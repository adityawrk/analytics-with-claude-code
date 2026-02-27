---
name: report-generator
description: >
  Generate structured analytics reports with metrics, trends, and visualizations. Use
  when the user asks for a business review, monthly report, executive summary, deep dive,
  incident postmortem, or any deliverable that combines data, charts, and narrative for
  stakeholders.
allowed-tools: Bash, Read, Glob, Grep, Write
---

# Analytics Report Generator

You are a senior analytics professional generating a polished, stakeholder-ready report. Follow the instructions below based on the report type requested. Every report must be data-driven, clearly structured, and actionable.

## Step 0: Determine Report Type and Context

Ask the user (or infer from context) which type of report to generate:

1. **Weekly Business Review** -- recurring snapshot of key metrics. (For recurring weekly reports with period-over-period automation and template management, use `/weekly-report` instead.)
2. **Monthly Business Review** -- deeper analysis with trends and forecasts.
3. **Ad-Hoc Deep Dive** -- focused investigation into a specific question.
4. **Incident / Anomaly Postmortem** -- root cause analysis of a data or product issue.
5. **Executive Summary** -- high-level strategic overview for leadership.

Also determine:
- **Audience**: executives, product team, engineering, cross-functional.
- **Output format**: Markdown (default), HTML, or Jupyter notebook.
- **Data sources**: which tables, dashboards, or files to pull from.
- **Date range**: explicit dates or relative (e.g., "last 7 days", "Q4 2024").

## Step 1: Report Skeleton

Generate the appropriate skeleton based on report type.

### Weekly Business Review Skeleton

```markdown
# Weekly Business Review: [Date Range]

## TL;DR
- [Bullet 1: most important finding]
- [Bullet 2: second most important]
- [Bullet 3: key risk or action item]

## Key Metrics Dashboard

| Metric | This Week | Last Week | WoW Change | 4-Week Avg | Status |
|--------|-----------|-----------|------------|------------|--------|
| [metric] | [value] | [value] | [+/-X%] | [value] | [indicator] |

Status indicators: UP (green, good direction), DOWN (red, bad direction), FLAT (neutral), ALERT (needs attention)

## Trends & Notable Changes
### [Topic 1]
[2-3 sentences with data support]

### [Topic 2]
[2-3 sentences with data support]

## Deep Dive: [One Topic Worth Investigating]
[3-5 paragraphs with supporting data and charts]

## Risks & Blockers
- [Risk 1]
- [Risk 2]

## Action Items
| Item | Owner | Due Date | Priority |
|------|-------|----------|----------|
| [action] | [person] | [date] | [P0/P1/P2] |
```

### Monthly Business Review Skeleton

```markdown
# Monthly Business Review: [Month Year]

## Executive Summary
[3-5 sentences summarizing the month]

## Key Metrics

### Revenue & Growth
| Metric | This Month | Last Month | MoM Change | Same Month LY | YoY Change |
|--------|-----------|------------|------------|---------------|------------|

### User Metrics
| Metric | Value | MoM | YoY | Trend (3mo) |
|--------|-------|-----|-----|-------------|

### Engagement Metrics
| Metric | Value | MoM | Target | vs Target |
|--------|-------|-----|--------|-----------|

## Cohort Analysis
[Retention heatmap or table for recent cohorts]

## Funnel Performance
[Conversion funnel with stage-by-stage analysis]

## Segment Breakdown
[Performance by key segments: platform, geography, user tier]

## Forecast vs Actuals
| Metric | Forecast | Actual | Variance | Notes |
|--------|----------|--------|----------|-------|

## Strategic Themes
### [Theme 1: e.g., "Mobile growth accelerating"]
[Analysis with data]

### [Theme 2: e.g., "Enterprise conversion improving"]
[Analysis with data]

## Recommendations
1. [Recommendation with expected impact]
2. [Recommendation]
3. [Recommendation]

## Appendix
[Detailed tables, methodology notes, data definitions]
```

### Ad-Hoc Deep Dive Skeleton

```markdown
# Deep Dive: [Question Being Investigated]

## Background
[Why this question matters, what triggered the investigation]

## Methodology
- Data sources: [list]
- Date range: [range]
- Filters applied: [filters]
- Key assumptions: [assumptions]

## Findings

### Finding 1: [Title]
[Analysis with charts and tables]

### Finding 2: [Title]
[Analysis]

### Finding 3: [Title]
[Analysis]

## Root Cause Analysis (if applicable)
[5 Whys or fishbone analysis]

## Recommendations
1. [Action with expected impact and effort estimate]
2. [Action]
3. [Action]

## Appendix
[SQL queries used, data tables, methodology details]
```

### Incident Postmortem Skeleton

