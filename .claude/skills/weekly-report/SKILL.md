---
name: weekly-report
description: >
  Generate recurring weekly or monthly analytics reports with period-over-period comparison,
  anomaly detection, and executive summaries. Use when the user asks for a weekly report,
  monthly KPI review, recurring metrics snapshot, or needs automated period-over-period
  diffing. Saves templates for one-command re-runs.
---

# Recurring Report Generator

You are a senior analytics professional who generates polished, stakeholder-ready recurring reports. Unlike ad-hoc analyses, these reports run on a schedule and must be consistent, comparable across periods, and fast to produce. Follow every step below.

## Step 0: Parse Invocation Arguments

Extract the following from the user's invocation:

| Parameter | Flag | Default | Description |
|-----------|------|---------|-------------|
| **name** | `--name` | Required (ask if missing) | Report name, used for template storage (e.g., "Business Review", "Executive Summary") |
| **period** | `--period` | `this-week` | Period to report on. Accepts: `this-week`, `last-week`, `this-month`, `last-month`, `this-quarter`, `last-quarter`, or explicit dates `2024-01-01:2024-01-07` |
| **compare** | `--compare` | previous period | Period to compare against. Same format as `--period`, or `last-week`, `last-month`, `last-quarter`, `last-year`, `same-period-last-year` |
| **format** | `--format` | `markdown` | Output format: `markdown`, `html`, `slack` |
| **metrics** | `--metrics` | from template | Comma-separated list of metrics to include, or `all` |
| **audience** | `--audience` | `team` | `executive`, `team`, or `technical` -- adjusts detail level and language |
| **template** | `--template` | auto-detect | Path to a custom template file, or `new` to create fresh |

### Period Resolution
Resolve relative period names to concrete date ranges. Use the current date to calculate:

- `this-week`: Monday through Sunday of the current week (or through today if the week is incomplete -- mark as PARTIAL)
- `last-week`: Monday through Sunday of the previous week
- `this-month`: 1st through last day of the current month (or through today if incomplete -- mark as PARTIAL)
- `last-month`: 1st through last day of the previous month
- `this-quarter`: first day of current quarter through today (mark as PARTIAL)
- `last-quarter`: full previous quarter
- Explicit dates: parse as `start:end`

Always output:
```
Report Period: [start_date] to [end_date] [PARTIAL if incomplete]
Comparison Period: [start_date] to [end_date]
```

Warn if comparing a partial period to a full period (unfair comparison). Suggest normalizing (e.g., compare only complete days).

## Step 1: Template Management

### 1.1 Check for Existing Template
Look for a saved template at `.analytics/report-templates/{name-slugified}.json`.

Use Glob to search for: `.analytics/report-templates/*.json`

### 1.2 If Template Exists: Load It
Read the template file. It contains:
```json
{
    "name": "Business Review",
    "created": "2024-06-15",
    "last_run": "2024-07-22",
    "run_count": 6,
    "sections": [
        {
            "id": "executive_summary",
            "title": "Executive Summary",
            "type": "auto_summary",
            "config": {}
        },
        {
            "id": "kpi_table",
            "title": "Key Metrics",
            "type": "kpi_table",
            "config": {
                "metrics": [
                    {
                        "name": "Revenue",
                        "query_file": "queries/revenue.sql",
                        "format": "currency",
                        "direction": "up_is_good",
                        "alert_threshold_pct": 10
                    },
                    {
                        "name": "Active Users",
                        "query_file": "queries/active_users.sql",
                        "format": "number",
                        "direction": "up_is_good",
                        "alert_threshold_pct": 15
                    }
                ]
            }
        },
        {
            "id": "breakdown",
            "title": "Breakdown by Region",
            "type": "dimension_breakdown",
            "config": {
                "dimension": "region",
                "metric": "revenue"
            }
        }
    ],
    "format_defaults": {
        "currency_symbol": "$",
        "number_locale": "en-US",
        "percentage_decimals": 1
    },
    "prior_results": [
        {
            "period": "2024-07-15:2024-07-21",
            "generated": "2024-07-22T09:15:00Z",
            "totals": {
                "Revenue": 1250000,
                "Active Users": 45231
            }
        }
    ]
}
```

Tell the user: "Loaded template '[name]' (last run: [date], run #{N}). Using [X] configured sections and [Y] metrics."

### 1.3 If No Template: Create One
Guide the user through template creation:

1. Ask what metrics they want to track (or infer from available SQL files/dbt models).
2. Ask what dimensions to break down by (or suggest based on available data).
3. Ask the audience level (executive, team, technical).
4. Generate the template JSON.
5. Save it to `.analytics/report-templates/{name-slugified}.json` by creating the directory if needed.
6. Tell the user: "Created new template '[name]' at [path]. Future runs will load this automatically."

### 1.4 Template Update
After every successful report generation, update the template:
- Set `last_run` to current timestamp.
- Increment `run_count`.
- Append the current period's totals to `prior_results` (keep last 52 entries for weekly, 12 for monthly).

## Step 2: Data Collection

### 2.1 Query Execution Strategy
For each metric in the template, determine how to get the data:

1. **SQL file exists** (`query_file` in template): Read the file, inject the date range parameters, and provide the executable query.
2. **dbt model exists**: Reference the dbt model and suggest a query against the compiled table/view.
3. **Manual / CSV**: Ask the user to provide the values for this period.
4. **Derived**: Calculate from other metrics (e.g., ARPU = Revenue / Active Users).

### 2.2 Date Parameter Injection
For SQL queries, inject date parameters safely:

```sql
-- Replace these with your period dates
-- Report period:
--   @start_date = '{report_start}'
--   @end_date = '{report_end}'
-- Comparison period:
--   @compare_start = '{compare_start}'
--   @compare_end = '{compare_end}'
```

Support common parameter styles: `:start_date`, `$1`, `@start_date`, `{{ var('start_date') }}`, `'{start_date}'`.

### 2.3 Dual-Period Query Pattern
For each metric, generate a query that fetches both the current and comparison periods in one pass:

```sql
SELECT
    CASE
        WHEN event_date BETWEEN :report_start AND :report_end THEN 'current'
        WHEN event_date BETWEEN :compare_start AND :compare_end THEN 'comparison'
    END AS period,
    SUM(amount) AS revenue,
    COUNT(DISTINCT user_id) AS active_users
FROM events
WHERE event_date BETWEEN :compare_start AND :report_end
GROUP BY period;
```

## Step 3: Period-over-Period Computation

For every metric, calculate the full comparison context.

### 3.1 Core Calculations

```python
def compute_period_comparison(current_value, comparison_value, prior_results=None):
    """
    Compute all period-over-period metrics.

    Returns dict with:
    - current, comparison, absolute_change, pct_change
    - direction (up/down/flat)
    - is_significant (change > alert threshold)
    - trend (from prior_results)
    - is_anomaly (> 2 std devs from trend)
    - sparkline (directional indicator)
    """
    result = {
        'current': current_value,
        'comparison': comparison_value,
    }

    # Absolute and percentage change
    result['absolute_change'] = current_value - comparison_value
    if comparison_value and comparison_value != 0:
        result['pct_change'] = round(
            (current_value - comparison_value) / abs(comparison_value) * 100, 1
        )
    else:
        result['pct_change'] = None  # Cannot compute

    # Direction
    if result['pct_change'] is None:
        result['direction'] = 'flat'
    elif abs(result['pct_change']) < 1.0:
        result['direction'] = 'flat'
    elif result['pct_change'] > 0:
        result['direction'] = 'up'
    else:
        result['direction'] = 'down'

    # Historical trend from prior results
    if prior_results and len(prior_results) >= 4:
        values = [r for r in prior_results[-12:]]  # Last 12 periods
        mean = sum(values) / len(values)
        std = (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5

        # Anomaly detection (> 2 standard deviations)
        result['is_anomaly'] = abs(current_value - mean) > 2 * std if std > 0 else False
        result['rolling_mean'] = round(mean, 2)
        result['rolling_std'] = round(std, 2)

        # Trend direction (linear regression over last 4 periods)
        recent = values[-4:]
        n = len(recent)
        x_mean = (n - 1) / 2
        y_mean = sum(recent) / n
        slope = sum((i - x_mean) * (v - y_mean) for i, v in enumerate(recent))
        slope /= max(sum((i - x_mean) ** 2 for i in range(n)), 1e-10)
        result['trend'] = 'improving' if slope > 0 else 'declining' if slope < 0 else 'stable'
    else:
        result['is_anomaly'] = False
        result['trend'] = 'insufficient_data'

    return result
```

### 3.2 Significance Thresholds
Default thresholds (overridable per metric in template):

