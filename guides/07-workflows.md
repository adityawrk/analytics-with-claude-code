# End-to-End Analytics Workflows with Claude Code

This guide covers five complete workflows that analytics practitioners use daily. Each includes the exact prompts, tools, and techniques to go from question to answer.

---

## Workflow 1: Ad-Hoc Analysis

**When to use:** A stakeholder asks a question. You need to explore data, write queries, and deliver an answer -- often within hours.

### Step 1: Frame the Question

Start a Claude Code session in your analytics project directory:

```bash
cd ~/projects/analytics
claude
```

Set context immediately:

```
The VP of Marketing wants to know: "Which acquisition channels have the
highest 90-day LTV for customers who signed up in Q4 2024?"

Before writing any queries, outline the analysis plan. What tables do we need?
What is the definition of LTV for this analysis? What are the edge cases?
```

Claude Code will reference your CLAUDE.md for metric definitions and table locations, then produce an analysis plan for your review.

### Step 2: Explore the Data

```
Explore the relevant tables. Show me the acquisition channels available in the
data, the date range of Q4 2024 signups, and sample rows from the revenue table.
Use the data-explorer agent for this.
```

If you have a database MCP server configured, Claude Code queries directly. Otherwise, it writes and executes Python scripts.

### Step 3: Write and Run the Query

```
Write the LTV query. Use CTEs. Follow our SQL conventions. Include a cohort
of Q4 2024 signups, their acquisition channel, and total revenue within 90 days
of signup. Run it and show results.
```

Review the query before it runs. Claude Code will show you the SQL and ask for approval (depending on your permission settings).

### Step 4: Visualize

```
Create a bar chart showing 90-day LTV by acquisition channel, sorted descending.
Add a horizontal line for the overall average. Save as outputs/ltv_by_channel.png.
```

### Step 5: Share

```
Write a Slack-ready summary of the findings. Lead with the answer, include the
key numbers, and note any caveats. Keep it under 200 words.
```

If Slack MCP is configured:

```
Post this summary to the #marketing-analytics channel.
```

### Tips for Ad-Hoc Analysis

- Start every session by stating the business question, not the SQL you want.
- Let Claude Code propose the approach, then refine it.
- Use `/compact` if the session gets long and context fills up.
- Save the final query and results for reproducibility.

---

## Workflow 2: dbt Model Development

**When to use:** You need to build a new dbt model from requirements through to production-ready code with tests and documentation.

### Step 1: Requirements

```bash
claude
```

```
I need to build a new dbt mart model called `fct_subscription_events` that
tracks all subscription lifecycle events (created, upgraded, downgraded,
cancelled, reactivated). Source data is in `raw_stripe.subscription_events`.

Show me the source table structure, then propose the model architecture
(staging -> intermediate -> mart).
```

### Step 2: Build the Staging Model

```
Create the staging model for stripe subscription events. Follow our naming
convention (stg_stripe__subscription_events). Include:
- Column renaming to snake_case
- Type casting
- Null handling
- A unique test on the primary key
- Add the model to the staging YAML file with column descriptions
```

Claude Code will create:
- `models/staging/stripe/stg_stripe__subscription_events.sql`
- An entry in `models/staging/stripe/_stripe__models.yml`

### Step 3: Build Intermediate Models (if needed)

```
Create an intermediate model that joins subscription events with customer data
and calculates the MRR impact of each event. Reference the MRR definition
in CLAUDE.md.
```

### Step 4: Build the Mart Model

```
Create the final mart model fct_subscription_events. Include:
- All relevant dimensions from the intermediate model
- Calculated fields: mrr_change, is_expansion, is_contraction
- Appropriate materialization (incremental based on event_date)
- Full YAML documentation with column descriptions
- Tests: unique on primary key, not_null on key columns,
  accepted_values on event_type
```

### Step 5: Test and Validate

```
Run the model and its tests:
1. dbt run --select +fct_subscription_events
2. dbt test --select fct_subscription_events
Show me the results. If any tests fail, fix the model.
```

### Step 6: Documentation

```
Generate the dbt docs block for this model. Include a description that explains
the grain, the source, and how to use it. Add to the YAML file.
```