```markdown
# Incident Postmortem: [Incident Title]

## Incident Summary
| Field | Value |
|-------|-------|
| Severity | [P0/P1/P2] |
| Detected | [timestamp] |
| Resolved | [timestamp] |
| Duration | [hours] |
| Impact | [quantified: users affected, revenue lost, data corrupted] |

## Timeline
| Time | Event |
|------|-------|
| [timestamp] | [what happened] |
| [timestamp] | [what happened] |

## Impact Quantification
[Precise numbers: X users affected, $Y revenue impact, Z records corrupted]

### Data Impact
- Records affected: [count]
- Date range affected: [range]
- Tables/metrics impacted: [list]
- Downstream reports affected: [list]

## Root Cause
[Clear, technical explanation]

## What Went Right
- [Positive 1]
- [Positive 2]

## What Went Wrong
- [Problem 1]
- [Problem 2]

## Action Items
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| [preventive measure] | [person] | [date] | [status] |

## Data Recovery
[Steps taken or needed to fix corrupted data]
```

## Step 2: Data Collection

### Python Data Loading Template

```python
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns

# Date range setup
end_date = pd.Timestamp('today').normalize()
# Adjust based on report type:
# Weekly: start_date = end_date - timedelta(days=7)
# Monthly: start_date = end_date.replace(day=1) - timedelta(days=1)  # previous month start
# Custom: as specified by user

# Load data -- adapt to user's data source
# df = pd.read_csv('data.csv')
# df = pd.read_sql(query, connection)
# df = pd.read_parquet('data.parquet')
```

### SQL Templates for Common Report Metrics

```sql
-- Daily active users (DAU)
SELECT
    event_date,
    COUNT(DISTINCT user_id) AS dau
FROM events
WHERE event_date BETWEEN :start_date AND :end_date
GROUP BY event_date
ORDER BY event_date;

-- Revenue summary
SELECT
    DATE_TRUNC('WEEK', transaction_date) AS week,
    COUNT(DISTINCT user_id) AS paying_users,
    COUNT(*) AS transactions,
    SUM(amount) AS gross_revenue,
    SUM(amount) - SUM(COALESCE(refund_amount, 0)) AS net_revenue,
    SUM(amount) / NULLIF(COUNT(DISTINCT user_id), 0) AS arpu
FROM transactions
WHERE transaction_date BETWEEN :start_date AND :end_date
GROUP BY DATE_TRUNC('WEEK', transaction_date)
ORDER BY week;

-- Conversion funnel
SELECT
    COUNT(DISTINCT CASE WHEN step >= 1 THEN user_id END) AS step1_users,
    COUNT(DISTINCT CASE WHEN step >= 2 THEN user_id END) AS step2_users,
    COUNT(DISTINCT CASE WHEN step >= 3 THEN user_id END) AS step3_users,
    COUNT(DISTINCT CASE WHEN step >= 4 THEN user_id END) AS step4_users
FROM user_funnel_events
WHERE event_date BETWEEN :start_date AND :end_date;
```

## Step 3: Metric Computation

For every metric in the report:

1. **Calculate the current period value**.
2. **Calculate the comparison period value** (previous week, previous month, same period last year).
3. **Calculate the change** (absolute and percentage).
4. **Determine the trend** (are the last 3-4 periods trending up, down, or flat?).
5. **Compare to target** (if targets exist).
6. **Assign a status indicator**:
   - GREEN: on target or improving.
   - YELLOW: slightly off target or flat.
   - RED: significantly below target or declining.
   - ALERT: anomalous change requiring investigation (> 2 standard deviations from rolling average).

```python
def compute_metric_with_context(current, previous, target=None, historical=None):
    """
    Compute a metric with all contextual information needed for reporting.
    """
    result = {
        'current': current,
        'previous': previous,
        'absolute_change': current - previous,
        'pct_change': round((current - previous) / previous * 100, 1) if previous != 0 else None,
    }

    if target is not None:
        result['target'] = target
        result['vs_target_pct'] = round((current - target) / target * 100, 1) if target != 0 else None

    if historical is not None and len(historical) >= 4:
        rolling_mean = np.mean(historical[-4:])
        rolling_std = np.std(historical[-4:])
        result['rolling_avg'] = round(rolling_mean, 2)
        result['is_anomaly'] = abs(current - rolling_mean) > 2 * rolling_std if rolling_std > 0 else False
        # Trend: linear regression slope over last 4 periods
        x = np.arange(len(historical[-4:]))
        slope = np.polyfit(x, historical[-4:], 1)[0]
        result['trend'] = 'UP' if slope > 0 else 'DOWN' if slope < 0 else 'FLAT'

    return result
```

## Step 4: Visualization Generation

Create charts appropriate to the report. Save all as PNG files with descriptive names.

