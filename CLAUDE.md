# Analytics with Claude Code -- Contributor Guide

Open-source repo. The product is `templates/CLAUDE.md.template` and everything in `.claude/`. MIT licensed.

## What Matters

The CLAUDE.md template is the product. Everything else supports it. When adding or changing anything, ask: "Does this make the CLAUDE.md experience better for someone who just dropped it into their project?"

## Architecture

- `.claude/skills/` -- Slash-command skills. YAML frontmatter: `name`, `description`.
- `.claude/agents/` -- Subagents. YAML frontmatter: `name`, `description`, `model`, `tools`.
- `.claude/rules/` -- Auto-applied rules. YAML frontmatter: `description`, `globs`.
- `.claude/hooks/` -- Bash scripts reading JSON from stdin. Exit code 2 blocks.
- `templates/` -- The gold-standard CLAUDE.md and configs users copy.
- `demo/` -- DuckDB batteries-included demo. Zero external deps.
- `challenges/` -- Progressive analytics challenges.
- `guides/` -- Reference docs (numbered 01-08).

## Quality Bar

- Skills MUST handle nulls, empty datasets, division by zero.
- Agents MUST specify when to use AND when NOT to use them.
- SQL uses CTEs, trailing commas, snake_case, inclusive-start/exclusive-end dates.
- NEVER fabricate data, testimonials, or results in examples.
- NEVER hardcode paths, credentials, or database names.

## The Philosophy

Users should NEVER have to write CLAUDE.md by hand. They copy the template, paste their top 5 queries, and Claude learns everything from the queries. The CLAUDE.md instructs Claude to auto-delegate to agents for execution, auto-review with the analytics-reviewer, and never hallucinate. Keep this philosophy in every change.

## Self-Learning

When you discover a mistake or pattern while working on this repo:
1. Abstract it into a one-line directive (ALWAYS/NEVER + why)
2. Add it below. Max 20 entries.

## Learnings

<!-- Claude populates this as it works. -->
