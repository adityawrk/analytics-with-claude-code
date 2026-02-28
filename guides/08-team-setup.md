# Setting Up Claude Code for Analytics Teams

## Shared Configuration via Git

Claude Code is designed for team use. The configuration files that define how Claude Code behaves in your project are committed to git, so every team member gets the same setup automatically.

### What to Commit

```
your-project/
  CLAUDE.md                      # Shared project knowledge
  .mcp.json                      # MCP server configuration (no secrets)
  .claude/
    settings.json                # Shared tool permissions and hook wiring
    rules/
      sql-conventions.md         # SQL style rules
      data-privacy.md            # Data privacy standards
      metric-definitions.md      # Metric definitions
    skills/
      eda/SKILL.md               # Exploratory data analysis skill
      ab-test/SKILL.md           # A/B test analysis skill
      weekly-report/SKILL.md     # Weekly report skill
    agents/
      analyst.md                 # Business question answering agent
      data-explorer.md           # Schema exploration agent
      sql-developer.md           # SQL writing agent
    hooks/
      validate-sql.sh            # SQL validation hook
      auto-format-sql.sh         # SQL formatting hook
      audit-log.sh               # Query audit logging hook
```

### What NOT to Commit

```
your-project/
  CLAUDE.local.md                # Personal overrides
  .claude/
    settings.local.json          # Personal MCP servers or permissions
  .env                           # Database credentials, API keys
```

Add to `.gitignore`:

```
CLAUDE.local.md
.claude/settings.local.json
.env
```

## Permission Modes for Different Environments

Claude Code permissions should match the environment. A developer running Claude Code locally needs more freedom than a CI pipeline generating reports.

### Development Environment

`.claude/settings.json` for local development:

```json
{
  "permissions": {
    "allow": [
      "Bash(python*)",
      "Bash(dbt *)",
      "Bash(sqlfluff*)",
      "Bash(git *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "mcp__analytics-db__query",
      "mcp__analytics-db__list_tables",
      "mcp__analytics-db__describe_table"
    ],
    "deny": [
      "Bash(rm -rf*)",
      "Bash(*DROP TABLE*)",
      "Bash(*DROP DATABASE*)",
      "Bash(*TRUNCATE*)",
      "mcp__analytics-db__execute_ddl"
    ]
  }
}
```

This allows Claude Code to read, write, run Python, run dbt, query the database, but blocks destructive operations.

### CI/CD Environment

For automated reporting or testing in CI:

```json
{
  "permissions": {
    "allow": [
      "Bash(python scripts/*)",
      "Bash(dbt run*)",
      "Bash(dbt test*)",
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Write",
      "Edit",
      "Bash(git push*)",
      "Bash(rm*)"
    ]
  }
}
```

Narrow scope: run specific scripts, run dbt, read files. No writing, no git pushes.

### Production Data Environment

When Claude Code has access to production data:

```json
{
  "permissions": {
    "allow": [
      "mcp__prod-db__query",
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Write",
      "Edit",
      "Bash",
      "mcp__prod-db__execute_ddl",
      "mcp__prod-db__create_table",
      "mcp__prod-db__drop_table"
    ]
  }
}
```

Read-only. No Bash, no file writes. Only query access to the database.

## Managed Settings for Organizations

For organizations using Claude Code at scale, managed settings provide centralized control. These are set by administrators and cannot be overridden by individual users.

Managed settings are configured through the Anthropic admin console and enforce organization-wide policies:

```json
{
  "managedPolicy": {
    "permissions": {
      "deny": [
        "Bash(*curl*secret*)",
        "Bash(*wget*)",
        "WebFetch"
      ]
    },
    "maxTokensPerSession": 500000,
    "allowedModels": ["claude-sonnet-4", "claude-haiku-4"]
  }
}
```

Use managed settings to:
- Block tools that could exfiltrate data
- Set cost limits via token caps
- Restrict which models teams can use
- Enforce security policies across all projects

## Onboarding New Team Members

### Step 1: Repository Setup

Create an onboarding section in your README (or a dedicated doc):

```markdown
## Setting Up Claude Code

1. Install Claude Code:
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```

2. Clone the analytics repo:
   ```bash
   git clone git@github.com:your-org/analytics.git
   cd analytics
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials (get from 1Password vault "Analytics")
   source .env
   ```

4. Start Claude Code:
   ```bash
   claude
   ```