| Change Magnitude | Classification |
|-----------------|----------------|
| < 1% | **Flat** -- no callout needed |
| 1% - 5% | **Minor change** -- mention in trends, not in executive summary |
| 5% - 10% | **Notable change** -- include in executive summary |
| 10% - 25% | **Significant change** -- highlight prominently, suggest investigation |
| > 25% | **Major movement** -- lead with this, flag as potential anomaly |
| > 2 std devs | **Anomaly** -- regardless of percentage, flag for investigation |

### 3.3 Sparkline Indicators
Map metrics to visual indicators for the KPI table:

| Direction | Significance | Metric Direction | Indicator |
|-----------|-------------|-----------------|-----------|
| Up | Any | up_is_good | `^ (+X%)` |
| Up | Any | down_is_good | `^ (+X%) [!]` |
| Down | Any | down_is_good | `v (-X%)` |
| Down | Any | up_is_good | `v (-X%) [!]` |
| Flat | Any | Any | `~ (0%)` |
| Any | Anomaly | Any | `[ANOMALY] (+X%)` |

## Step 4: Report Generation

Generate the report in the requested format with these sections.

### Section 1: Header and Metadata

**Markdown:**
```markdown
# [Report Name]: [Period Date Range]
**Generated**: [timestamp]
**Period**: [start] to [end] [PARTIAL if applicable]
**Compared to**: [comparison start] to [comparison end]
**Run #[N]** from template `[template_name]`

---
```

**Slack:**
```
*[Report Name]: [Period Date Range]*
Period: [start] to [end] | vs. [comparison period]
```

### Section 2: Executive Summary (Auto-Generated)

Automatically generate 3-5 bullet points based on the biggest movers:

1. Sort all metrics by absolute percentage change (descending).
2. Lead with the most significant movement.
3. Include any anomalies.
4. Note any metrics that crossed a target threshold (above or below).
5. End with an overall assessment ("strong week", "mixed results", "concerning trends").

**Template for each bullet:**
- [UP/DOWN indicator] **[Metric Name]** [increased/decreased] [X]% to [value] ([absolute change] [direction] from [comparison value]). [One sentence of context: why this matters or what likely caused it.]

**For executive audience**: Lead with business impact ("Revenue grew $50K this week"), not metric mechanics.
**For technical audience**: Include the breakdown ("driven by a 12% increase in mobile conversion rate").

### Section 3: KPI Table

Generate a formatted table with all tracked metrics:

**Markdown:**
```markdown
| Metric | This Period | Last Period | Change | Change % | 4-Period Avg | Trend | Status |
|--------|------------|-------------|--------|----------|-------------|-------|--------|
| Revenue | $1,250,000 | $1,180,000 | +$70,000 | +5.9% | $1,215,000 | ^ | OK |
| Active Users | 45,231 | 46,102 | -871 | -1.9% | 45,800 | v | OK |
| Conversion Rate | 3.2% | 2.8% | +0.4pp | +14.3% | 2.9% | ^ | ALERT |
| ARPU | $27.63 | $25.60 | +$2.03 | +7.9% | $26.50 | ^ | OK |
```

**Status column logic:**
- `OK`: Within normal range
- `WATCH`: Notable change (5-10%) in concerning direction
- `ALERT`: Significant change (>10%) or anomaly
- `TARGET MET`: Crossed a positive target threshold
- `TARGET MISSED`: Below a target threshold

### Section 4: Detailed Breakdown by Dimension

For each configured dimension breakdown:

```markdown
### Revenue by Region

| Region | This Period | Last Period | Change % | Share of Total |
|--------|------------|-------------|----------|---------------|
| North America | $750,000 | $720,000 | +4.2% | 60.0% |
| Europe | $312,500 | $295,000 | +5.9% | 25.0% |
| APAC | $125,000 | $118,000 | +5.9% | 10.0% |
| Rest of World | $62,500 | $47,000 | +33.0% [!] | 5.0% |

**Notable**: Rest of World revenue surged +33.0% -- investigate whether this is sustainable or a one-time event.
```

Rules for dimension breakdowns:
- Sort by absolute value of the metric (largest first), not by change.
- Include a "Share of Total" column to show relative importance.
- Flag any dimension with > 10% change with `[!]`.
- If a dimension is new (exists in current period but not comparison), mark as `[NEW]`.
- If a dimension disappeared (exists in comparison but not current), mark as `[GONE]`.
- Limit to top 10 dimensions by default. Collapse the rest into "Other".

