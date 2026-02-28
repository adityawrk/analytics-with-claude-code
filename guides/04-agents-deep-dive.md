# Creating Custom Agents for Analytics Workflows

## What Subagents Are

Subagents are isolated Claude instances that your main Claude Code session can spawn to handle specific tasks. Each agent gets its own context window, has defined tool access, and inherits the model from the parent session. When the agent finishes, it returns results to the parent session.

Think of it this way: you are the lead analyst. You delegate "go explore this table" to a focused agent with read-only tools and "write the final SQL" to an agent with write access. The orchestration happens automatically.

## When to Use Agents vs Skills

| Use a Skill when... | Use an Agent when... |
|---------------------|---------------------|
| You need instructions loaded into the current session | You need an isolated context for a subtask |
| The task is a single coherent workflow | The task benefits from parallel or sequential delegation |
| Context from the main session is needed throughout | The subtask should not pollute the main session's context |
| You want Claude Code to follow a specific playbook | You want to use a cheaper model for exploration |
| One-shot tasks: profiling, report generation | Multi-step workflows: explore then analyze then report |

A practical rule: if the task takes fewer than 5 back-and-forth steps, use a skill. If it requires independent exploration, use an agent.

## Agent Definition Anatomy

Agents live in `.claude/agents/` as markdown files with YAML frontmatter:

```markdown
---
name: "data-explorer"
description: "Explores datasets and surfaces key findings"
tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Data Explorer Agent

You are a data exploration specialist. Your job is to quickly scan a dataset
and report the most important findings.

## Approach
1. Check file size and format
2. Read the first 100 rows
3. Compute basic statistics
4. Identify the 3 most interesting patterns or anomalies
5. Return a concise summary (under 500 words)

## Output Format
Return a structured summary:
- **Shape**: rows x columns
- **Key columns**: list the most important columns and why
- **Findings**: top 3 discoveries
- **Recommended next steps**: what analysis should follow
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Identifier for the agent |
| `description` | Yes | What this agent does |
| `tools` | No | List of allowed tools (defaults to parent's tools) |

> **Note:** Agents inherit the model from the parent chat session. There is no `model` field in agent frontmatter. Model routing (using cheaper models for exploration vs. expensive models for reasoning) is handled at the orchestration level — the parent session decides which agent to spawn for which task.

## Cost-Effective Agent Design

Since agents inherit the parent session's model, cost optimization comes from **tool scoping** — give each agent only the tools it needs. Fewer tools means fewer costly tool-use cycles and tighter focus.

| Agent Purpose | Recommended Tools | Why |
|---------------|------------------|-----|
| Exploration | Read, Glob, Grep | Read-only — cannot accidentally modify anything |
| SQL writing | Read, Bash, Write, Grep, Glob | Needs Bash to test queries, Write to save models |
| Review/validation | Read, Grep, Glob | Static analysis only — no execution needed |
| Report generation | Read, Bash, Write, Grep, Glob | Needs Bash for queries, Write for output |

To run exploration tasks on a cheaper model, use the Task tool's `model` parameter at the orchestration level rather than in the agent definition.

## Isolation and Context Management

Each agent has its own context window. This is powerful:

- **No context pollution.** An exploration agent can read 50 files without filling up the main session's context.
- **Focused reasoning.** The agent only sees what is relevant to its task.
- **Parallel execution.** Multiple agents can work simultaneously on different subtasks.

However, agents do not share memory. If Agent A discovers something that Agent B needs, the parent session must relay it. Design your workflows accordingly.

## Walkthrough: Building a Data Explorer Agent

### Step 1: Create the Agent

Create `.claude/agents/data-explorer.md`:

```markdown
---
name: "data-explorer"
description: "Quick exploration of datasets - finds patterns, anomalies, and key statistics"
tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Data Explorer

You are a fast, thorough data explorer. Given a dataset (file or table),
produce a concise exploration report.

## Process

### 1. Orientation (30 seconds)
- Determine file type, size, encoding
- Count rows and columns
- Read the first 20 and last 10 rows

### 2. Structure Analysis
- Map column names, types, and descriptions (infer from names and values)
- Identify the primary key (or note if none exists)
- Identify date columns and determine the time range
- Identify potential foreign keys

### 3. Quality Check
- Null counts per column (flag > 5%)
- Duplicate row check
- Constant columns (remove candidates)

