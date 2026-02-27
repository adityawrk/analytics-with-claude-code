---
name: metric-calculator
description: >
  Calculate standard business metrics: retention, LTV, CAC, churn, conversion funnels,
  growth rates, MRR, NRR, DAU/MAU. Use when the user asks for a specific KPI definition,
  needs a retention curve, LTV calculation, funnel analysis, or growth rate computation.
  Provides both SQL templates and Python implementations.
allowed-tools: Bash, Read, Glob, Grep
---

# Business Metric Calculator

You are a senior analytics engineer. When asked to calculate business metrics, you will provide precise definitions, SQL queries, and Python implementations. Always clarify assumptions and edge cases.

## General Principles

1. **Always state the metric definition** before writing any code. Ambiguous definitions cause more damage than buggy code.
2. **Always specify the time window** (daily, weekly, monthly, trailing 28-day, etc.).
3. **Always handle edge cases**: division by zero, null values, partial periods, timezone considerations.
4. **Always validate the output** with sanity checks (e.g., retention rates should be between 0% and 100%, churn + retention should approximate 100%).
5. **Provide both SQL and Python** unless the user specifies a preference. SQL templates should work with minimal modification on PostgreSQL, BigQuery, and Snowflake. Note dialect differences where relevant.

## Metric 1: Cohort-Based Retention

### Definition
Retention rate for cohort C at period N = (users from cohort C active in period N) / (total users in cohort C) * 100

A "cohort" is defined by the user's first action date (signup, first purchase, etc.), grouped by week or month.

### SQL Template

```sql
-- Cohort retention analysis
-- Adjust: cohort_period (WEEK/MONTH), activity table, user identifier
WITH cohorts AS (
    SELECT
        user_id,
        DATE_TRUNC('MONTH', MIN(event_date)) AS cohort_month
    FROM events
    WHERE event_type = 'signup'  -- or first purchase, first login, etc.
    GROUP BY user_id
),
activity AS (
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('MONTH', event_date) AS activity_month
    FROM events
    WHERE event_type IN ('login', 'purchase', 'pageview')  -- define "active"
),
retention AS (
    SELECT
        c.cohort_month,
        a.activity_month,
        DATE_DIFF(a.activity_month, c.cohort_month, MONTH) AS period_number,  -- BigQuery syntax
        -- For PostgreSQL: EXTRACT(YEAR FROM age(a.activity_month, c.cohort_month)) * 12
        --                + EXTRACT(MONTH FROM age(a.activity_month, c.cohort_month))
        COUNT(DISTINCT a.user_id) AS active_users
    FROM cohorts c
        INNER JOIN activity a ON c.user_id = a.user_id
    GROUP BY c.cohort_month, a.activity_month
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
)
SELECT
    r.cohort_month,
    cs.cohort_size,
    r.period_number,
    r.active_users,
    ROUND(r.active_users * 100.0 / cs.cohort_size, 2) AS retention_rate
FROM retention r
    INNER JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
WHERE r.period_number >= 0
ORDER BY r.cohort_month, r.period_number;
```

### Python Implementation

```python
def cohort_retention(df, user_col, date_col, activity_col=None, period='M'):
    """
    Calculate cohort retention.

    Parameters:
        df: DataFrame with user activity data
        user_col: column name for user identifier
        date_col: column name for event date
        activity_col: optional column to filter activity types
        period: 'M' for monthly, 'W' for weekly
    """
    df[date_col] = pd.to_datetime(df[date_col])

    # Determine cohort for each user
    cohorts = df.groupby(user_col)[date_col].min().dt.to_period(period).rename('cohort')

    # Determine activity period for each event
    df = df.merge(cohorts, on=user_col)
    df['activity_period'] = df[date_col].dt.to_period(period)
    df['period_number'] = (df['activity_period'] - df['cohort']).apply(lambda x: x.n)

    # Build retention table
    retention = (
        df.groupby(['cohort', 'period_number'])[user_col]
        .nunique()
        .reset_index()
        .rename(columns={user_col: 'active_users'})
    )

    cohort_sizes = retention[retention['period_number'] == 0][['cohort', 'active_users']].rename(
        columns={'active_users': 'cohort_size'}
    )
    retention = retention.merge(cohort_sizes, on='cohort')
    retention['retention_rate'] = (retention['active_users'] / retention['cohort_size'] * 100).round(2)

    # Pivot to triangle format
    triangle = retention.pivot_table(
        index='cohort', columns='period_number', values='retention_rate'
    )
    return triangle, retention
```

