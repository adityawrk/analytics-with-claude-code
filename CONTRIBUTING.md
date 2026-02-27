# Contributing to Analytics with Claude Code

Thanks for your interest in contributing! This project aims to be the definitive resource for analytics practitioners using Claude Code. Every contribution makes it better for the whole community.

## Ways to Contribute

### Add a new skill
Skills are the highest-impact contribution. If you've built a Claude Code skill for an analytics task, others will benefit from it.

**To add a skill:**
1. Create `.claude/skills/your-skill-name/SKILL.md`
2. Use YAML frontmatter with `name` and `description`
3. Write comprehensive instructions (not toy examples)
4. Test it on real data before submitting
5. Update the skills table in `README.md`

**Skill quality bar:**
- Would a senior analyst actually use this daily?
- Does it handle edge cases (nulls, empty results, large datasets)?
- Does it produce structured, actionable output?
- Is the description clear enough for Claude to invoke it appropriately?

### Add a new agent
Agents handle multi-step workflows. Good agents have clear scope, appropriate model selection, and well-defined tool access.

**To add an agent:**
1. Create `.claude/agents/your-agent-name.md`
2. Use frontmatter with `name`, `description`, and `tools` (do NOT add a `model` field — agents inherit the model from the user's chat session)
3. Write detailed system prompt instructions
4. Document when to use it (and when NOT to)
5. Update the agents table in `README.md`

### Improve a guide
Guides should be practical and actionable. If something is unclear, missing examples, or outdated -- fix it.

### Add an example
Examples should be self-contained directories with their own README, sample data, and clear instructions for reproducing the analysis.

### Report issues
Found something broken, misleading, or missing? [Open an issue](../../issues).

---

## Development Setup

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/analytics-with-claude-code.git
cd analytics-with-claude-code

# That's it. This is a documentation/configuration repo.
# No build step, no dependencies to install.
```

To test skills and agents, copy them to an analytics project that has data:
```bash
cp -r .claude/ /path/to/your-analytics-project/.claude/
cd /path/to/your-analytics-project
claude
```

---

## Quality Standards

### Skills
- Frontmatter must include `name`, `description`, and `allowed-tools`
- Instructions should be specific enough to produce consistent results
- Include output format specification
- Handle edge cases explicitly
- No hardcoded paths, database names, or credentials

### Agents
- Frontmatter must include `name`, `description`, and `tools`
- Do NOT set `model` — agents inherit the model from the user's chat session
- Tool access should follow least-privilege (e.g., the reviewer agent has no Bash access)
- Include clear behavioral instructions

### Rules
- Use `globs` in frontmatter for file-specific rules
- Keep rules concise -- each line should prevent a specific mistake
- Include examples of correct and incorrect patterns

### Hooks
- Must be executable (`chmod +x`)
- Must handle errors gracefully (don't break the workflow)
- Include clear comments explaining the logic
- Read input from stdin as JSON, use jq for parsing

### Guides
- Write for analytics practitioners (assume SQL/Python knowledge, no Claude Code knowledge)
- Include copy-paste code examples
- Be actionable -- every section should teach something the reader can do immediately
- Keep a logical flow within numbered guides

---

## Git Workflow

1. Fork the repo
2. Create a feature branch: `git checkout -b add-funnel-analysis-skill`
3. Make your changes
4. Test your changes (copy to a real project, verify they work)
5. Commit with a clear message: `feat: add funnel analysis skill`
6. Push and open a PR

### Commit messages
Use conventional commits:
- `feat:` -- New skill, agent, guide, or example
- `fix:` -- Bug fix or correction
- `docs:` -- Documentation improvement
- `refactor:` -- Restructuring without changing behavior

---

## What We're Looking For

**High-priority contributions:**
- Skills: funnel analysis, cohort analysis, forecasting, data profiling, anomaly detection
- Agents: visualization specialist, documentation generator, migration planner
- MCP configs: dbt Cloud, Looker, Tableau, Databricks, Redshift
- Examples: real workflows with sample data
- Guides: advanced topics (CI/CD integration, custom MCP servers)

**We'll review PRs for:**
- Practical utility -- would a working analyst use this?
- Quality -- does it handle real-world messiness?
- Consistency -- does it follow the patterns established in existing content?
- Clarity -- could someone new to Claude Code follow it?

---

## Code of Conduct

Be respectful, constructive, and welcoming. We're all here to make analytics work better.

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