### 4. Pattern Discovery
- For numeric columns: distribution shape (normal, skewed, bimodal)
- For categorical columns: cardinality and top values
- For date columns: periodicity and gaps
- Cross-column: obvious correlations or dependencies

### 5. Report
Return a markdown report with:
- One-paragraph executive summary
- Statistics tables
- Top 3 findings with evidence
- Suggested next analysis steps

Keep the entire report under 600 words.
```

### Step 2: Use It

In a Claude Code session:

```
Explore the file customer_orders_2024.parquet using the data-explorer agent.
Then based on its findings, write a SQL query to investigate the most
interesting pattern it discovered.
```

Claude Code will:
1. Spawn the data-explorer agent with read-only tools.
2. The agent reads the file, runs Python commands, and produces a report.
3. The parent session receives the report.
4. The parent session writes the SQL query based on the findings.

## Walkthrough: Orchestrating Multiple Agents

For a complete analysis workflow, create several agents that work in sequence.

### Agent 1: Schema Scout

`.claude/agents/schema-scout.md`:

```markdown
---
name: "schema-scout"
description: "Maps database schemas and finds relevant tables"
tools:
  - Bash
  - Read
---

# Schema Scout

Given a question or topic, find the relevant tables in the database.

1. Query information_schema to list tables matching the topic
2. For each candidate table, get column names and sample rows
3. Identify which tables are needed to answer the question
4. Map out the join keys between tables
5. Return a concise schema map with table names, key columns, and join paths
```

### Agent 2: Query Builder

`.claude/agents/query-builder.md`:

```markdown
---
name: "query-builder"
description: "Writes optimized SQL queries from requirements and schema information"
tools:
  - Bash
  - Read
  - Write
---

# Query Builder

Given a question, a schema map, and query requirements:

1. Write the SQL query using CTEs
2. Follow the SQL conventions from CLAUDE.md
3. Include comments explaining each CTE
4. Test the query if a database connection is available
5. Optimize: check for missing indexes, unnecessary joins, or Cartesian products
6. Return the final query and its execution plan summary
```

### Agent 3: Insight Writer

`.claude/agents/insight-writer.md`:

```markdown
---
name: "insight-writer"
description: "Turns query results into clear business insights"
tools:
  - Read
  - Write
  - Bash
---

# Insight Writer

Given query results and business context:

1. Identify the key finding (one sentence)
2. Provide supporting evidence with specific numbers
3. Compare to benchmarks or prior periods if available
4. State the business implication
5. Recommend 1-3 specific actions
6. Format as a concise memo (under 300 words)

Write for a VP-level audience. No jargon. Lead with the insight, not the methodology.
```

### Orchestration Prompt

```
I need to understand why revenue dropped last week.

Use the schema-scout agent to find relevant revenue and order tables.
Then use the query-builder agent to write queries that break down revenue
by segment, channel, and product. Run the queries.
Finally, use the insight-writer agent to produce a memo explaining the findings.
```

This runs three agents in sequence, each scoped to exactly the tools it needs. The schema-scout only reads; the query-builder can write SQL files; the insight-writer produces the final memo.

## Agent Memory and Persistent Learning

Agents do not have persistent memory across invocations by default. Each time an agent is spawned, it starts fresh with only its definition and the task from the parent.

To create persistent learning:

1. **Have agents write findings to files.** The data-explorer agent can append to `exploration_log.md`. Future runs can read this file.

2. **Update CLAUDE.md with discoveries.** After an agent finds something important (e.g., "the orders table has a timezone issue"), add it to CLAUDE.md so all future sessions know.

3. **Build a knowledge base.** Create a `knowledge/` directory where agents save their findings as structured markdown files.

## Cost Management

Monitor costs with `/cost` during any session. Agent design is your primary cost lever — agents with fewer tools and tighter scope finish faster, using fewer tokens.

### Cost-Saving Patterns

1. **Scope tools tightly.** Give exploration agents only `Read`, `Glob`, and `Grep`. Fewer tools means fewer costly tool-use cycles.
2. **Set clear stopping criteria.** Agents without boundaries will keep exploring. Define "done" in the agent definition.
3. **Reuse findings.** Have agents write discoveries to files so subsequent agents (or sessions) do not repeat the exploration.
4. **Use the Task tool's `model` parameter** at the orchestration level when you want to run a subtask on a cheaper model (e.g., haiku for exploration).