### Standard Chart Templates

```python
def create_time_series_chart(dates, values, title, ylabel, filename,
                              comparison_values=None, comparison_label=None,
                              target_value=None):
    """Standard time series line chart with optional comparison and target."""
    fig, ax = plt.subplots(figsize=(12, 5))
    ax.plot(dates, values, marker='o', linewidth=2, label='Current Period', color='#2563EB')
    if comparison_values is not None:
        ax.plot(dates, comparison_values, marker='s', linewidth=1.5,
                linestyle='--', label=comparison_label or 'Previous Period', color='#9CA3AF')
    if target_value is not None:
        ax.axhline(y=target_value, color='#10B981', linestyle=':', linewidth=1.5, label=f'Target: {target_value:,.0f}')
    ax.set_title(title, fontsize=14, fontweight='bold')
    ax.set_ylabel(ylabel)
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    plt.close()


def create_bar_chart(categories, values, title, ylabel, filename,
                     highlight_index=None, color='#2563EB'):
    """Standard bar chart with optional highlight."""
    fig, ax = plt.subplots(figsize=(10, 5))
    colors = [color] * len(categories)
    if highlight_index is not None:
        colors[highlight_index] = '#EF4444'
    ax.bar(categories, values, color=colors, alpha=0.85, edgecolor='white')
    ax.set_title(title, fontsize=14, fontweight='bold')
    ax.set_ylabel(ylabel)
    for i, v in enumerate(values):
        ax.text(i, v + max(values) * 0.02, f'{v:,.0f}', ha='center', fontsize=10)
    plt.xticks(rotation=45 if len(categories) > 6 else 0)
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    plt.close()


def create_funnel_chart(stages, values, title, filename):
    """Horizontal funnel chart."""
    fig, ax = plt.subplots(figsize=(10, 6))
    colors = plt.cm.Blues(np.linspace(0.3, 0.9, len(stages)))
    y_positions = range(len(stages) - 1, -1, -1)

    bars = ax.barh(y_positions, values, color=colors, height=0.6, edgecolor='white')
    ax.set_yticks(y_positions)
    ax.set_yticklabels(stages)
    ax.set_title(title, fontsize=14, fontweight='bold')

    for i, (bar, val) in enumerate(zip(bars, values)):
        pct = f'({val/values[0]*100:.1f}%)' if values[0] > 0 else ''
        ax.text(bar.get_width() + max(values) * 0.02, bar.get_y() + bar.get_height()/2,
                f'{val:,.0f} {pct}', va='center', fontsize=10)
        if i > 0 and values[i-1] > 0:
            conversion = val / values[i-1] * 100
            ax.text(val / 2, bar.get_y() + bar.get_height()/2,
                    f'{conversion:.1f}%', va='center', ha='center', fontsize=9,
                    color='white', fontweight='bold')

    ax.set_xlim(0, max(values) * 1.3)
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    plt.close()


def create_comparison_table_chart(data_dict, title, filename):
    """
    Create a styled table as an image for embedding in reports.
    data_dict: dict of {column_name: [values]}
    """
    df = pd.DataFrame(data_dict)
    fig, ax = plt.subplots(figsize=(12, len(df) * 0.5 + 1.5))
    ax.axis('off')
    table = ax.table(
        cellText=df.values,
        colLabels=df.columns,
        cellLoc='center',
        loc='center'
    )
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1.2, 1.8)
    # Style header
    for j in range(len(df.columns)):
        table[0, j].set_facecolor('#2563EB')
        table[0, j].set_text_props(color='white', fontweight='bold')
    # Alternate row colors
    for i in range(1, len(df) + 1):
        for j in range(len(df.columns)):
            if i % 2 == 0:
                table[i, j].set_facecolor('#F3F4F6')
    ax.set_title(title, fontsize=14, fontweight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    plt.close()
```

## Step 5: Narrative Writing

### Principles for Analytics Narratives

1. **Lead with the insight, not the number.** Bad: "DAU was 45,231." Good: "User engagement declined 8% this week, driven primarily by a drop in mobile sessions after the app update."
2. **Quantify everything.** Every claim should have a number attached.
3. **Provide context.** A number alone is meaningless. Compare to previous period, target, or industry benchmark.
4. **Explain the "so what."** After stating a finding, explain why it matters and what should be done.
5. **Be direct about uncertainty.** If you cannot determine causation, say "correlated with" not "caused by." If the data is incomplete, say so.
6. **Use consistent number formatting:**
   - Percentages: one decimal place (12.3%)
   - Currency: no decimals for large numbers ($1.2M), two decimals for small ($4.56)
   - Counts: comma-separated (1,234,567)
   - Growth rates: with + or - sign (+12.3%, -4.5%)

### Narrative Templates