5. Verify MCP connections:
   ```
   What MCP servers are connected? List all available database tools.
   ```

6. Run the verification prompt:
   ```
   Using our analytics database, query the fct_revenue table for yesterday's
   total revenue. Compare it to the same day last week.
   ```
```

### Step 2: First-Day Prompts

Give new team members a set of prompts that teach them the project while producing useful output:

```markdown
## First-Day Exploration Prompts

1. "Show me the project structure. Explain what each top-level directory
   contains and how the data flows from sources to marts."

2. "List all dbt models in the marts directory. For each, show the
   description and the primary key."

3. "Query the analytics database for yesterday's key metrics: revenue,
   active users, new signups. Format as a table."

4. "Profile the fct_orders table. Show column types, null rates, and
   the distribution of order_status."

5. "Show me the last 5 git commits and explain what changed."
```

### Step 3: Personal Configuration

Have each team member create their `CLAUDE.local.md`:

```markdown
# Personal Settings

## Preferences
- I prefer verbose explanations when I'm learning a new area
- My local Postgres is on port 5433 (not the default 5432)
- I work in the US/Pacific timezone

## Current Focus
- Working on the customer segmentation project
- Primary tables: dim_customers, fct_orders, fct_sessions
```

## Standardizing Metric Calculations

The most common source of analytics errors is inconsistent metric definitions. Claude Code solves this through CLAUDE.md and rules.

### Metric Definitions in CLAUDE.md

```markdown
## Canonical Metric Definitions

### Revenue
- **Gross Revenue**: SUM(amount) from fct_orders WHERE status != 'refunded'
- **Net Revenue**: Gross Revenue - SUM(refund_amount) from fct_refunds
- **MRR**: SUM(monthly_amount) from fct_subscriptions WHERE is_active = true
- ALWAYS use fct_revenue as source of truth. Do NOT calculate from raw tables.

### Users
- **Active User**: Triggered any event EXCEPT pageview and heartbeat in the period
- **DAU**: COUNT(DISTINCT user_id) of active users per day
- **MAU**: COUNT(DISTINCT user_id) of active users in a 28-day window (NOT calendar month)
- Note: MAU uses 28-day window, not calendar month. This is intentional.

### Conversion
- **Conversion Rate**: Converters / Total Users in Cohort
- A "converter" is defined in dim_conversion_events (different per funnel)
- NEVER calculate conversion without specifying the funnel and time window
```

### Metric Validation Rules

Create `.claude/rules/metric-validation.md`:

```markdown
# Metric Validation Rules

When calculating any metric defined in CLAUDE.md:

1. ALWAYS use the canonical source table specified in the definition
2. NEVER recalculate a metric from raw tables if a mart table exists
3. When the result differs from the dashboard by more than 1%, investigate before reporting
4. Always specify the time period and timezone (default: UTC)
5. When comparing periods, ensure equal-length windows (do not compare a 31-day month to a 28-day month without noting it)
```

This ensures that every analyst on the team, whether they have been here for 5 years or 5 days, calculates MRR the same way.

## Code Review Workflows

### Using Claude Code for PR Reviews

In a PR review workflow:

```bash
# In your analytics repo, on the PR branch
claude "Review the changes in this branch. Check for:
1. SQL correctness (joins, filters, aggregations)
2. Adherence to our SQL conventions from CLAUDE.md
3. dbt best practices (ref usage, test coverage, documentation)
4. Data quality risks (missing null handling, implicit type conversions)
5. Performance concerns (full table scans, expensive joins)
Give specific, actionable feedback with line references."
```

### Automated PR Checks

Add Claude Code to your CI pipeline for automated review:

```yaml
# .github/workflows/analytics-review.yml
name: Analytics PR Review
on:
  pull_request:
    paths:
      - 'models/**'
      - 'analyses/**'

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Review SQL changes
        run: |
          claude --print --allowedTools "Read,Glob,Grep" \
            "Review all changed SQL files in this PR. Check for:
            1. Correct use of ref() instead of hardcoded table names
            2. All models have tests for primary key uniqueness
            3. No SELECT * in mart models
            4. CTEs are used instead of subqueries
            Output a structured review with PASS/FAIL for each check."
