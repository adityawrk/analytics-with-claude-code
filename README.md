# Analytics with Claude Code

A production-ready [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration for analytics teams. Drop it into any project, paste your top 5 queries, and Claude becomes an analytics expert that knows your data, delegates to specialized agents, auto-reviews every output, and flags uncertainty instead of guessing.

## How It Works

The [`CLAUDE.md`](CLAUDE.md) file at the root of this repo is the core -- it's the configuration that makes everything work.

1. **You copy** [`CLAUDE.md`](CLAUDE.md) and the `.claude/` directory to your project
2. **You paste** your top 5 most-used SQL queries (reporting, ad-hoc, pipeline, metrics, debugging)
3. **Claude learns** your entire data model -- tables, columns, relationships, metrics, conventions -- and writes it all to the Learnings section
4. **Claude keeps learning** -- every session, every agent interaction, every correction you make gets captured. Session 10 is dramatically smarter than session 1
5. **Claude works** by delegating to specialized agents for execution, automatically reviewing every output for correctness, and flagging anything suspicious instead of guessing

No manual schema entry. No configuration files to fill out. No guides to read first.

## Setup

```bash
git clone https://github.com/adityawrk/analytics-with-claude-code.git
cd analytics-with-claude-code

# Option A: Interactive setup (picks skills based on your role + data stack)
bash setup.sh

# Option B: Copy everything manually
cp -r .claude/ /path/to/your-project/.claude/
cp CLAUDE.md /path/to/your-project/CLAUDE.md
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

## Agents

In Claude Code, **agents** are specialized subprocesses that run in their own context window. They receive a task, execute it independently, and return results -- without cluttering up your main conversation.

Why this matters for analytics:
- **Clean context window** -- Heavy exploration and SQL iteration happen inside agents, keeping your main chat focused on actual decisions
- **Specialized expertise** -- Each agent carries deep, domain-specific instructions (e.g. the reviewer knows 20+ categories of SQL errors to check for)
- **Parallel execution** -- Claude can dispatch multiple agents simultaneously (explore schema + write SQL + review results)
- **Built-in quality gate** -- The `analytics-reviewer` agent automatically validates every output before you see it, catching hallucinated tables, fan-out joins, wrong aggregation grain, and more

| Agent | What It Does |
|-------|-------------|
| `analyst` | Answers business questions — writes SQL, runs queries, validates results, interprets findings |
| `data-explorer` | Maps schemas, discovers tables, profiles data, traces lineage |
| `sql-developer` | Writes, tests, and iterates on SQL queries and dbt models |
| `analytics-reviewer` | Reviews every output for correctness — validates joins, metrics, NULL handling, sanity-checks numbers |
| `pipeline-builder` | Builds dbt models with tests, docs, and schema.yml following staging/intermediate/mart conventions |
| `analytics-onboarder` | Generates a complete Data Team Handbook from your codebase via static analysis |

Agents inherit the model from your chat session. No model is hardcoded -- they run at the same capability level you're using.

## Skills

In Claude Code, **skills** are slash commands -- predefined workflows you invoke by typing `/skill-name`. Each skill is a markdown file (`.claude/skills/*/SKILL.md`) containing step-by-step instructions for a specific analytical task. Think of them as reusable playbooks that encode best practices so you don't have to remember the right steps every time.

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

## Also Included

- **3 Rules** -- SQL conventions, data privacy, metric definitions (auto-applied by file type)
- **3 Hooks** -- SQL validator (blocks destructive queries), auto-formatter, audit logger
- **8 Guides** -- Reference documentation from getting started to team deployment
- **4 Challenges** -- Test your skills: data quality, query optimization, metric reconciliation, A/B test traps

## Built-In Guardrails

The CLAUDE.md includes three layers of protection:

- **Anti-hallucination protocol** -- Claude never fabricates table names, never presents numbers it didn't compute, always shows the query behind every result
- **Auto-review pipeline** -- After producing any output, the analytics-reviewer agent validates joins, grain, NULL handling, and sanity-checks the numbers
- **Agent orchestration** -- Heavy work runs in agent context windows, keeping your main conversation clean and focused

## How to Organize Your Project

Claude Code uses a hierarchy of configuration files. Understanding this helps you get the most out of it.

### CLAUDE.md hierarchy (highest to lowest priority)

1. **Project `./CLAUDE.md`** -- Project-level configuration. **This is what our repo provides.** It lives at the root of your analytics project and contains the data model, agent orchestration rules, anti-hallucination protocol, and the Learnings section that grows over time. Project-level overrides global.
2. **Global `~/.claude/CLAUDE.md`** -- Your personal preferences that apply to ALL projects (e.g., "always use trailing commas", "I prefer BigQuery syntax"). Create this for things that are about you, not a specific project.
3. **Project `.claude/` directory** -- Contains agents, skills, rules, and hooks specific to this project. Our repo provides all of these pre-configured.
4. **Rules `.claude/rules/*.md`** -- Auto-applied by file pattern via `globs` frontmatter (e.g., SQL conventions apply to all `**/*.sql` files).

The `CLAUDE.md` in this repository is a **project-level** configuration. Copy it to the root of your analytics project alongside the `.claude/` directory. Claude reads it automatically when you open Claude Code in that directory.

### Recommended project structure

```
your-analytics-project/
├── CLAUDE.md                  # The analytics configuration (from this repo)
├── .claude/
│   ├── agents/                # Specialized agents (data-explorer, sql-developer, etc.)
│   ├── skills/                # Slash commands (/eda, /ab-test, etc.)
│   ├── rules/                 # Auto-applied rules (SQL conventions, data privacy)
│   ├── hooks/                 # Pre/post tool hooks (SQL validator, audit logger)
│   └── settings.json          # Hook wiring and permissions
├── models/                    # Your dbt models (if using dbt)
├── sql/                       # Ad-hoc SQL queries
├── notebooks/                 # Jupyter notebooks
└── data/                      # Local data files (CSV, Parquet)
```

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

See [CONTRIBUTING.md](CONTRIBUTING.md). We especially welcome new skills and bug reports.

## License

[MIT](LICENSE)