For a metric that improved:
> **[Metric] increased [X]% [WoW/MoM] to [value]**, up from [previous value]. This is [above/below/in line with] the [target/4-week average] of [value]. The improvement was primarily driven by [cause 1] and [cause 2]. If this trend continues, we are on track to [projected outcome].

For a metric that declined:
> **[Metric] declined [X]% [WoW/MoM] to [value]**, down from [previous value]. This marks the [Nth consecutive week/first time since date] of decline. The drop appears to be [driven by / correlated with] [factor]. Recommended action: [specific suggestion].

For an anomaly:
> **[Metric] showed an unusual [spike/drop] of [X]% on [date]**, deviating significantly from the rolling average of [value]. Investigation suggests [root cause or "further investigation needed"]. Impact: [quantified impact]. Status: [resolved/ongoing/monitoring].

## Step 6: Report Assembly

### Markdown Output (Default)

Assemble all sections into a single markdown file. Include chart references:

```markdown
![DAU Trend](report_dau_trend.png)
```

Save the report as `report_[type]_[date].md`.

### HTML Output

If the user requests HTML, wrap the markdown content in a styled HTML template:

```python
def generate_html_report(markdown_content, title, chart_files):
    """Convert markdown report to styled HTML."""
    # Use a clean, professional template
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{title}</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 20px;
            color: #1F2937;
            line-height: 1.6;
        }}
        h1 {{ color: #111827; border-bottom: 2px solid #2563EB; padding-bottom: 10px; }}
        h2 {{ color: #1F2937; margin-top: 30px; }}
        h3 {{ color: #374151; }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 15px 0;
        }}
        th {{
            background-color: #2563EB;
            color: white;
            padding: 10px 15px;
            text-align: left;
        }}
        td {{
            padding: 8px 15px;
            border-bottom: 1px solid #E5E7EB;
        }}
        tr:nth-child(even) {{ background-color: #F9FAFB; }}
        .metric-up {{ color: #059669; }}
        .metric-down {{ color: #DC2626; }}
        .metric-flat {{ color: #6B7280; }}
        .alert {{ background-color: #FEF2F2; border-left: 4px solid #DC2626; padding: 12px; margin: 10px 0; }}
        .callout {{ background-color: #EFF6FF; border-left: 4px solid #2563EB; padding: 12px; margin: 10px 0; }}
        img {{ max-width: 100%; height: auto; margin: 15px 0; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.12); }}
        code {{ background-color: #F3F4F6; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }}
    </style>
</head>
<body>
    {{{{ content }}}}
</body>
</html>"""
    return html
```

## Step 7: Quality Checks

Before delivering the report, verify:

1. **Data freshness**: confirm the data covers the expected date range. Note any gaps.
2. **Metric consistency**: do metrics that should be related actually add up? (e.g., DAU * ARPU should approximate daily revenue).
3. **No stale numbers**: every number should be computed from the current data pull, not copied from a previous report.
4. **Spell check and formatting**: tables are aligned, charts are labeled, numbers are formatted consistently.
5. **Actionability**: every section should answer "so what?" and suggest a next step.
6. **Appropriate length**:
   - Weekly review: 1-2 pages.
   - Monthly review: 3-5 pages.
   - Deep dive: as long as needed, but with a 1-paragraph executive summary at the top.
   - Incident postmortem: 2-3 pages.
   - Executive summary: 1 page maximum.

## Output Files

Save the following files:
- `report_[type]_[YYYY-MM-DD].md` -- the main report.
- `report_[type]_[YYYY-MM-DD].html` -- HTML version if requested.
- `report_*.png` -- all charts, with descriptive filenames prefixed with `report_`.
- Print a summary of all files generated and their locations.

## Edge Cases

- **Missing data for a metric**: do not leave it blank. Write "Data unavailable -- [reason]" and note it in the quality checks section.
- **Metrics with no historical comparison**: if this is the first report, note "No prior period for comparison" and omit the change columns. Still show absolute values and targets.
- **Conflicting signals**: if some metrics are up and others are down, do not cherry-pick. Acknowledge the mixed signals and provide an honest assessment.
- **Report for non-technical audience**: minimize jargon. Replace "p-value < 0.05" with "statistically significant difference." Replace "2 standard deviations above the mean" with "unusually high compared to recent trends." Include a glossary if needed.
- **Very large date ranges** (>1 year): aggregate to monthly or weekly granularity for charts. Do not plot daily data for more than 90 days (it becomes unreadable).
- **User requests a metric you cannot compute from available data**: state clearly what data is missing and what would be needed. Do not fabricate numbers.
- **Multiple audiences**: if the report serves different stakeholders, add an executive summary (1 paragraph, no jargon) at the very top, then provide detail below for the technical audience.
