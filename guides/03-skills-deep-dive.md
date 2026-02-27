# Building Custom Skills for Analytics

## What Skills Are

Skills are reusable knowledge modules that Claude Code loads on demand. Unlike CLAUDE.md (which loads on every session), a skill is loaded only when invoked. This keeps your context window lean while giving you deep expertise exactly when you need it.

Think of skills as playbooks. A "data profiler" skill tells Claude Code exactly how you want datasets profiled. A "weekly report" skill tells it how to pull numbers, format tables, and write commentary. You write the instructions once; you use them forever.

## Anatomy of a SKILL.md File

A skill is a markdown file with YAML frontmatter, placed in `.claude/skills/`:

```markdown
---
name: "data-profiler"
description: "Profile a dataset with standard statistics, distributions, and quality checks"
invocation: "both"
---

# Data Profiler

When asked to profile a dataset, follow these steps:

1. Load the data using pandas or polars (prefer polars for files > 100MB)
2. Report:
   - Row count and column count
   - For each column: data type, null count, null %, unique count
   - For numeric columns: min, max, mean, median, std dev, p5, p25, p75, p95
   - For categorical columns (<50 unique): value counts with percentages
   - For date columns: min date, max date, gaps in expected dates
3. Flag data quality issues:
   - Columns with >10% nulls
   - Potential duplicate rows
   - Columns where a single value dominates (>90%)
   - Numeric outliers beyond 3 standard deviations
4. Save the profile as a markdown file in the current directory
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Identifier used to invoke the skill |
| `description` | Yes | Short description shown in skill listings |
| `invocation` | No | Who can trigger it: `user` (slash command only), `claude` (auto-detected), `both` (default) |

### Invocation Control

- **`user`** -- The skill is only loaded when you type `/skill:data-profiler`. Claude Code will never load it on its own.
- **`claude`** -- Claude Code can load this skill automatically when it determines the task matches. You cannot invoke it manually.
- **`both`** (default) -- Either you or Claude Code can trigger it.

For analytics skills, `both` is usually the right choice. You want to be able to type `/skill:data-profiler` explicitly, but you also want Claude Code to use it when you say "profile this dataset."

## Dynamic Context Injection

Skills can include shell commands that run at load time and inject their output into the context:

```markdown
---
name: "dbt-modeler"
description: "Build dbt models following project conventions"
invocation: "both"
---

# dbt Model Builder

## Current Project State
Available models:
`ls models/staging/ models/intermediate/ models/marts/ 2>/dev/null`

Recent model changes:
`git log --oneline -10 -- 'models/'`

dbt project config:
`cat dbt_project.yml`

## Instructions
When building a new dbt model:
1. Check if a staging model exists for the source. If not, create one first.
2. Follow the naming convention from CLAUDE.md.
...
```

The backtick-wrapped commands execute when the skill loads, so Claude Code always has fresh context about your project state. Use this for:

- Listing available tables or models
- Showing recent git changes
- Displaying current configuration
- Checking environment status

## Walkthrough: Building a Data Profiler Skill

### Step 1: Create the Skill File

```bash
mkdir -p .claude/skills
```

Create `.claude/skills/data-profiler.md`:

```markdown
---
name: "data-profiler"
description: "Comprehensive dataset profiling with quality checks"
invocation: "both"
---

# Data Profiler Skill

## Profiling Procedure

When asked to profile a dataset (CSV, Parquet, or database table):

### Step 1: Load and Inspect
- Use polars if available, fall back to pandas
- Print shape (rows x columns) immediately
- Detect and report file encoding issues

### Step 2: Column-Level Statistics
For EVERY column, report in a markdown table:

| Column | Type | Nulls | Null% | Unique | Sample Values |
|--------|------|-------|-------|--------|--------------|

Then for each data type:

**Numeric columns:**
| Column | Min | Max | Mean | Median | Std Dev | P5 | P25 | P75 | P95 |
|--------|-----|-----|------|--------|---------|----|----|-----|-----|

**Categorical columns (< 100 unique values):**
Show top 10 and bottom 5 values with counts and percentages.

**Date/datetime columns:**
| Column | Min | Max | Range | Gaps |
|--------|-----|-----|-------|------|

### Step 3: Data Quality Assessment
Flag and explain:
- Columns > 5% null (WARNING) or > 20% null (CRITICAL)
- Potential ID columns (unique count = row count)
- Constant columns (1 unique value) -- candidates for removal
- High cardinality categoricals (> 1000 unique) -- may need bucketing
- Duplicate rows (exact and near-duplicate)

### Step 4: Output
Save as `profile_<filename>_<date>.md` in the current directory.
Print a summary to the console.