```

## Cost Management

### Monitoring Usage

Use `/cost` in any session to see current token usage. For team-wide tracking:

1. **Set per-session limits** in managed settings to prevent runaway costs.
2. **Use haiku for exploration** -- it is 10-20x cheaper than opus for reading and scanning data.
3. **Use agents strategically** -- delegate cheap tasks to cheap models.

### Budget Guidelines

| Task Type | Recommended Model | Typical Cost |
|-----------|------------------|-------------|
| Data exploration | Haiku | $0.05-0.20 per session |
| SQL writing | Sonnet | $0.20-0.50 per session |
| Complex analysis | Sonnet | $0.30-1.00 per session |
| Report writing | Opus | $0.50-2.00 per session |
| Code review | Sonnet | $0.10-0.30 per PR |

### Cost Reduction Strategies

1. **Write better CLAUDE.md.** The more context Claude Code has upfront, the fewer clarifying questions and wrong turns. This saves tokens.
2. **Use skills.** A well-defined skill produces the right output on the first try. No iteration = fewer tokens.
3. **Use `/compact` aggressively.** When exploring data, context fills up fast. Compact early and often.
4. **Batch work.** Instead of 5 separate sessions for 5 queries, do them all in one session while context is loaded.

## Security Best Practices

### Data Classification

Define what Claude Code can and cannot access:

```markdown
## Data Access Policy (in CLAUDE.md)

### Accessible Data
- All tables in the `analytics` schema (aggregated, non-PII)
- All tables in the `staging` schema (cleaned, pseudonymized)

### Restricted Data
- NEVER query the `raw_pii` schema (contains email, phone, address)
- NEVER SELECT columns: email, phone_number, address, ssn, credit_card
- If analysis requires PII, write the query but DO NOT execute it. Flag for manual review.
```

### Hook-Based PII Protection

Create `.claude/hooks/pii-guard.sh`:

```bash
#!/bin/bash
# Uses the hookSpecificOutput JSON protocol for PreToolUse hooks.
set -euo pipefail

input=$(cat)

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

tool_name=$(echo "$input" | jq -r '.tool_name')
if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')
upper_command=$(echo "$command" | tr '[:lower:]' '[:upper:]')

# Block queries that select PII columns
pii_columns=("EMAIL" "PHONE_NUMBER" "ADDRESS" "SSN" "CREDIT_CARD" "DATE_OF_BIRTH")
for col in "${pii_columns[@]}"; do
  if echo "$upper_command" | grep -qE "SELECT.*$col|SELECT \*.*RAW_PII"; then
    deny "Query references PII column ($col) or PII schema. Submit a data access request."
  fi
done

# Block queries to restricted schemas
if echo "$upper_command" | grep -qE "FROM.*RAW_PII\.|JOIN.*RAW_PII\."; then
  deny "Query references the raw_pii schema."
fi

exit 0
```

### Audit Logging

For teams that need audit trails, log all Claude Code database queries:

```bash
#!/bin/bash
# .claude/hooks/audit-log.sh - PostToolUse hook for MCP database queries
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name')

# Only log database queries
if [[ "$tool_name" != mcp__*__query ]]; then
  exit 0
fi

query=$(echo "$input" | jq -r '.tool_input.query // .tool_input.sql // "unknown"')
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
user=$(whoami)

echo "$timestamp | $user | $tool_name | $query" >> .claude/audit.log

exit 0
```

### Network Controls

For sensitive environments, restrict Claude Code's network access:

```json
{
  "permissions": {
    "deny": [
      "WebFetch",
      "WebSearch",
      "Bash(*curl*)",
      "Bash(*wget*)",
      "Bash(*nc *)",
      "Bash(*ssh*)"
    ]
  }
}
```

This ensures Claude Code cannot send data to external services. Combine with read-only database users and PII guards for defense in depth.

## Putting It All Together

A fully configured analytics team setup looks like this:

1. **CLAUDE.md** with metric definitions, table references, and conventions.
2. **Rules** for SQL style, dbt patterns, and data quality standards.
3. **Skills** for profiling, reporting, and model building.
4. **Agents** with appropriate model selection for cost-effective exploration.
5. **Hooks** for SQL validation, PII protection, and formatting.
6. **MCP servers** for database access and tool integrations.
7. **Permissions** tuned per environment (dev, CI, prod).
8. **Onboarding docs** so new team members are productive on day one.

The result: every analyst on the team has the same institutional knowledge, the same guardrails, and the same powerful tools -- loaded automatically, every session.