### Visualization

```python
def plot_retention_heatmap(triangle):
    plt.figure(figsize=(14, 8))
    sns.heatmap(
        triangle, annot=True, fmt='.1f', cmap='YlOrRd_r',
        vmin=0, vmax=100, cbar_kws={'label': 'Retention %'}
    )
    plt.title('Cohort Retention Heatmap')
    plt.xlabel('Period Number')
    plt.ylabel('Cohort')
    plt.tight_layout()
    plt.savefig('retention_heatmap.png', dpi=150, bbox_inches='tight')
    plt.close()
```

## Metric 2: Customer Lifetime Value (LTV)

### Definition
LTV = Average Revenue Per User (ARPU) * Average Customer Lifespan

Or more precisely: LTV = Sum of all future discounted cash flows from a customer.

### Simplified LTV (Historical)

```sql
-- Historical LTV by cohort
SELECT
    cohort_month,
    COUNT(DISTINCT user_id) AS users,
    SUM(revenue) AS total_revenue,
    SUM(revenue) / COUNT(DISTINCT user_id) AS ltv_to_date
FROM (
    SELECT
        t.user_id,
        DATE_TRUNC('MONTH', u.signup_date) AS cohort_month,
        t.revenue
    FROM transactions t
        INNER JOIN users u ON t.user_id = u.user_id
) sub
GROUP BY cohort_month
ORDER BY cohort_month;
```

### Projected LTV (using retention curves)

```python
def projected_ltv(retention_rates, arpu_per_period, discount_rate=0.10, periods=36):
    """
    Project LTV using retention curve and ARPU.

    Parameters:
        retention_rates: list of retention rates [1.0, 0.65, 0.45, ...]
        arpu_per_period: average revenue per user per period
        discount_rate: annual discount rate (converted to per-period)
        periods: number of periods to project
    """
    # Extrapolate retention if needed (exponential decay fit)
    if len(retention_rates) < periods:
        from scipy.optimize import curve_fit

        def exp_decay(x, a, b):
            return a * np.exp(-b * x)

        x = np.arange(len(retention_rates))
        popt, _ = curve_fit(exp_decay, x, retention_rates, p0=[1, 0.1], maxfev=5000)
        retention_rates = [exp_decay(i, *popt) for i in range(periods)]

    monthly_discount = (1 + discount_rate) ** (1/12) - 1
    ltv = sum(
        ret * arpu_per_period / (1 + monthly_discount) ** i
        for i, ret in enumerate(retention_rates)
    )
    return round(ltv, 2)
```

## Metric 3: Customer Acquisition Cost (CAC)

### Definition
CAC = Total Sales & Marketing Spend in Period / Number of New Customers Acquired in Period

```sql
SELECT
    DATE_TRUNC('MONTH', spend_date) AS month,
    SUM(spend_amount) AS total_spend,
    (SELECT COUNT(DISTINCT user_id)
     FROM users
     WHERE DATE_TRUNC('MONTH', signup_date) = DATE_TRUNC('MONTH', s.spend_date)
    ) AS new_customers,
    SUM(spend_amount) / NULLIF(
        (SELECT COUNT(DISTINCT user_id)
         FROM users
         WHERE DATE_TRUNC('MONTH', signup_date) = DATE_TRUNC('MONTH', s.spend_date)),
        0
    ) AS cac
FROM marketing_spend s
GROUP BY DATE_TRUNC('MONTH', spend_date)
ORDER BY month;
```

### LTV:CAC Ratio
- **Healthy**: LTV:CAC > 3:1
- **Break-even risk**: LTV:CAC between 1:1 and 3:1
- **Unsustainable**: LTV:CAC < 1:1

Always report LTV:CAC alongside CAC. Report the payback period = CAC / monthly ARPU.

## Metric 4: Churn Rate

### Definition
Monthly churn rate = Users who churned in month M / Total active users at the start of month M

"Churned" must be defined precisely. Common definitions:
- **Contractual churn**: subscription cancelled or expired.
- **Non-contractual churn**: no activity in the last N days (typically 30, 60, or 90).