### Step 5: Suggest Next Steps
Based on the profile, suggest:
- Columns to investigate further
- Potential join keys if multiple files are present
- Data cleaning steps needed before analysis
```

### Step 2: Test It

```bash
claude "/skill:data-profiler Profile the file sales_q4.csv"
```

Or simply:

```bash
claude "Profile the file sales_q4.csv"
```

If invocation is set to `both`, Claude Code will auto-detect and load the skill.

### Step 3: Iterate

After the first run, refine the skill. Common additions:

- Add a section for correlation matrices on numeric columns.
- Add handling for geospatial columns.
- Add specific checks for your domain (e.g., "revenue should never be negative").

## Walkthrough: Building a Weekly Report Skill

Create `.claude/skills/weekly-report.md`:

```markdown
---
name: "weekly-report"
description: "Generate the weekly analytics report with KPIs and commentary"
invocation: "user"
---

# Weekly Report Generator

## Context
Current report week:
`date -v-7d +%Y-%m-%d` to `date +%Y-%m-%d`

Previous reports for reference:
`ls -la reports/weekly/ 2>/dev/null | tail -5`

## Report Structure

Generate the weekly analytics report following this exact structure:

### 1. KPI Summary Table

| Metric | This Week | Last Week | WoW Change | MoM Change |
|--------|-----------|-----------|------------|------------|
| Revenue | | | | |
| Active Users (DAU avg) | | | | |
| New Signups | | | | |
| Churn Rate | | | | |
| ARPU | | | | |

### 2. Data Extraction
Run these queries (adjust dates for the current week):

**Revenue:**
```sql
SELECT
  DATE_TRUNC('week', order_date) AS week,
  SUM(amount) AS revenue,
  COUNT(DISTINCT customer_id) AS paying_customers
FROM analytics.marts.fct_orders
WHERE order_date >= CURRENT_DATE - INTERVAL '8 weeks'
GROUP BY 1
ORDER BY 1 DESC
```

**Active Users:**
```sql
SELECT
  DATE_TRUNC('week', event_date) AS week,
  COUNT(DISTINCT user_id) AS active_users
FROM analytics.marts.fct_activity
WHERE event_date >= CURRENT_DATE - INTERVAL '8 weeks'
GROUP BY 1
ORDER BY 1 DESC
```

### 3. Commentary
For each KPI:
- State the number and direction plainly
- If change > 10%, investigate and explain the driver
- Reference specific events, launches, or issues if known

### 4. Charts
Create these charts using matplotlib:
- Revenue trend (8 weeks, bar chart)
- DAU trend (8 weeks, line chart)
- Signup funnel (this week vs last week, horizontal bar)

Save charts to `reports/weekly/charts/`.

### 5. Output
Save the report as `reports/weekly/weekly_report_<date>.md`.
Print a summary to the console.

### 6. Delivery
After generating, ask the user if they want to:
- Commit the report to git
- Share key numbers (offer to format for Slack)
```

Set invocation to `user` because this is a deliberate weekly task, not something Claude Code should auto-trigger.

Invoke it:

```bash
claude "/skill:weekly-report Generate this week's report"
```

## Installing Skills from This Repository

To use any of the skills included in this repository:

```bash
# Clone the repo
git clone https://github.com/your-org/analytics-with-claude-code.git

# Copy skills to your project
cp -r analytics-with-claude-code/skills/* your-project/.claude/skills/

# Or symlink for automatic updates
ln -s /path/to/analytics-with-claude-code/skills/data-profiler.md \
      your-project/.claude/skills/data-profiler.md
```

You can also selectively copy only the skills you need.

## Best Practices

### Scope

Each skill should do one thing well. Do not combine data profiling and visualization and report writing into a single skill. Make three skills and let them compose.

Good scope:
- "Profile a dataset"
- "Generate a weekly report"
- "Build a dbt staging model"
- "Analyze an A/B test"

Bad scope:
- "Do all analytics tasks"
- "Be a data engineer"

### Specificity

Vague instructions produce vague results. Compare:

**Vague:**
```
Analyze the data and produce a report.
```

**Specific:**
```
For each numeric column, compute: min, max, mean, median, std dev, p5, p95.
Present results in a markdown table with columns aligned.
Flag any column where std dev > 2x the mean as "high variance."
```

The specific version produces consistent, predictable output every time.

### Testing

Test skills by running them on known data and checking the output:

1. Create a small test dataset with known properties (nulls, duplicates, outliers).
2. Run the skill against it.
3. Verify the output matches expectations.
4. Refine the skill instructions.

### Composability

Design skills that work together. Your weekly report skill can reference the profiler skill:

```markdown
If the data source has changed since last week, run the data-profiler skill
first to check for schema changes or quality regressions.
```

### Size

Keep skills under 200 lines. If a skill is getting longer, split it into multiple skills or extract reference data into imported files.