### Section 5: Anomaly Callouts

For any metric or metric-dimension combination that exceeds 2 standard deviations from its historical trend:

```markdown
## Anomaly Alerts

### [ANOMALY] Conversion Rate: +14.3% WoW
**Current**: 3.2% | **Expected range**: 2.6% - 3.1% (based on 12-period trend)
**Standard deviations from mean**: 2.4
**Possible explanations**:
1. [Check if a marketing campaign launched this period]
2. [Check if a product change affected the funnel]
3. [Check for data quality issues in the event tracking]
**Recommended action**: Investigate root cause before next report. If organic, update targets.
```

For each anomaly, auto-suggest 2-3 investigation paths based on the metric type:
- Revenue anomaly: Check for large one-time deals, pricing changes, refund spikes.
- User anomaly: Check for marketing campaigns, viral events, bot traffic, tracking changes.
- Conversion anomaly: Check for A/B tests, product changes, funnel instrumentation changes.
- Engagement anomaly: Check for feature launches, outages, seasonal patterns.

### Section 6: Trends and Historical Context

If the template has 4+ prior results, include a trends section:

```markdown
## Trends (Last 12 Periods)

### Revenue Trend
| Period | Value | WoW Change | Cumulative |
|--------|-------|------------|------------|
| Week 1 | $1,050,000 | - | $1,050,000 |
| Week 2 | $1,080,000 | +2.9% | $2,130,000 |
| ... | ... | ... | ... |
| Week 12 | $1,250,000 | +5.9% | $14,250,000 |

**Trend**: Revenue has grown for 8 of the last 12 weeks. Compound weekly growth rate: +1.4%.
**Forecast**: At current trajectory, next period revenue is estimated at $1,268,000 (+/- $45,000).
```

Simple forecast method: Use the linear trend from the last 4-8 periods to project one period forward. Include a confidence range based on the standard deviation of recent changes. Always caveat that this is a naive extrapolation, not a statistical forecast.

### Section 7: Action Items (Auto-Suggested)

Based on the metric movements, auto-generate suggested action items:

```markdown
## Suggested Action Items

| Priority | Action | Rationale | Owner |
|----------|--------|-----------|-------|
| HIGH | Investigate conversion rate spike (+14.3%) | Anomalous change, need to determine if sustainable | [Assign] |
| MEDIUM | Monitor Rest of World revenue growth (+33%) | Unusual acceleration, verify data quality | [Assign] |
| LOW | Review active user decline (-1.9%) | Second consecutive week of decline, still within normal range | [Assign] |
```

Action item generation rules:
- **HIGH priority**: Any anomaly or any metric with > 15% change in a concerning direction.
- **MEDIUM priority**: Metrics with 5-15% change in concerning direction, or 2+ consecutive periods of decline/growth.
- **LOW priority**: Minor movements worth monitoring but not urgent.
- Always include "Investigate [anomaly]" for any anomaly detected.
- If a positive metric turned negative or vice versa, flag the inflection point.

## Step 5: Format-Specific Output

### 5.1 Markdown (Default)
Output as a single markdown document. Save as `reports/{name-slugified}_{period}.md`.

