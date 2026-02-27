# Community Configurations

Share your `.claude/` setup! Submit a PR with your team's configuration.

Every analytics team has different tools, conventions, and workflows. This directory collects real-world configurations so you can learn from how others have adapted Claude Code to their stack.

---

## How to Submit

1. Fork this repository
2. Create a directory: `community/your-industry-or-use-case/`
3. Include: your customized CLAUDE.md, any custom skills, and a README explaining your setup
4. Submit a PR

### What to Include

Your submission directory should follow this structure:

```
community/your-industry-or-use-case/
├── README.md      — Describe your stack, team size, and what you customized
├── CLAUDE.md      — Your project's Claude Code config (anonymize sensitive data)
└── .claude/       — Any custom skills, rules, or hooks
```

### Guidelines

- **Anonymize everything.** Remove company names, real table names, credentials, and internal URLs. Replace them with realistic placeholders.
- **Explain your choices.** The README is the most valuable part -- tell us why you configured things the way you did.
- **Keep it focused.** You don't need to include every file. Share the parts that are unique or interesting about your setup.

---

## Featured Configurations

*Coming soon -- be the first to submit!*

---

## Template

Use this as a starting point for your submission's README:

```markdown
# [Your Industry / Use Case]

## Stack
- **Database:** (e.g., Snowflake, BigQuery, PostgreSQL)
- **Orchestrator:** (e.g., dbt, Airflow, Dagster)
- **BI Tool:** (e.g., Looker, Tableau, Metabase)
- **Team size:** (e.g., 3 analysts, 2 analytics engineers)

## What We Customized
- Describe which skills, agents, or rules you modified and why
- Mention any custom skills you built
- Note any rules or hooks specific to your workflow

## Key Learnings
- What worked well
- What you would do differently
- Tips for others with a similar stack
```
