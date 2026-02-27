# Connecting Claude Code to Your Data Stack

## What MCP Is

Model Context Protocol (MCP) is an open standard that lets Claude Code connect to external tools and data sources. An MCP server exposes "tools" -- functions that Claude Code can call, like `query` for running SQL or `list_tables` for exploring schemas.

With MCP, Claude Code does not just read files on disk. It can query your database directly, trigger dbt runs, post to Slack, and interact with your entire analytics stack.

## Architecture

```
Claude Code  <-->  MCP Client  <-->  MCP Server  <-->  Your Database
                                                        Your API
                                                        Your Tool
```

Each MCP server is a lightweight process that speaks the MCP protocol. Claude Code manages the servers, starting and stopping them as needed. You configure which servers to use in `.mcp.json` or `.claude/settings.json`.

## Setting Up Database Connections

### PostgreSQL

Install the Postgres MCP server:

```bash
npm install -g @anthropic-ai/mcp-server-postgres
```

Create `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "analytics-db": {
      "command": "mcp-server-postgres",
      "args": [],
      "env": {
        "POSTGRES_HOST": "localhost",
        "POSTGRES_PORT": "5432",
        "POSTGRES_DB": "analytics",
        "POSTGRES_USER": "analyst",
        "POSTGRES_PASSWORD": "${ANALYTICS_DB_PASSWORD}"
      }
    }
  }
}
```

The `${ANALYTICS_DB_PASSWORD}` syntax references an environment variable. Set it in your shell:

```bash
export ANALYTICS_DB_PASSWORD="your_password_here"
```

Now in Claude Code:

```
List the tables in the public schema, then show me the top 10 customers by revenue.
```

Claude Code will use the MCP tools `list_tables` and `query` to answer directly from your database.

### BigQuery

Use the BigQuery MCP server:

```json
{
  "mcpServers": {
    "bigquery": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-bigquery"],
      "env": {
        "BIGQUERY_PROJECT": "your-project-id",
        "BIGQUERY_DATASET": "analytics",
        "GOOGLE_APPLICATION_CREDENTIALS": "${HOME}/.config/gcloud/application_default_credentials.json"
      }
    }
  }
}
```

Authenticate with gcloud first:

```bash
gcloud auth application-default login
```

### Snowflake

```json
{
  "mcpServers": {
    "snowflake": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-snowflake"],
      "env": {
        "SNOWFLAKE_ACCOUNT": "your_account.us-east-1",
        "SNOWFLAKE_USER": "ANALYST",
        "SNOWFLAKE_PASSWORD": "${SNOWFLAKE_PASSWORD}",
        "SNOWFLAKE_WAREHOUSE": "ANALYTICS_WH",
        "SNOWFLAKE_DATABASE": "ANALYTICS",
        "SNOWFLAKE_SCHEMA": "MARTS"
      }
    }
  }
}
```

## Setting Up Tool Integrations

### GitHub

The GitHub MCP server lets Claude Code interact with issues, PRs, and repos:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

Analytics use cases:
- "Create an issue for the data quality problem we found"
- "Open a PR with the new dbt model"
- "Check if there are any open issues about revenue data"

### Slack

