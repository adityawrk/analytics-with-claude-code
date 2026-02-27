---
description: Standard business metric definitions ensuring consistency across all analytics work
---

# Standard Metric Definitions

Every metric in this project must be calculated consistently. When writing queries that compute these metrics, follow the definitions below exactly. If a stakeholder uses a metric name that differs from these definitions, clarify which definition applies before writing the query.

---

## Revenue Metrics

### Monthly Recurring Revenue (MRR)

**Definition:** The total recurring revenue normalized to a monthly amount, measured at a point in time (end of month). Includes only active subscriptions. Excludes one-time charges, credits, and refunds.

**SQL Template:**
```sql
select
    date_trunc('month', measurement_date) as month,
    sum(monthly_amount_usd) as mrr
from {{ ref('fct_subscriptions') }}
where subscription_status = 'active'
    and measurement_date = last_day_of_month
group by 1
```

**Common Pitfalls:**
- Do not include trial subscriptions unless they have a paid component.
- Annual contracts must be divided by 12 to normalize to monthly.
- Handle currency conversion at the transaction time, not at report time.
- Do not double-count subscriptions that were upgraded mid-month; use the end-of-month state.

**Edge Cases:**
- Mid-month cancellations: include the subscription in MRR for that month if it was active on the measurement date.
- Downgrades: reflect the new (lower) amount starting the month the downgrade takes effect.
- Free plans with paid add-ons: include only the paid add-on amount.

### Annual Recurring Revenue (ARR)

**Definition:** ARR = MRR * 12. Always derive ARR from MRR, never calculate it independently.

### Gross Revenue

**Definition:** Total invoiced amount before any refunds, credits, or discounts. Includes one-time charges.

```sql
select
    date_trunc('month', invoice_date) as month,
    sum(invoice_amount_usd) as gross_revenue
from {{ ref('fct_invoices') }}
where invoice_status != 'void'
group by 1
```

### Net Revenue

**Definition:** Gross revenue minus refunds, credits, and chargebacks. This is the recognized revenue figure.

```sql
select
    date_trunc('month', invoice_date) as month,
    sum(invoice_amount_usd)
        - coalesce(sum(refund_amount_usd), 0)
        - coalesce(sum(credit_amount_usd), 0) as net_revenue
from {{ ref('fct_invoices') }}
left join {{ ref('fct_refunds') }} using (invoice_id)
left join {{ ref('fct_credits') }} using (invoice_id)
where invoice_status != 'void'
group by 1
```

**Common Pitfalls:**
- Refunds may be issued in a different month than the original invoice. Decide whether to attribute the refund to the invoice month or the refund month and be consistent.
- Partial refunds exist. Do not assume a refund cancels the full invoice.

---

## User Metrics

### Daily Active Users (DAU)

**Definition:** Count of distinct users who performed at least one qualifying action on a given calendar day (UTC).

**Qualifying actions** must be defined per product. Typically: any in-app event excluding background/system events and bot traffic.

```sql
select
    event_date,
    count(distinct user_id) as dau
from {{ ref('fct_user_events') }}
where is_qualifying_action = true
    and is_bot = false
group by 1
```

**Common Pitfalls:**
- Always use UTC dates for consistency unless the business explicitly requires a different timezone.
- Exclude anonymous/logged-out sessions unless the metric definition explicitly includes them.
- Deduplicate on `user_id`, not `session_id` or `device_id`.

### Weekly Active Users (WAU)

**Definition:** Count of distinct users who performed at least one qualifying action in a 7-day window ending on the given date (inclusive, rolling).

```sql
select
    event_date,
    count(distinct user_id) as wau
from {{ ref('fct_user_events') }}
where is_qualifying_action = true
    and is_bot = false
    and event_date between current_date - interval '6 days' and current_date
group by 1
```

**Edge Cases:**
- For dashboard display, decide whether WAU is a rolling 7-day window or ISO week. Document which one.

### Monthly Active Users (MAU)

**Definition:** Count of distinct users who performed at least one qualifying action in a 28-day rolling window (not calendar month, unless explicitly stated).

```sql
select
    event_date,
    count(distinct user_id) as mau_28d
from {{ ref('fct_user_events') }}
where is_qualifying_action = true
    and is_bot = false
    and event_date between current_date - interval '27 days' and current_date
group by 1
```

**Common Pitfalls:**
- A 28-day window avoids month-length bias (Feb vs. Jan). If using calendar month, name it `mau_calendar` to distinguish.
- Be explicit about whether the window is 28d or 30d.

---

## Retention Metrics

### Day-N Retention

**Definition:** Of users who signed up (or activated) on day 0, what percentage performed a qualifying action exactly N days later.

