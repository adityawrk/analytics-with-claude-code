# Setting Up Claude Code for Analytics

## What Claude Code Is

Claude Code is Anthropic's agentic command-line tool. It runs in your terminal, reads and writes files, executes commands, and iterates on work autonomously. For analytics practitioners, this means you can describe an analysis in plain English and Claude Code will write the SQL, run the queries, build the charts, and iterate until the output is correct.

Unlike chat-based AI tools, Claude Code operates directly in your project directory. It sees your dbt models, your Python scripts, your CSV files, and your git history. It does not copy snippets into a web browser -- it works where you work.

## Why Analytics Practitioners Should Care

If you spend your days writing SQL, building dbt models, or wrangling data in Python, Claude Code changes the economics of your work:

- **Exploration is faster.** Describe a question and Claude Code writes the query, runs it, and interprets the results.
- **Boilerplate disappears.** Staging models, test YAML, documentation blocks -- generated in seconds.
- **Context stays loaded.** Claude Code reads your CLAUDE.md file on every session, so it knows your schema, your naming conventions, and your metric definitions.
- **Iteration is natural.** Say "that's wrong, filter to active users only" and it fixes the query.

## Installation

### Via Homebrew (macOS)

```bash
brew install claude-code
```

### Via npm (any platform)

```bash
npm install -g @anthropic-ai/claude-code
```

Verify the installation:

```bash
claude --version
```

You will need an Anthropic API key or a Claude subscription. On first launch, Claude Code walks you through authentication.

## First Session Walkthrough

Open your terminal, navigate to a directory containing a CSV file, and launch Claude Code:

```bash
cd ~/projects/sales-data
claude
```

You are now in an interactive session. Type a prompt:

```
Profile the file sales_2024.csv. Show me row count, column types,
null percentages, and the distribution of the top 5 categorical columns.
```

Claude Code will:

1. Read the CSV using Python (pandas).
2. Print summary statistics.
3. Show value counts for categorical columns.
4. Ask if you want to dig deeper.

That is the agentic loop in action. Claude Code plans, executes, observes, and iterates.

## Key Concepts

### The Agentic Loop

Claude Code does not produce a single response. It works in a loop:

1. **Plan** -- decide what to do next.
2. **Act** -- call a tool (read a file, run a command, write code).
3. **Observe** -- examine the tool's output.
4. **Repeat** -- continue until the task is complete.

You can interrupt at any step. Press `Escape` to stop tool execution.

### Tools

Tools are the actions Claude Code can take. The built-in tools include:

| Tool | What It Does |
|------|-------------|
| `Read` | Read a file from disk |
| `Write` | Create or overwrite a file |
| `Edit` | Make targeted edits to existing files |
| `Bash` | Run a shell command |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `WebFetch` | Fetch a URL |
| `WebSearch` | Search the web |

MCP servers can add more tools -- like querying a database directly. See Guide 06.

### The Context Window

Claude Code has a finite context window (the amount of text it can hold in working memory). When context fills up, older messages are summarized automatically. For analytics work this means:

- Do not paste entire 10,000-row CSVs into the prompt. Let Claude Code read the file itself.
- Break large analyses into focused sessions.
- Use `/cost` to monitor token usage.

## Essential Commands

These slash commands work inside any Claude Code session:

| Command | Purpose |
|---------|---------|
| `/help` | Show all available commands |
| `/cost` | Display tokens used and estimated cost for this session |
| `/memory` | View or edit the CLAUDE.md memory file |
| `/model` | Switch the model mid-session (e.g., to haiku for exploration) |
| `/clear` | Clear the conversation history to free context |
| `/compact` | Summarize the conversation to free context while retaining key info |
| `/quit` | Exit the session |

## Your First CLAUDE.md File

Create a file called `CLAUDE.md` in the root of your analytics project:

```markdown
# Project: Sales Analytics

## Data Sources
- `raw.stripe.payments` -- Stripe payment events, updated hourly
- `raw.hubspot.deals` -- CRM deal data, updated daily at 06:00 UTC
- `analytics.core.fct_revenue` -- Canonical revenue fact table

## SQL Conventions
- Use CTEs, never subqueries
- Always alias tables (e.g., `payments AS p`)
- Date columns use `_at` suffix for timestamps, `_date` for dates
- Use `snake_case` for all identifiers

## Key Metrics
- **MRR**: Sum of active subscription amounts at month-end
- **Churn Rate**: Lost MRR / Beginning MRR for the period
- **ARPU**: MRR / Active Subscriptions

## Common Commands
- Run dbt: `dbt run --select +model_name`
- Run tests: `dbt test --select model_name`
- Profile data: `python scripts/profile.py --table <table_name>`
```

Every time you start a Claude Code session in this directory, this context is loaded automatically. Claude Code knows your schemas, your conventions, and your definitions.

## Permission Modes

When Claude Code wants to run a command or write a file, it asks for your permission. You choose a mode at the start of each session:

| Mode | Behavior | Best For |
|------|----------|----------|
| **Ask every time** | Prompts before each tool use | Learning, production data |
| **Auto-accept reads** | Auto-approves file reads, asks for writes/commands | Day-to-day analysis |
| **YOLO mode** | Auto-approves everything | Trusted environments, rapid iteration |

Start with "ask every time" while you are learning. Once you trust the setup and have hooks guarding dangerous operations (see Guide 05), move to auto-accept reads.

## Non-Interactive Mode

You can use Claude Code without entering an interactive session. This is useful for one-off tasks:

```bash
# Single prompt, no session
claude "How many rows are in data.csv?"

# Pipe input
cat query.sql | claude "Optimize this SQL query for BigQuery"

# Print mode for scripts and CI
claude --print "Generate a data dictionary for all CSV files in this directory"
```

The `--print` flag outputs the result to stdout and exits, making it composable with other command-line tools.

## 5-Minute Quick Win: Dataset Profiling

Put any CSV in a directory and run:

```bash
claude "Profile the file data.csv. For each column show: data type, null count,
null percentage, unique count, and min/max/mean for numeric columns. Then
show the 5 most and least frequent values for every categorical column with
fewer than 50 unique values. Save the profile as profile_report.md."
```

This single command:
- Reads the file
- Writes and executes a Python profiling script
- Generates a markdown report
- Saves it to disk

You now have a reusable profiling workflow. To make it even faster, turn it into a skill (see Guide 03).

## Common Pitfalls for New Users

**Pitfall 1: Prompts that are too vague.**
Bad: "Analyze my data." Good: "Show me the top 10 customers by revenue in Q4 2024, broken down by acquisition channel."

**Pitfall 2: Pasting large datasets into the prompt.**
Do not copy-paste a CSV into the chat. Instead, tell Claude Code the file path and let it read the file with its tools. This is faster and uses fewer tokens.

**Pitfall 3: Not using CLAUDE.md.**
Without CLAUDE.md, Claude Code does not know your project conventions. It will guess -- and guess wrong. Spend 10 minutes writing a CLAUDE.md before your second session.

**Pitfall 4: Running too long without compacting.**
Long exploration sessions fill the context window. When Claude Code starts "forgetting" earlier findings, run `/compact` to summarize and free space.

**Pitfall 5: Not reviewing generated SQL before execution.**
Claude Code writes good SQL, but not perfect SQL. Always review queries that touch production data before approving execution.

## Useful Prompt Patterns for Analytics

These patterns work well for getting started:

```
# Exploration
"Show me the schema of the orders table and 10 sample rows"

# Aggregation
"What is the total revenue by month for the last 12 months? Show as a table."

# Comparison
"Compare this week's signups to last week, broken down by channel"

# Investigation
"Why are there nulls in the revenue column? Show me the rows and find the pattern."

# Visualization
"Create a line chart of daily active users for the past 90 days. Save as dau_trend.png."

# Transformation
"Write a dbt staging model for the raw_stripe.charges table following our naming conventions"
```

## What to Do Next

1. **Read Guide 02** to write a proper CLAUDE.md for your project.
2. **Read Guide 03** to build reusable skills for tasks you repeat.
3. **Read Guide 06** to connect Claude Code directly to your database.

The most important thing: start using Claude Code on real work today. Open a session, point it at a real dataset, and ask a real question.