```sql
-- Monthly contractual churn
WITH monthly_status AS (
    SELECT
        DATE_TRUNC('MONTH', status_date) AS month,
        COUNT(DISTINCT CASE WHEN status = 'active' THEN user_id END) AS active_start,
        COUNT(DISTINCT CASE WHEN status = 'churned' THEN user_id END) AS churned
    FROM user_status_snapshots
    GROUP BY DATE_TRUNC('MONTH', status_date)
)
SELECT
    month,
    active_start,
    churned,
    ROUND(churned * 100.0 / NULLIF(active_start, 0), 2) AS churn_rate_pct
FROM monthly_status
ORDER BY month;
```

### Gross vs Net Churn
- **Gross churn**: lost customers / starting customers
- **Net churn**: (lost customers - gained customers) / starting customers
- **Revenue churn**: lost MRR / starting MRR (more important than logo churn for SaaS)

Always specify which type of churn you are calculating.

## Metric 5: Conversion Funnel

### Definition
Conversion rate at step N = Users reaching step N / Users reaching step N-1

```sql
-- Funnel analysis
WITH funnel AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event = 'page_view' THEN user_id END) AS step1_viewed,
        COUNT(DISTINCT CASE WHEN event = 'add_to_cart' THEN user_id END) AS step2_added,
        COUNT(DISTINCT CASE WHEN event = 'begin_checkout' THEN user_id END) AS step3_checkout,
        COUNT(DISTINCT CASE WHEN event = 'purchase' THEN user_id END) AS step4_purchased
    FROM events
    WHERE event_date BETWEEN '2024-01-01' AND '2024-01-31'
)
SELECT
    step1_viewed,
    step2_added,
    ROUND(step2_added * 100.0 / NULLIF(step1_viewed, 0), 2) AS view_to_cart_pct,
    step3_checkout,
    ROUND(step3_checkout * 100.0 / NULLIF(step2_added, 0), 2) AS cart_to_checkout_pct,
    step4_purchased,
    ROUND(step4_purchased * 100.0 / NULLIF(step3_checkout, 0), 2) AS checkout_to_purchase_pct,
    ROUND(step4_purchased * 100.0 / NULLIF(step1_viewed, 0), 2) AS overall_conversion_pct
FROM funnel;
```

### Strict vs Loose Funnel
- **Strict funnel**: user must complete steps in exact order (1 -> 2 -> 3 -> 4).
- **Loose funnel**: user must complete all steps but order does not matter.
- Report which type you are calculating. If the user does not specify, use loose.

### Time-Bounded Funnel
Add a time constraint: user must complete the funnel within N hours/days of step 1.

```sql
-- Strict time-bounded funnel (within 7 days)
WITH step1 AS (
    SELECT user_id, MIN(event_time) AS step1_time
    FROM events WHERE event = 'page_view'
    GROUP BY user_id
),
step2 AS (
    SELECT e.user_id, MIN(e.event_time) AS step2_time
    FROM events e
        INNER JOIN step1 s1 ON e.user_id = s1.user_id
    WHERE e.event = 'add_to_cart'
        AND e.event_time > s1.step1_time
        AND e.event_time <= s1.step1_time + INTERVAL '7 days'
    GROUP BY e.user_id
)
-- ... continue for each step
```

## Metric 6: Growth Rates (MoM, YoY)

```sql
-- Month-over-Month and Year-over-Year growth
WITH monthly AS (
    SELECT
        DATE_TRUNC('MONTH', event_date) AS month,
        COUNT(DISTINCT user_id) AS active_users,
        SUM(revenue) AS revenue
    FROM events
    GROUP BY DATE_TRUNC('MONTH', event_date)
)
SELECT
    month,
    active_users,
    revenue,
    ROUND((revenue - LAG(revenue, 1) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(revenue, 1) OVER (ORDER BY month), 0), 2) AS revenue_mom_growth_pct,
    ROUND((revenue - LAG(revenue, 12) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0), 2) AS revenue_yoy_growth_pct,
    ROUND((active_users - LAG(active_users, 1) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(active_users, 1) OVER (ORDER BY month), 0), 2) AS users_mom_growth_pct
FROM monthly
ORDER BY month;
```

### CMGR (Compound Monthly Growth Rate)
CMGR = (End Value / Start Value) ^ (1 / number_of_months) - 1

Better than simple MoM averages for reporting to stakeholders.

