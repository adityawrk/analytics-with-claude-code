# Templates

Starter configurations you can copy into your analytics projects.

## CLAUDE.md Template
**[CLAUDE.md.template](CLAUDE.md.template)** -- A comprehensive CLAUDE.md starter for analytics projects. Customize with your data sources, metrics, and conventions.

```bash
cp templates/CLAUDE.md.template /path/to/your-project/CLAUDE.md
```

## MCP Server Configs
Pre-built Model Context Protocol configurations for connecting Claude Code to your data warehouse:

| Config | Database | File |
|--------|----------|------|
| [PostgreSQL](mcp-postgres.json) | PostgreSQL, Amazon RDS, Aurora | `mcp-postgres.json` |
| [BigQuery](mcp-bigquery.json) | Google BigQuery | `mcp-bigquery.json` |
| [Snowflake](mcp-snowflake.json) | Snowflake | `mcp-snowflake.json` |

```bash
# Copy to your project root as .mcp.json
cp templates/mcp-postgres.json /path/to/your-project/.mcp.json
# Then set environment variables for your connection details
```

## Settings Template
**[settings.json.template](settings.json.template)** -- Permission rules and hook wiring for analytics teams. Allows dbt/sqlfluff commands, blocks destructive SQL, wires up validation hooks.

```bash
cp templates/settings.json.template /path/to/your-project/.claude/settings.json
```