Connect Claude Code to Slack for sharing results:

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
        "SLACK_TEAM_ID": "T01234567"
      }
    }
  }
}
```

Analytics use cases:
- "Post the weekly KPI summary to #analytics-updates"
- "Check the #data-alerts channel for recent issues"

### dbt Cloud

Trigger dbt Cloud jobs and check run status:

```json
{
  "mcpServers": {
    "dbt-cloud": {
      "command": "npx",
      "args": ["-y", "mcp-server-dbt-cloud"],
      "env": {
        "DBT_CLOUD_API_TOKEN": "${DBT_CLOUD_TOKEN}",
        "DBT_CLOUD_ACCOUNT_ID": "12345"
      }
    }
  }
}
```

Analytics use cases:
- "Trigger a dbt run for the revenue models"
- "Check the status of the last dbt Cloud job"
- "Show me the latest dbt test failures"

## The .mcp.json File

The `.mcp.json` file lives in your project root and is designed to be shared with your team via git. Here is a complete example:

```json
{
  "mcpServers": {
    "analytics-db": {
      "command": "mcp-server-postgres",
      "args": [],
      "env": {
        "POSTGRES_HOST": "localhost",
        "POSTGRES_PORT": "5432",
        "POSTGRES_DB": "analytics",
        "POSTGRES_USER": "${DB_USER}",
        "POSTGRES_PASSWORD": "${DB_PASSWORD}"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/shared/data"],
      "env": {}
    }
  }
}
```

Each team member sets their own environment variables. The configuration is the same; the credentials differ.

## Security

### Environment Variables

Never hardcode credentials in `.mcp.json`. Always use `${VARIABLE_NAME}` references:

```json
"env": {
  "POSTGRES_PASSWORD": "${DB_PASSWORD}"
}
```

Set variables in your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export DB_PASSWORD="your_password"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
```

Or use a secrets manager and source from a `.env` file (gitignored):

```bash
# .env (DO NOT COMMIT)
DB_PASSWORD=your_password
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

```bash
# In your shell profile
source ~/projects/analytics/.env
```

### Allowlists and Denylists

Control which MCP tools Claude Code can use in `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__analytics-db__query",
      "mcp__analytics-db__list_tables",
      "mcp__analytics-db__describe_table"
    ],
    "deny": [
      "mcp__analytics-db__execute_ddl",
      "mcp__analytics-db__create_table",
      "mcp__analytics-db__drop_table"
    ]
  }
}
```

This lets Claude Code query your database but prevents it from modifying schemas. For analytics teams, this is the right default: read access yes, write access no.

### Read-Only Database Users

Create a read-only database user for Claude Code:

```sql
-- PostgreSQL
CREATE ROLE claude_reader LOGIN PASSWORD 'secure_password';
GRANT USAGE ON SCHEMA public TO claude_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO claude_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO claude_reader;
```

```sql
-- Snowflake
CREATE ROLE CLAUDE_READER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE CLAUDE_READER;
GRANT USAGE ON DATABASE ANALYTICS TO ROLE CLAUDE_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE ANALYTICS TO ROLE CLAUDE_READER;
GRANT SELECT ON ALL TABLES IN DATABASE ANALYTICS TO ROLE CLAUDE_READER;
```

Use this role in your MCP configuration. Even if Claude Code attempts to write, the database will reject it.

## Practical Workflow: Querying Your Database

Once MCP is configured, the workflow is natural:

```
You: What were our top 10 customers by revenue last month?

Claude Code: I'll query the analytics database to find this.
[Uses mcp__analytics-db__query tool]

Results:
| Customer | Revenue |
|----------|---------|
| Acme Corp | $45,230 |
| Beta Inc | $38,100 |
...

The top customer, Acme Corp, generated $45,230 in revenue last month,
representing 12% of total revenue. This is a 15% increase from the
prior month...
```

No Python scripts, no export/import, no context switching. Claude Code goes from question to answer in one step.

### Composing Queries with File Context

The real power emerges when Claude Code combines database access with file knowledge:

```
You: Using the metric definitions in CLAUDE.md, calculate our Net Revenue
Retention for Q4 2024. Query the database for the raw numbers.
```

Claude Code reads the NRR definition from CLAUDE.md, writes the correct SQL using your warehouse's syntax, runs it via MCP, and interprets the results.

## Tool Search

When you have many MCP servers configured, Claude Code can search across all available tools:

```
You: I need to check data freshness. What tools do I have for that?
```

Claude Code will list relevant tools from all configured MCP servers. This is useful when you have 5+ integrations and cannot remember every available tool.

## Common Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "MCP server failed to start" | Missing dependency | Run the MCP server command manually to see the error |
| "Tool not found" | Server not configured or crashed | Check `.mcp.json` syntax; restart Claude Code |
| "Permission denied" | Database user lacks access | Check GRANT statements for the read-only user |
| "Connection refused" | Database not running or wrong host | Verify host/port; test with `psql` or `bq` directly |
| "Environment variable not set" | Missing `$VAR` | Check `echo $VAR` in your terminal |
| Slow queries | No warehouse/compute assigned | Check Snowflake warehouse is running; check BigQuery quota |

### Debugging MCP Connections

Start the MCP server manually to see its output:

```bash
# For Postgres
POSTGRES_HOST=localhost POSTGRES_PORT=5432 POSTGRES_DB=analytics \
  POSTGRES_USER=analyst POSTGRES_PASSWORD=password \
  mcp-server-postgres
```

If it starts successfully, the issue is in the Claude Code configuration. If it fails, the error message will tell you what is wrong.

### Checking MCP Status in a Session

In a Claude Code session, you can ask:

```
What MCP servers are currently connected? List all available MCP tools.
```

Claude Code will show you which servers are running and what tools they provide.