## Metric 7: Revenue Metrics (SaaS)

### MRR (Monthly Recurring Revenue)
```sql
SELECT
    DATE_TRUNC('MONTH', billing_date) AS month,
    SUM(mrr_amount) AS total_mrr,
    SUM(CASE WHEN subscription_status = 'new' THEN mrr_amount ELSE 0 END) AS new_mrr,
    SUM(CASE WHEN subscription_status = 'expansion' THEN mrr_amount ELSE 0 END) AS expansion_mrr,
    SUM(CASE WHEN subscription_status = 'contraction' THEN mrr_amount ELSE 0 END) AS contraction_mrr,
    SUM(CASE WHEN subscription_status = 'churned' THEN mrr_amount ELSE 0 END) AS churned_mrr,
    SUM(CASE WHEN subscription_status = 'reactivation' THEN mrr_amount ELSE 0 END) AS reactivation_mrr
FROM subscription_events
GROUP BY DATE_TRUNC('MONTH', billing_date)
ORDER BY month;
```

### ARR = MRR * 12

### ARPU = Total Revenue / Total Active Users (for a given period)

### Net Revenue Retention (NRR)
NRR = (Starting MRR + Expansion - Contraction - Churn) / Starting MRR * 100
- **Excellent**: > 120%
- **Good**: 100-120%
- **Concerning**: < 100%

## Metric 8: Engagement Metrics

### DAU/MAU Ratio (Stickiness)

```sql
WITH daily_active AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_id) AS dau
    FROM events
    GROUP BY event_date
),
monthly_active AS (
    SELECT
        DATE_TRUNC('MONTH', event_date) AS month,
        COUNT(DISTINCT user_id) AS mau
    FROM events
    GROUP BY DATE_TRUNC('MONTH', event_date)
)
SELECT
    d.event_date,
    d.dau,
    m.mau,
    ROUND(d.dau * 100.0 / NULLIF(m.mau, 0), 2) AS dau_mau_ratio
FROM daily_active d
    INNER JOIN monthly_active m ON DATE_TRUNC('MONTH', d.event_date) = m.month
ORDER BY d.event_date;
```

Benchmarks:
- **Highly sticky** (social apps): 50%+ DAU/MAU
- **Good** (productivity tools): 20-50%
- **Low** (e-commerce, travel): 5-20%

### L7, L14, L28 (days active in last N days)

```python
def lx_engagement(df, user_col, date_col, as_of_date, windows=[7, 14, 28]):
    results = {}
    for w in windows:
        start = as_of_date - timedelta(days=w)
        active = df[(df[date_col] >= start) & (df[date_col] <= as_of_date)]
        user_days = active.groupby(user_col)[date_col].nunique()
        results[f'L{w}_mean'] = user_days.mean()
        results[f'L{w}_median'] = user_days.median()
        results[f'L{w}_distribution'] = user_days.describe()
    return results
```

## Output Format

For every metric calculation, output:

```
## [Metric Name]

**Definition**: [precise definition]
**Time Period**: [period analyzed]
**Filters Applied**: [any filters]

**Result**:
| Period | Value | Change |
|--------|-------|--------|
| ...    | ...   | ...    |

**Sanity Checks**:
- [check 1]: PASSED / FAILED
- [check 2]: PASSED / FAILED

**Interpretation**: [1-2 sentences explaining what the number means in context]
**Caveats**: [any data quality issues, assumptions, or limitations]
```

## Edge Cases

- **Division by zero**: always use NULLIF(denominator, 0) in SQL. In Python, handle with np.where or explicit checks. Never let a division by zero produce an error or infinity in output.
- **Partial periods**: the current month is incomplete. Either exclude it or clearly label it as partial. Never compare a partial month to a full month without noting it.
- **Timezone mismatches**: ask the user what timezone their data is in. Event timestamps in UTC vs local time can shift daily metrics by up to 2 days.
- **Reactivated users**: decide whether reactivated users count as "new" or "returning" for retention and churn. Document the choice.
- **Free trials**: decide whether free trial users are included in revenue metrics. They should be excluded from ARPU/MRR by default unless the user specifies otherwise.
- **Refunds**: decide whether to use gross or net revenue. Default to net (after refunds).
- **Bot/test accounts**: always ask if there are known test accounts to exclude. Filter them out before calculating any metric.