### 5.2 HTML (for Email)
Wrap the content in a styled HTML template optimized for email clients:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #1a1a1a;
            line-height: 1.5;
            background: #ffffff;
        }
        h1 {
            color: #111827;
            border-bottom: 3px solid #2563EB;
            padding-bottom: 8px;
            font-size: 24px;
        }
        h2 {
            color: #1F2937;
            margin-top: 28px;
            font-size: 18px;
        }
        .summary-box {
            background: #EFF6FF;
            border-left: 4px solid #2563EB;
            padding: 16px;
            margin: 16px 0;
            border-radius: 0 4px 4px 0;
        }
        .anomaly-box {
            background: #FEF2F2;
            border-left: 4px solid #DC2626;
            padding: 16px;
            margin: 16px 0;
            border-radius: 0 4px 4px 0;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 12px 0;
            font-size: 14px;
        }
        th {
            background: #2563EB;
            color: white;
            padding: 10px 14px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 8px 14px;
            border-bottom: 1px solid #E5E7EB;
        }
        tr:nth-child(even) { background: #F9FAFB; }
        .up { color: #059669; font-weight: 600; }
        .down { color: #DC2626; font-weight: 600; }
        .flat { color: #6B7280; }
        .alert { color: #DC2626; font-weight: 700; }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge-ok { background: #D1FAE5; color: #065F46; }
        .badge-watch { background: #FEF3C7; color: #92400E; }
        .badge-alert { background: #FEE2E2; color: #991B1B; }
        .metadata {
            color: #6B7280;
            font-size: 13px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <!-- Report content inserted here -->
</body>
</html>
```

Save as `reports/{name-slugified}_{period}.html`.

### 5.3 Slack-Ready Blocks
Format the output for pasting into Slack. Use Slack markdown conventions:

- `*bold*` for emphasis (not `**bold**`)
- Use `:chart_with_upwards_trend:` and `:chart_with_downwards_trend:` for indicators
- Use `:rotating_light:` for anomalies
- Use `:white_check_mark:` for targets met
- Use `:warning:` for watch items
- Format tables as code blocks (Slack does not render markdown tables)
- Keep the total message under 4000 characters (Slack message limit). If longer, split into sections with clear headers.

```
*Weekly Business Review: Jan 15-21, 2024*
_vs. Jan 8-14, 2024_

*TL;DR*
:chart_with_upwards_trend: Revenue up +5.9% to $1.25M
:chart_with_downwards_trend: Active users down -1.9% (within normal range)
:rotating_light: Conversion rate anomaly: +14.3% -- needs investigation

*Key Metrics*
```Revenue:       $1,250,000  (+5.9%)  OK```
```Active Users:  45,231      (-1.9%)  OK```
```Conversion:    3.2%        (+14.3%) ALERT```
```ARPU:          $27.63      (+7.9%)  OK```

*Action Items*
1. :red_circle: Investigate conversion rate anomaly
2. :large_orange_circle: Monitor RoW revenue acceleration
3. :white_circle: Watch active user trend
```

## Step 6: Post-Generation

### 6.1 Save Template Update
Update the template file with:
- New `last_run` timestamp
- Incremented `run_count`
- Append current period totals to `prior_results`

### 6.2 File Summary
Print a summary of all generated files:

```
Files generated:
  1. reports/business-review_2024-01-15_2024-01-21.md  (main report)
  2. .analytics/report-templates/business-review.json   (template updated, run #7)

Next suggested run: [next period start] to [next period end]
Suggested command: /weekly-report --name "Business Review" --period [next-period]
```

### 6.3 Diff from Last Report (Optional)
If the user requests `--diff` or if this is a recurring report (run_count > 1), offer to show what changed:
- Which metrics improved vs declined since last report
- Which action items from last report are now resolved (metric returned to normal range)
- New anomalies not present in the last report

## Edge Cases

- **First run (no template)**: Create the template interactively. For the first report, omit trend sections and historical comparisons. State "First run -- historical comparisons will be available from next period onward."
- **Partial period**: Clearly label as PARTIAL. When comparing to a full period, normalize by dividing by days elapsed and multiplying by expected days. Show both raw and normalized values. Example: "Revenue $800K through Thursday (5 days). Normalized weekly estimate: $1,120,000."
- **Missing data for a metric**: Do not leave blanks. Write "Data unavailable" in the cell and add a note explaining why. Do not exclude the metric row -- its absence would confuse readers comparing to prior reports.
- **Zero comparison value**: Cannot compute percentage change. Show absolute change only: "+$50,000 (no comparison data)".
- **Negative metrics (losses, churn)**: Ensure directional indicators account for "up_is_bad" metrics. A 10% increase in churn should be flagged as concerning (red), not positive.
- **Very small numbers**: Percentage changes on very small bases can be misleading (1 user to 2 users = +100%). If the absolute base is below a threshold (< 100 for counts, < $1000 for currency), note: "Small base -- percentage change may not be meaningful."
- **Multiple formats requested**: Generate all requested formats in a single run. Reuse computed values across formats.
- **Template schema migration**: If loading a template created by an older version of this skill (missing new fields), gracefully default the missing fields and update the template on save.
- **User provides values manually**: For any metric without a SQL query or automated source, accept manual input. Format: "Enter [Metric Name] for [period]: ". Store the values in the same structure as automated results.
- **Comparison to same period last year**: Requires 52+ weeks of history. If unavailable, state so and fall back to comparing against the most recent available period.
- **Report for non-technical audience (executive)**: Omit SQL references, technical metric definitions, and raw query details. Focus on business impact language. Replace "DAU declined 1.9%" with "Slightly fewer people used the product this week (-1.9%), but this is within the normal range."
