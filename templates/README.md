# Templates

Supporting configurations for analytics projects. The main CLAUDE.md is at the [repository root](../CLAUDE.md).

## MCP Server Configs
Pre-built Model Context Protocol configurations for connecting Claude Code to your data warehouse:

| Config | Database | File |
|--------|----------|------|
| [PostgreSQL](mcp-postgres.json) | PostgreSQL, Amazon RDS, Aurora | `mcp-postgres.json` |
| [BigQuery](mcp-bigquery.json) | Google BigQuery | `mcp-bigquery.json` |
| [Snowflake](mcp-snowflake.json) | Snowflake | `mcp-snowflake.json` |
| [DuckDB](mcp-duckdb.json) | DuckDB | `mcp-duckdb.json` |
| [CSV / Parquet](mcp-csv.json) | CSV and Parquet files (via DuckDB) | `mcp-csv.json` |

```bash
# Copy to your project's .claude/ directory
cp templates/mcp-postgres.json /path/to/your-project/.claude/mcp.json
# Then set environment variables for your connection details
```

## Settings Template
**[settings.json.template](settings.json.template)** -- Permission rules and hook wiring for analytics teams. Allows dbt/sqlfluff commands, blocks destructive SQL, wires up validation hooks.

```bash
cp templates/settings.json.template /path/to/your-project/.claude/settings.json
```
