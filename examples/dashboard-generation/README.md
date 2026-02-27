# Example: Dashboard and Report Generation

## Scenario
Leadership wants a weekly business metrics dashboard covering revenue, user growth, engagement, and operational health. You need to build the underlying queries and generate a formatted report.

## Steps

### 1. Define metrics with the metric calculator
```bash
cd examples/dashboard-generation
claude
```

```
> /metric-calculator
> I need these metrics for a weekly dashboard:
> - Total revenue and MoM growth
> - New users and retention (week 1, week 4)
> - DAU/MAU ratio
> - Conversion rate (session to purchase)
> - Average order value
```

Claude will generate SQL templates for each metric with proper date filtering, null handling, and growth calculations.

### 2. Generate the report
```
> /report-generator --type weekly --title "Weekly Business Review"
> Include: revenue summary, user growth, engagement metrics, and conversion funnel.
> Compare to last week and same week last year.
```

Claude will:
- Execute the metric queries
- Calculate period-over-period comparisons
- Generate trend analysis
- Produce a structured markdown report with tables and chart code
- Include an executive summary with key callouts

### 3. Customize and iterate
```
> Add a section breaking down revenue by product category
> Add a chart showing the DAU trend over the last 12 weeks
> Flag any metrics that changed more than 10% week over week
```

## What You'll Learn
- How to use `/metric-calculator` for standard business metrics
- How to generate structured reports with `/report-generator`
- How to iterate on report content conversationally
- How to build reusable reporting workflows
