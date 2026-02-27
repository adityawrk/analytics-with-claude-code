# Crafting the Perfect CLAUDE.md for Analytics Projects

## Why CLAUDE.md Matters

CLAUDE.md is loaded into context at the start of every Claude Code session. It is the single most effective way to make Claude Code understand your project. Without it, Claude Code is a skilled generalist. With it, Claude Code becomes a team member who knows your schemas, your conventions, and your metric definitions.

For analytics teams, this is transformative. Every analyst on the team gets the same institutional knowledge loaded automatically. No more Slack messages asking "which table has the canonical revenue number?" -- it is in CLAUDE.md.

## The Memory Hierarchy

Claude Code reads instructions from multiple sources, in this priority order:

| Priority | Source | Scope | How to Set |
|----------|--------|-------|-----------|
| 1 (highest) | Managed policy | Organization-wide | Admin dashboard |
| 2 | Project rules | Per-project | `.claude/rules/*.md` files |
| 3 | CLAUDE.md | Per-project | `CLAUDE.md` in project root |
| 4 | User rules | Per-user | `~/.claude/CLAUDE.md` |
| 5 (lowest) | Auto-generated | Per-project | Created by `/memory` command |

For analytics teams, the most important layers are:

- **CLAUDE.md** (committed to git) -- shared project knowledge.
- **.claude/rules/*.md** -- specialized rules that apply conditionally.
- **CLAUDE.local.md** -- personal overrides (not committed to git).

## What to Include

Keep your CLAUDE.md focused on information that changes how Claude Code behaves. Every line should either prevent a mistake or save a question.

### 1. Data Sources and Schemas

```markdown
## Data Sources

### Production Database (PostgreSQL)
- `public.users` -- User accounts. Primary key: `id`. ~2M rows.
- `public.events` -- Clickstream events. Primary key: `id`. ~500M rows. Partitioned by `created_at`.
- `public.subscriptions` -- Subscription state. Use `status = 'active'` for current subs.

### Analytics Warehouse (BigQuery)
- `analytics.staging.stg_users` -- Cleaned user dimension
- `analytics.marts.fct_revenue` -- Revenue fact table (source of truth for all revenue metrics)
- `analytics.marts.dim_customers` -- Customer dimension with segments

### Important Notes
- NEVER query `public.events` without a date filter. The table is 500M+ rows.
- Revenue data before 2023-01-01 is unreliable due to a billing migration.
- The `deleted_at` column in `users` is soft-delete. Always filter `WHERE deleted_at IS NULL` unless analyzing churn.
```

### 2. SQL Conventions

```markdown
## SQL Style Guide
- Use CTEs, not subqueries
- CTE names should describe the transformation: `filtered_events`, `aggregated_revenue`
- Always alias tables with meaningful abbreviations
- Use `COALESCE(column, 0)` for nullable numeric columns in aggregations
- Date functions: use `DATE_TRUNC('month', created_at)` (BigQuery syntax)
- Qualify all column references with table alias when joining
```

### 3. Key Metric Definitions

```markdown
## Metric Definitions

### MRR (Monthly Recurring Revenue)
Sum of all active subscription `monthly_amount` values at the last moment of the month.
Source of truth: `analytics.marts.fct_mrr`
Formula: `SUM(monthly_amount) WHERE status = 'active' AND as_of_date = LAST_DAY(month)`

### Active Users (DAU/WAU/MAU)
A user is "active" if they triggered any event in `public.events` with `event_type NOT IN ('pageview', 'heartbeat')`.
Do NOT count pageviews as activity.

### Churn Rate
Lost MRR / Beginning-of-period MRR.
Use `analytics.marts.fct_mrr_movement` which has pre-calculated movements.
```

### 4. Common Commands

```markdown
## Commands
- Run dbt models: `dbt run --select +model_name`
- Run tests: `dbt test --select model_name`
- Generate docs: `dbt docs generate && dbt docs serve`
- Lint SQL: `sqlfluff lint models/`
- Run Python analysis: `python -m analytics.run --analysis <name>`
- Export to CSV: `python scripts/export.py --query "SELECT ..." --output results.csv`
```

### 5. Project Structure

```markdown
## Project Structure
```
models/
  staging/       -- 1:1 with source tables, light cleaning only
  intermediate/  -- Business logic joins and transformations
  marts/         -- Final tables consumed by BI tools
analyses/        -- Ad-hoc analysis scripts (Python)
tests/           -- dbt tests and Python test files
macros/          -- dbt Jinja macros
```
```

## What NOT to Include

CLAUDE.md is loaded on every session. Keep it under 150 lines. Do not include:

- **Full table schemas.** Reference them; do not paste DDL. Use `@imports` for schema files.
- **Entire style guides.** Include the top 5 rules. Put the full guide in `.claude/rules/`.
- **Historical context.** "We migrated from Redshift in 2022" is not actionable.
- **Obvious instructions.** "Write clean code" adds nothing.
- **Credentials or secrets.** Never put connection strings or API keys in CLAUDE.md.

## Real Examples

### Example: dbt Project

```markdown
# Analytics dbt Project

## Database
- Warehouse: BigQuery, project `acme-analytics`, dataset `analytics`
- Source schemas: `raw_stripe`, `raw_hubspot`, `raw_segment`

## Conventions
- Model naming: `stg_<source>__<entity>`, `int_<entity>_<verb>`, `fct_<entity>`, `dim_<entity>`
- All models must have a `_loaded_at` timestamp from the source
- Use `{{ ref('model_name') }}` never hardcode table names
- Tests: every model needs unique + not_null on primary key at minimum

## Key Metrics
- ARR: `SUM(monthly_amount) * 12` from `fct_subscriptions` where `is_active = true`
- Net Revenue Retention: `(Beginning ARR + Expansion - Contraction - Churn) / Beginning ARR`

## Commands
- Run staging: `dbt run --select staging`
- Run full refresh: `dbt run --full-refresh --select model_name`
- Check freshness: `dbt source freshness`

## Important
- NEVER use `dbt run` without `--select`. Full runs take 45 minutes.
- The `raw_stripe` schema has PII. Do not SELECT * from it.
```

### Example: Python Analytics Repo

```markdown
# Customer Analytics

## Environment
- Python 3.11, managed with `uv`
- Install: `uv sync`
- Run analysis: `uv run python -m analytics <analysis_name>`

## Database Access
- Connection config in `.env` (never commit this)
- Use `from analytics.db import get_engine` for all database access
- Default warehouse: Snowflake, database `ANALYTICS`, schema `MARTS`

## Conventions
- Analysis scripts go in `analyses/` with descriptive names
- Each analysis has a `run()` function as entry point
- Use `polars` for dataframes (not pandas)
- Charts use `plotly` and save to `outputs/<analysis_name>/`
- SQL queries live in `queries/` as `.sql` files, loaded with `analytics.sql.load()`

## Key Tables
- `MARTS.FCT_ORDERS` -- Order-level revenue data
- `MARTS.DIM_CUSTOMERS` -- Customer attributes and segments
- `MARTS.FCT_SESSIONS` -- Web session data from Segment
```

### Example: Jupyter Notebook Project

```markdown
# Research Analytics Notebooks

## Setup
- Environment: `conda activate research`
- Jupyter: `jupyter lab --port 8888`
- Kernel: `research-py311`

## Data Access
- BigQuery: use `from google.cloud import bigquery; client = bigquery.Client()`
- Local files in `data/` are gitignored. Download with `make data`

## Notebook Conventions
- First cell: imports and config (copy from `templates/header.py`)
- Use `watermark` extension to record package versions
- Clear all outputs before committing
- Name notebooks: `YYYY-MM-DD_<descriptive-name>.ipynb`

## Plotting
- Use `matplotlib` with the `acme` style: `plt.style.use('acme')`
- Standard figure size: `(12, 6)`
- Always include axis labels and a title
- Save figures to `figures/` as both PNG and SVG
```

## Using @imports for External Documentation

For large reference documents, use `@imports` to include them only when relevant:

```markdown
# Analytics Project

## Schema Reference
@analyses/schema_reference.md

## Full Style Guide
@docs/sql_style_guide.md
```

The imported files are loaded into context alongside CLAUDE.md. This keeps your main file concise while still providing deep reference material when needed.

## Team vs Personal Configuration

### Shared Configuration (committed to git)

- `CLAUDE.md` -- Project-level knowledge everyone needs.
- `.claude/rules/*.md` -- Conditional rules (e.g., `sql-style.md` loaded when editing SQL).
- `.claude/settings.json` -- Shared tool permissions and MCP servers.

### Personal Configuration (not committed)

- `CLAUDE.local.md` -- Your personal overrides. Example uses:
  - "I prefer verbose explanations."
  - "My local database is on port 5433."
  - "I work in the Pacific timezone."

- `.claude/settings.local.json` -- Personal MCP servers or tool permissions.

Create a `.gitignore` entry:

```
CLAUDE.local.md
.claude/settings.local.json
```

## Iteration Tips

Your CLAUDE.md will evolve. Here is how to keep it sharp:

1. **Start small.** 20 lines is fine. Add content when Claude Code makes a mistake that CLAUDE.md could have prevented.
2. **Use /memory.** After a session where you corrected Claude Code repeatedly, run `/memory` and let it suggest additions.
3. **Review quarterly.** Delete lines that no longer apply. Metric definitions change. Tables get deprecated.
4. **Test it.** Start a fresh session and ask Claude Code a question that requires project knowledge. If it gets it wrong, your CLAUDE.md needs work.