### Tips for dbt Development

- Include your dbt naming conventions in CLAUDE.md. This is the single highest-value entry.
- Use the `/skill:dbt-modeler` skill if you built one (see Guide 03).
- Always have Claude Code run `dbt test` after creating models.
- For incremental models, have Claude Code test both full-refresh and incremental runs.

---

## Workflow 3: A/B Test Analysis

**When to use:** An experiment has concluded and you need to validate the data, run statistical tests, and produce a recommendation.

### Step 1: Experiment Setup Review

```bash
claude
```

```
We ran an A/B test called "checkout_redesign_v2" from Jan 15 to Feb 15, 2025.
Variant A is control (existing checkout), Variant B is the redesign.
Primary metric: conversion rate. Secondary metrics: average order value,
cart abandonment rate.

First, validate the experiment data:
1. Check that randomization is balanced (sample sizes, demographic distributions)
2. Check for data quality issues (duplicate assignments, users in both variants)
3. Show the raw metric values for each variant
```

### Step 2: Statistical Analysis

```
Run the statistical analysis:
1. Conversion rate: chi-squared test (or z-test for proportions)
2. Average order value: t-test (check for normality first; use Mann-Whitney if not normal)
3. Report: point estimate, 95% confidence interval, p-value for each metric
4. Calculate required sample size vs actual to confirm sufficient power

Use Python with scipy.stats. Show your work.
```

### Step 3: Segment Analysis

```
Break down the results by:
- Device type (mobile vs desktop)
- New vs returning users
- Geographic region

Flag any segments where the treatment effect is significantly different
from the overall effect (interaction effects).
```

### Step 4: Recommendation

```
Write the experiment summary report:
1. One-sentence recommendation (ship, iterate, or kill)
2. Key results table with confidence intervals
3. Segment insights
4. Caveats and limitations
5. Suggested follow-up experiments

Format as a markdown document. Save to reports/experiments/checkout_redesign_v2.md
```

### Tips for A/B Test Analysis

- Always validate the data before running statistics. Garbage in, garbage out.
- Include your significance threshold (typically p < 0.05) and minimum detectable effect in CLAUDE.md.
- Have Claude Code check for novelty effects by plotting the metric over time by variant.
- For Bayesian analysis, specify the prior in your prompt.

---

## Workflow 4: Incident Investigation

**When to use:** Something is broken. Revenue dropped, a dashboard is wrong, or an alert fired. You need to find the root cause fast.

### Step 1: Triage

```bash
claude
```

```
INCIDENT: Revenue dashboard is showing a 40% drop for yesterday.
This was flagged by the #data-alerts Slack channel.

Triage steps:
1. Check if the data pipeline ran successfully (dbt source freshness)
2. Check if the revenue table was updated (max event date)
3. Check if the drop is real or a data issue (compare raw source vs mart)
Do this quickly. Use the data-explorer agent for speed.
```

### Step 2: Narrow the Scope

```
The pipeline looks healthy. The drop appears real in the raw data.

Break down yesterday's revenue by:
- Payment processor (Stripe vs PayPal vs Apple)
- Product line
- Geographic region
- Customer segment (new vs existing)

Find where the 40% drop is concentrated.
```

### Step 3: Root Cause Analysis

```
The drop is concentrated in Stripe payments from the US.

Investigate:
1. Check Stripe webhook event counts (are we receiving fewer events?)
2. Check payment failure rates (are more payments failing?)
3. Check if there was a deployment yesterday that could affect checkout
4. Look at the raw Stripe events table for anomalies

Compare hour-by-hour patterns for yesterday vs the prior 7 days.
```

### Step 4: Confirm and Fix

```
Root cause identified: Stripe webhook delivery failed from 2am-8am UTC due to
an expired SSL certificate on our webhook endpoint.

1. Write a query that quantifies the exact revenue impact
2. Check if Stripe has replay capability for the missed webhooks
3. Write a data patch query to backfill the missing transactions
   (DO NOT execute it -- just write it for review)
```

### Step 5: Postmortem

