# Analytics with Claude Code

A gold-standard [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration for analytics teams. Drop it into any project, paste your top 5 queries, and Claude becomes an analytics expert that knows your data, delegates to specialized agents, auto-reviews every output, and never hallucinates.

![License](https://img.shields.io/badge/license-MIT-blue) ![Skills](https://img.shields.io/badge/skills-10-green) ![Agents](https://img.shields.io/badge/agents-5-purple)

## How It Works

1. **You copy** the `.claude/` directory and `CLAUDE.md` to your project
2. **You paste** your top 5 most-used SQL queries (reporting, ad-hoc, pipeline, metrics, debugging)
3. **Claude learns** your entire data model -- tables, columns, relationships, metrics, conventions
4. **Claude works** by delegating to specialized agents for execution, automatically reviewing every output for correctness, and flagging anything suspicious instead of guessing

No manual schema entry. No configuration files to fill out. No guides to read first.

## Setup

```bash
git clone https://github.com/adityawrk/analytics-with-claude-code.git
cd analytics-with-claude-code

# Option A: Interactive setup (picks skills based on your role + data stack)
bash setup.sh

# Option B: Copy everything manually
cp -r .claude/ /path/to/your-project/.claude/
cp templates/CLAUDE.md.template /path/to/your-project/CLAUDE.md
```

Then open Claude Code in your project and paste your queries. That's it.

## Try It Without Any Setup

A DuckDB demo with sample data -- no database, no API keys:

```bash
cd demo
pip install duckdb && python setup_demo_data.py
claude
```

Ask Claude anything: `/eda`, "top 10 customers by revenue", "build a cohort retention analysis".

## What's Inside

### Skills (slash commands)

| Skill | What It Does |
|-------|-------------|
| `/eda` | Full exploratory data analysis -- distributions, nulls, correlations, outliers |
| `/sql-optimizer` | Analyze slow queries, suggest indexes, rewrite for performance |
| `/data-quality` | Completeness, uniqueness, freshness checks with a scorecard |
| `/metric-calculator` | Retention, LTV, churn, conversion funnels, growth rates |
| `/ab-test` | Sample validation, significance testing, recommendations |
| `/report-generator` | Structured reports with charts, trends, executive summaries |
| `/explain-sql` | Plain-English explanation + Mermaid data flow diagram for any query |
| `/metric-reconciler` | Find exactly why two queries for the same metric disagree |
| `/weekly-report` | Recurring report automation with period-over-period diffing |
| `/systematic-debug` | 4-phase structured debugging with 3-strike escalation rule |

### Agents (specialized workers with their own context)

| Agent | Does | Model |
|-------|------|-------|
| `data-explorer` | Maps schemas, discovers tables, profiles data | Haiku (fast) |
| `sql-developer` | Writes, tests, and iterates on SQL and dbt models | Sonnet |
| `analytics-reviewer` | Reviews queries for correctness, validates metrics, catches bugs | Sonnet |
| `pipeline-builder` | Builds dbt models with tests, docs, and schema.yml | Sonnet |
| `analytics-onboarder` | Generates a complete Data Team Handbook from your codebase | Sonnet |

### Also included

- **3 Rules** -- SQL conventions, data privacy, metric definitions (auto-applied by file type)
- **3 Hooks** -- SQL validator (blocks destructive queries), auto-formatter, audit logger
- **8 Guides** -- Reference documentation from getting started to team deployment
- **4 Challenges** -- Test your skills: data quality, query optimization, metric reconciliation, A/B test traps

## Built-In Guardrails

The CLAUDE.md includes three layers of protection:

- **Anti-hallucination protocol** -- Claude never fabricates table names, never presents numbers it didn't compute, always shows the query behind every result
- **Auto-review pipeline** -- After producing any output, the analytics-reviewer agent validates joins, grain, NULL handling, and sanity-checks the numbers
- **Agent orchestration** -- Heavy work runs in agent context windows, keeping your main conversation clean and focused

## What You Can Automate

| Task | Before | After |
|------|--------|-------|
| Profile a new dataset | 2-4 hours | `/eda` -- 5 min |
| Weekly reporting | 3-5 hours | `/weekly-report` -- 10 min |
| A/B test analysis | 1-2 hours | `/ab-test` -- 5 min |
| Onboard to unfamiliar data | 1-2 weeks | `analytics-onboarder` agent -- 10 min |
| Debug a broken query | 30-60 min | `/systematic-debug` -- 10 min |
| Explain inherited SQL | 30-60 min | `/explain-sql` -- 2 min |
| Reconcile conflicting metrics | Days | `/metric-reconciler` -- 15 min |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). We especially welcome new skills, community configurations in `community/`, and bug reports.

## License

[MIT](LICENSE)
