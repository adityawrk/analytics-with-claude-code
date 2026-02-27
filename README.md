# Analytics with Claude Code

> The definitive guide to using [Claude Code](https://docs.anthropic.com/en/docs/claude-code) for analytics. Production-ready skills, agents, hooks, and workflows for data analysts, analytics engineers, and data scientists.

**Stop writing boilerplate. Start shipping insights.**

Claude Code is an agentic coding tool that lives in your terminal. This repository teaches you how to turn it into the most powerful analytics assistant you've ever had -- one that knows your data, follows your conventions, and automates the work that eats your week.

---

## What's Inside

### [Skills](/.claude/skills) -- Reusable analytics automations
Drop-in slash commands that handle real work:

| Skill | What It Does |
|-------|-------------|
| [`/eda`](/.claude/skills/eda/SKILL.md) | Full exploratory data analysis -- distributions, nulls, correlations, outliers |
| [`/sql-optimizer`](/.claude/skills/sql-optimizer/SKILL.md) | Analyze slow queries, suggest indexes, rewrite for performance |
| [`/data-quality`](/.claude/skills/data-quality/SKILL.md) | Completeness, uniqueness, freshness, and accuracy checks with a scorecard |
| [`/metric-calculator`](/.claude/skills/metric-calculator/SKILL.md) | Retention, LTV, CAC, churn, conversion funnels, growth rates |
| [`/ab-test`](/.claude/skills/ab-test/SKILL.md) | Sample validation, significance testing, confidence intervals, recommendations |
| [`/report-generator`](/.claude/skills/report-generator/SKILL.md) | Structured analytics reports with charts, trends, and executive summaries |

### [Agents](/.claude/agents) -- Specialized analytics assistants
Custom subagents that handle complex multi-step work:

| Agent | Role | Model |
|-------|------|-------|
| [`data-explorer`](/.claude/agents/data-explorer.md) | Discover schemas, map relationships, document data sources | Haiku (fast) |
| [`sql-developer`](/.claude/agents/sql-developer.md) | Write, test, and iterate on complex SQL and dbt models | Sonnet |
| [`analytics-reviewer`](/.claude/agents/analytics-reviewer.md) | Review queries for correctness, validate metrics, catch bias | Sonnet |
| [`pipeline-builder`](/.claude/agents/pipeline-builder.md) | Build dbt models, data tests, source configs, and docs | Sonnet |

### [Rules](/.claude/rules) -- Guardrails and conventions
Modular rules that Claude follows automatically:

- **[SQL Conventions](/.claude/rules/sql-conventions.md)** -- CTEs over subqueries, naming standards, performance patterns
- **[Data Privacy](/.claude/rules/data-privacy.md)** -- PII handling, anonymization, minimum group sizes
- **[Metric Definitions](/.claude/rules/metric-definitions.md)** -- Canonical definitions for revenue, retention, growth, engagement

### [Hooks](/.claude/hooks) -- Automated safety nets
Scripts that run before/after Claude's actions:

- **[SQL Validator](/.claude/hooks/validate-sql.sh)** -- Blocks destructive queries, warns on missing WHERE clauses
- **[SQL Formatter](/.claude/hooks/auto-format-sql.sh)** -- Auto-formats SQL after every edit

### [Guides](/guides) -- Learn everything, step by step
8 comprehensive guides from zero to team-scale deployment:

1. **[Getting Started](/guides/01-getting-started.md)** -- Install, configure, run your first analysis
2. **[CLAUDE.md for Analytics](/guides/02-claude-md-for-analytics.md)** -- Teach Claude your data stack
3. **[Skills Deep Dive](/guides/03-skills-deep-dive.md)** -- Build custom analytics skills
4. **[Agents Deep Dive](/guides/04-agents-deep-dive.md)** -- Create specialized analytics agents
5. **[Hooks and Automation](/guides/05-hooks-and-automation.md)** -- Automate safety and formatting
6. **[MCP Integrations](/guides/06-mcp-integrations.md)** -- Connect to databases and tools
7. **[Workflows](/guides/07-workflows.md)** -- End-to-end analytics workflows
8. **[Team Setup](/guides/08-team-setup.md)** -- Deploy for your whole analytics team

### [Templates](/templates) -- Start fast
Copy-paste configurations for common setups:

- **[CLAUDE.md Template](/templates/CLAUDE.md.template)** -- Analytics project starter config
- **[MCP Configs](/templates)** -- Pre-built configs for PostgreSQL, BigQuery, Snowflake
- **[Settings Template](/templates/settings.json.template)** -- Permission rules for analytics teams

---

## Quick Start

### 1. Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### 2. Clone this repo and copy what you need
```bash
git clone https://github.com/YOUR_USERNAME/analytics-with-claude-code.git
cd analytics-with-claude-code

# Copy skills to your project
cp -r .claude/skills/ /path/to/your-project/.claude/skills/

# Copy agents to your project
cp -r .claude/agents/ /path/to/your-project/.claude/agents/

# Copy rules to your project
cp -r .claude/rules/ /path/to/your-project/.claude/rules/

# Or copy everything
cp -r .claude/ /path/to/your-project/.claude/
```

### 3. Add a CLAUDE.md to your analytics project
Start with the [template](/templates/CLAUDE.md.template) and customize:
```bash
cp templates/CLAUDE.md.template /path/to/your-project/CLAUDE.md
# Edit with your data sources, conventions, and commands
```

### 4. Start using it
```bash
cd /path/to/your-project
claude

# Try a skill
> /eda sales_data.csv

# Ask it to analyze something
> What were our top 10 customers by revenue last quarter?

# Use an agent for complex work
> Use the sql-developer agent to build a cohort retention model
```

---

## How It Works

Claude Code reads your project's `.claude/` directory on startup:

```
your-project/
├── CLAUDE.md                  # Your data sources, conventions, commands
├── .claude/
│   ├── skills/                # Slash commands (/eda, /ab-test, etc.)
│   ├── agents/                # Specialized subagents
│   ├── rules/                 # Auto-applied conventions
│   ├── hooks/                 # Pre/post action scripts
│   └── settings.json          # Permissions and hook wiring
└── ... your analytics code
```

- **CLAUDE.md** loads at session start -- it's your project's institutional knowledge
- **Skills** load on-demand when you invoke them (`/eda`) or Claude decides they're relevant
- **Agents** are spawned as isolated subprocesses for complex tasks
- **Rules** auto-apply based on file patterns (e.g., SQL rules activate for `*.sql` files)
- **Hooks** run before/after tool use (e.g., validate SQL before execution)

---

## What Can You Automate?

| Task | Time Before | Time After | How |
|------|------------|------------|-----|
| Exploratory data analysis | 2-4 hours | 5 minutes | `/eda` skill |
| Weekly reporting | 3-5 hours | 10 minutes | `/report-generator` skill |
| A/B test analysis | 1-2 hours | 5 minutes | `/ab-test` skill |
| SQL query writing | 30-60 min | 2 minutes | Natural language + rules |
| Data quality checks | 1-2 hours | 5 minutes | `/data-quality` skill |
| dbt model creation | 1-2 hours | 10 minutes | `pipeline-builder` agent |
| Code review (analytics) | 30-60 min | 5 minutes | `analytics-reviewer` agent |

---

## Repository Structure

```
analytics-with-claude-code/
├── .claude/
│   ├── skills/                 # 6 production-ready analytics skills
│   │   ├── eda/
│   │   ├── sql-optimizer/
│   │   ├── data-quality/
│   │   ├── metric-calculator/
│   │   ├── ab-test/
│   │   └── report-generator/
│   ├── agents/                 # 4 specialized analytics agents
│   │   ├── data-explorer.md
│   │   ├── sql-developer.md
│   │   ├── analytics-reviewer.md
│   │   └── pipeline-builder.md
│   ├── rules/                  # 3 modular rule sets
│   │   ├── sql-conventions.md
│   │   ├── data-privacy.md
│   │   └── metric-definitions.md
│   ├── hooks/                  # 2 automation hooks
│   │   ├── validate-sql.sh
│   │   └── auto-format-sql.sh
│   └── settings.json           # Permission and hook configuration
├── guides/                     # 8 comprehensive learning guides
├── examples/                   # Complete working examples
├── templates/                  # Copy-paste starter configs
├── CLAUDE.md                   # This project's own config (meta!)
├── CONTRIBUTING.md
└── LICENSE (MIT)
```

---

## Contributing

We welcome contributions! Whether it's a new skill, an improved guide, or a bug fix -- see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

**High-impact contributions we'd love:**
- New skills for common analytics tasks (funnel analysis, cohort analysis, forecasting)
- MCP server configurations for popular data tools
- Example workflows with real (anonymized) datasets
- Translations of guides
- Bug reports and improvement suggestions

---

## License

[MIT](LICENSE) -- use freely in personal and commercial projects.

---

## Acknowledgments

Built with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by [Anthropic](https://www.anthropic.com).

Inspired by the analytics community and the practitioners who spend their days turning data into decisions.