```
Write an incident postmortem document:
- Timeline of events
- Root cause
- Impact (revenue affected, duration)
- Resolution steps taken
- Action items to prevent recurrence
- Monitoring improvements needed

Save to incidents/2025-02-15_stripe_webhook_failure.md
```

### Tips for Incident Investigation

- Speed matters. Use haiku agents for data exploration during incidents.
- Have your key tables and freshness checks documented in CLAUDE.md.
- Create a skill called `incident-triage` that automates the first diagnostic steps.
- Always quantify the impact in dollars and time.

---

## Workflow 5: Automated Reporting

**When to use:** You produce a recurring report (weekly, monthly) and want to automate the data pull, calculations, and formatting.

### Step 1: Create the Report Template

```bash
claude
```

```
I need to automate our weekly analytics report. Create a report template
at reports/templates/weekly_report.md with these sections:

1. Executive Summary (3 bullet points)
2. KPI Dashboard (table with WoW and MoM comparisons)
3. Revenue Deep Dive (by segment, channel, product)
4. User Metrics (DAU/WAU/MAU, retention, engagement)
5. Funnel Performance (signup -> activation -> conversion)
6. Notable Events (launches, incidents, etc.)
7. Next Week Outlook
```

### Step 2: Build the Data Pull

```
Create a Python script at scripts/weekly_report_data.py that:
1. Connects to the analytics database
2. Runs the queries for each KPI (use the definitions from CLAUDE.md)
3. Calculates WoW and MoM changes
4. Saves raw data as JSON to reports/data/weekly_<date>.json
5. Handles edge cases: holidays, missing data, partial weeks

Include error handling and logging.
```

### Step 3: Build the Report Generator

```
Create a Python script at scripts/generate_weekly_report.py that:
1. Reads the data JSON from step 2
2. Populates the report template
3. Generates charts (matplotlib) and saves to reports/weekly/charts/
4. Adds AI-generated commentary for each section by analyzing the trends
5. Saves the final report as reports/weekly/weekly_<date>.md
```

### Step 4: Create the Weekly Report Skill

```
Create a skill at .claude/skills/weekly-report.md that orchestrates the
full weekly report workflow:
1. Run the data pull script
2. Run the report generator
3. Review the output for quality
4. Ask the user to review before finalizing
5. Offer to post key metrics to Slack and commit to git
```

### Step 5: Run It Weekly

With the skill in place, the weekly workflow becomes:

```bash
claude "/skill:weekly-report Generate this week's report"
```

Claude Code runs the scripts, generates the report, creates the charts, writes commentary, and presents it for your review. You edit as needed, then approve for distribution.

### Automating with Headless Mode

For fully automated runs (e.g., via cron or CI), use Claude Code in headless mode:

```bash
# In a cron job or CI pipeline
claude --print --allowedTools "Bash,Read,Write" \
  "Run the weekly report generation: python scripts/weekly_report_data.py && python scripts/generate_weekly_report.py. Review the output for any anomalies."
```

The `--print` flag runs Claude Code non-interactively and prints the output. The `--allowedTools` flag restricts which tools can be used.

### Tips for Automated Reporting

- Keep data pull and report generation as separate scripts. This makes debugging easier.
- Version your report templates in git so you can track changes over time.
- Include data validation in the data pull step: check that numbers are within expected ranges.
- Always have a human review step before distribution, especially for reports going to executives.
- Use the `--print` flag for CI/CD integration but `--allowedTools` to restrict dangerous operations.

---

## Choosing the Right Workflow

| Situation | Workflow | Key Feature |
|-----------|----------|-------------|
| "Why did X happen?" | Ad-Hoc Analysis | Fast iteration, exploratory |
| "Build a new data model" | dbt Development | Structured, tested, documented |
| "Did the experiment work?" | A/B Test Analysis | Statistical rigor, clear recommendation |
| "Something is broken" | Incident Investigation | Speed, systematic diagnosis |
| "Produce the weekly numbers" | Automated Reporting | Reproducible, templated |

Most real work combines workflows. An incident investigation might lead to a dbt model fix. An A/B test analysis might require ad-hoc exploration first. The key is knowing which playbook to start with.