```sql
with cohort as (
    select
        user_id,
        min(event_date) as signup_date
    from {{ ref('fct_user_events') }}
    where event_type = 'signup'
    group by 1
),

activity as (
    select distinct
        user_id,
        event_date as activity_date
    from {{ ref('fct_user_events') }}
    where is_qualifying_action = true
),

retention as (
    select
        c.signup_date,
        datediff('day', c.signup_date, a.activity_date) as day_n,
        count(distinct c.user_id) as retained_users
    from cohort as c
    inner join activity as a
        on c.user_id = a.user_id
    group by 1, 2
),

cohort_sizes as (
    select
        signup_date,
        count(distinct user_id) as cohort_size
    from cohort
    group by 1
)

select
    r.signup_date,
    r.day_n,
    r.retained_users,
    cs.cohort_size,
    round(100.0 * r.retained_users / cs.cohort_size, 2) as retention_rate
from retention as r
left join cohort_sizes as cs
    on r.signup_date = cs.signup_date
where r.day_n in (1, 3, 7, 14, 28)
order by r.signup_date, r.day_n
```

**Common Pitfalls:**
- Day 0 is the signup day itself. Day 1 is the next calendar day.
- Use `datediff('day', ...)` not timestamp subtraction, to avoid partial-day issues.
- Do not count the signup event itself as a Day-0 return visit.
- Immature cohorts (where N days have not yet elapsed) must be excluded or clearly marked.

### Week-N Retention

**Definition:** Same as Day-N but using ISO week boundaries. A user is retained in Week N if they performed any qualifying action during ISO week N after their signup week (Week 0).

### Cohort-Based Retention

Always present retention as a cohort matrix: rows are signup cohorts (typically weekly or monthly), columns are periods (Day N or Week N). This allows visual comparison of retention curves across cohorts.

---

## Conversion Metrics

### Funnel Conversion Rate

**Definition:** The percentage of users who completed step N+1 out of those who completed step N. Always define the funnel steps explicitly.

```sql
with funnel as (
    select
        user_id,
        max(case when event_type = 'page_view' then 1 else 0 end) as step_1_page_view,
        max(case when event_type = 'signup_start' then 1 else 0 end) as step_2_signup_start,
        max(case when event_type = 'signup_complete' then 1 else 0 end) as step_3_signup_complete,
        max(case when event_type = 'first_purchase' then 1 else 0 end) as step_4_first_purchase
    from {{ ref('fct_user_events') }}
    where event_date >= current_date - interval '30 days'
    group by 1
)

select
    count(distinct case when step_1_page_view = 1 then user_id end) as step_1_users,
    count(distinct case when step_2_signup_start = 1 then user_id end) as step_2_users,
    count(distinct case when step_3_signup_complete = 1 then user_id end) as step_3_users,
    count(distinct case when step_4_first_purchase = 1 then user_id end) as step_4_users,
    round(100.0 * step_2_users / nullif(step_1_users, 0), 2) as step_1_to_2_rate,
    round(100.0 * step_3_users / nullif(step_2_users, 0), 2) as step_2_to_3_rate,
    round(100.0 * step_4_users / nullif(step_3_users, 0), 2) as step_3_to_4_rate
from funnel
```

**Common Pitfalls:**
- Decide whether the funnel is strict-ordered (step 2 must come after step 1 chronologically) or unordered. Document which.
- Use `nullif(..., 0)` to avoid division-by-zero errors.
- Attribution window: define the maximum time allowed between funnel steps. A user who views a page and purchases 6 months later may not be the same conversion intent.

### Attribution Window

Default attribution windows unless otherwise specified:
- First-touch to signup: 30 days
- Signup to first purchase: 14 days
- Campaign exposure to conversion: 7 days

Always make the attribution window explicit in the query and document it.

---

## Growth Metrics

### Month-over-Month (MoM) Growth

**Definition:** Percentage change from the prior month.

```sql
select
    month,
    metric_value,
    lag(metric_value) over (order by month) as prior_month_value,
    round(
        100.0 * (metric_value - lag(metric_value) over (order by month))
        / nullif(lag(metric_value) over (order by month), 0),
        2
    ) as mom_growth_pct
from monthly_metrics
```

### Quarter-over-Quarter (QoQ) Growth

**Definition:** Percentage change from the prior quarter. Use `lag(..., 1)` over quarterly data or `lag(..., 3)` over monthly data.

### Year-over-Year (YoY) Growth

**Definition:** Percentage change from the same period in the prior year. Use `lag(..., 12)` over monthly data.

```sql
select
    month,
    metric_value,
    lag(metric_value, 12) over (order by month) as prior_year_value,
    round(
        100.0 * (metric_value - lag(metric_value, 12) over (order by month))
        / nullif(lag(metric_value, 12) over (order by month), 0),
        2
    ) as yoy_growth_pct
from monthly_metrics
```

### Compound Monthly Growth Rate (CMGR)

**Definition:** The smoothed average monthly growth rate over a period.

```sql
-- CMGR over N months
select
    power(
        latest_value::float / nullif(earliest_value::float, 0),
        1.0 / nullif(number_of_months - 1, 0)
    ) - 1 as cmgr
```

**Common Pitfalls:**
- Do not compare incomplete periods. If the current month is not over, exclude it or clearly label it as partial.
- Seasonality can make MoM misleading. Always provide YoY alongside MoM for seasonal businesses.
- Growth rates on small bases are volatile and misleading. Include the absolute values alongside percentages.
- When the prior period value is zero or negative, growth rate is undefined. Return NULL, not infinity.
