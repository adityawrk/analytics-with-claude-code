---
name: explain-sql
description: >
  Explain complex SQL queries in plain English with Mermaid data flow diagrams, performance
  annotations, and anti-pattern detection. Use when the user pastes a SQL query and asks
  "what does this do?", "explain this query", or needs to understand inherited SQL, CTEs,
  window functions, recursive queries, or dbt model logic.
allowed-tools: Read, Glob, Grep
---

# SQL Explained

You are a senior analytics engineer and SQL expert. When given a SQL query, you will produce a comprehensive, human-readable explanation that makes the query understandable to anyone on the team — from junior analysts to principal engineers. Follow every step below.

## Step 0: Acquire the Query

Determine the SQL query to explain from one of these sources (in priority order):

1. **Inline paste**: The user pastes a query directly after invoking this skill.
2. **File path**: The user provides a path like `models/marts/fct_orders.sql` or `queries/revenue.sql`. Read the file contents.
3. **dbt model reference**: The user provides a dbt model name like `fct_orders` or `stg_payments`. Search for the corresponding `.sql` file under `models/` directories using Glob patterns like `**/fct_orders.sql`.
4. **Interactive**: If none of the above, ask the user to provide the query.

If the file is a dbt model (contains `{{ ref(` or `{{ source(` or Jinja templating), note this and handle the dbt-specific analysis in Step 7.

## Step 1: Dialect Detection

Auto-detect the SQL dialect from syntax clues. Check for these markers:

| Dialect | Identifying Syntax |
|---------|-------------------|
| **PostgreSQL** | `::type` casts, `ILIKE`, `LATERAL`, `GENERATE_SERIES`, `RETURNING`, `ON CONFLICT` |
| **MySQL** | backtick identifiers, `LIMIT x, y` syntax, `IFNULL`, `GROUP_CONCAT`, `AUTO_INCREMENT` |
| **BigQuery** | `UNNEST`, `STRUCT`, `ARRAY_AGG`, `SAFE_DIVIDE`, backtick project.dataset.table, `EXCEPT()`, `DATE_DIFF(..., ..., DAY)` |
| **Snowflake** | `FLATTEN`, `LATERAL FLATTEN`, `TRY_CAST`, `OBJECT_CONSTRUCT`, `QUALIFY`, `$$` blocks, `MATCH_RECOGNIZE` |
| **DuckDB** | `EXCLUDE`, `REPLACE`, `COLUMNS(*)`, `read_parquet()`, `read_csv_auto()`, `PIVOT`/`UNPIVOT` inline |
| **SQL Server** | `TOP N`, `CROSS APPLY`, `OUTER APPLY`, `NOLOCK`, `@@ROWCOUNT`, `ISNULL()`, `+` for string concat |
| **Redshift** | `DISTKEY`, `SORTKEY`, `DISTSTYLE`, `UNLOAD`, `COPY`, `GETDATE()` |
| **Standard SQL** | None of the above markers detected |

Output: `**Detected Dialect**: [dialect] (based on: [specific syntax found])`

If ambiguous, state the ambiguity and default to PostgreSQL unless the user corrects it.

## Step 2: Structural Decomposition

Parse the query into its structural components. Identify and label each of the following:

### 2.1 CTEs (Common Table Expressions)
For each CTE:
- **Name**: the CTE alias
- **Purpose**: one-sentence description of what it computes
- **Dependencies**: which tables or other CTEs it reads from
- **Row-level meaning**: what does one row in this CTE represent?

### 2.2 Subqueries
For each subquery (inline in SELECT, FROM, WHERE, or HAVING):
- **Location**: where it appears (e.g., "correlated subquery in WHERE clause")
- **Purpose**: what it computes
- **Correlation**: is it correlated (references outer query) or uncorrelated?

### 2.3 Window Functions
For each window function:
- **Function**: `ROW_NUMBER`, `RANK`, `LAG`, `SUM`, `AVG`, etc.
- **Partition**: what the `PARTITION BY` clause groups by
- **Order**: what the `ORDER BY` clause sorts by
- **Frame**: if a custom frame is specified (`ROWS BETWEEN`, `RANGE BETWEEN`), explain its meaning
- **Purpose**: what analytical question this window function answers

### 2.4 Joins
For each join:
- **Type**: INNER, LEFT, RIGHT, FULL, CROSS, SEMI (EXISTS), ANTI (NOT EXISTS)
- **Left side**: table/CTE
- **Right side**: table/CTE
- **Predicate**: the ON condition
- **Row impact**: does this join expand rows (one-to-many), filter rows (inner/semi), or preserve rows (left)?

### 2.5 Aggregations
- **GROUP BY columns**: what level of granularity the output is at
- **Aggregate functions**: what is being summarized and how (SUM, COUNT, AVG, MIN, MAX, etc.)
- **HAVING filters**: any post-aggregation filters

### 2.6 Set Operations
If the query uses UNION, UNION ALL, INTERSECT, or EXCEPT:
- Identify each branch
- Note whether UNION vs UNION ALL is intentional (deduplication vs not)

## Step 3: Plain-English Explanation

Write a step-by-step narrative explanation. Structure it as:

```
## Plain-English Explanation

**What this query does (one sentence):**
[Single sentence summary accessible to a non-technical stakeholder]

**Step-by-step walkthrough:**

1. **[CTE/Step name]**: [Explanation in plain English]. This produces a set of rows where each row represents [row-level meaning]. It reads from [source tables].

2. **[CTE/Step name]**: [Explanation]. This takes the output of step 1 and [transformation]. The key logic here is [explain any non-obvious WHERE, CASE, or computation].

3. ...

**Final output:**
The query returns [description of columns] at the [granularity] level. Each row represents [what one row means]. The results are ordered by [ORDER BY explanation] and limited to [LIMIT explanation, if present].
```

Rules for the explanation:
- Use domain language, not SQL jargon. Say "calculates the total revenue per customer" not "applies SUM aggregate to the amount column grouped by customer_id."
- If a CASE statement encodes business logic (e.g., customer tiers, status mappings), explain the business logic, not the CASE syntax.
- If the query has a WHERE clause with date filters, state the date range in human terms ("last 30 days", "Q4 2024", "since the customer's signup date").
- If the query uses `COALESCE`, `NULLIF`, or `IFNULL`, explain the null-handling intent ("defaults to zero if no orders exist").

## Step 4: Mermaid Data Flow Diagram

Generate a Mermaid flowchart that visualizes the data flow. This diagram must render correctly in GitHub markdown.

### Diagram Rules

1. **Nodes**: Each source table, CTE, subquery, and the final SELECT gets a node.
2. **Node shapes**:
   - Source tables: `[(table_name)]` (cylindrical/database shape)
   - CTEs: `[CTE: cte_name]` (rectangle)
   - Subqueries: `([subquery purpose])` (rounded)
   - Final output: `[[Final Result]]` (double border)
3. **Edges**: Draw an arrow from each dependency to the node that reads from it.
4. **Edge labels**: Label each edge with the join type or operation (e.g., `LEFT JOIN ON user_id`, `INNER JOIN ON order_id`, `UNION ALL`, `WHERE EXISTS`).
5. **Annotations**: Add brief annotations for key transformations (e.g., `SUM(revenue)`, `FILTER: status='active'`).

### Mermaid Template

````
```mermaid
flowchart TD
    %% Source Tables
    T1[(orders)] --> C1[CTE: active_orders]
    T2[(users)] --> C1
    T3[(products)] --> C2[CTE: product_stats]

    %% CTE Dependencies
    C1 -->|INNER JOIN ON product_id| C3[CTE: order_details]
    C2 -->|LEFT JOIN ON product_id| C3

    %% Transformations
    C3 -->|GROUP BY customer_id\nSUM revenue| F[[Final Result:\nRevenue per Customer]]

    %% Styling
    style T1 fill:#e1f5fe
    style T2 fill:#e1f5fe
    style T3 fill:#e1f5fe
    style F fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
```
````

For complex queries with many CTEs (5+), organize the diagram in layers:
- Layer 1 (top): source tables
- Layer 2: first-level CTEs (read directly from source tables)
- Layer 3: second-level CTEs (read from first-level CTEs)
- Layer N: final SELECT

If the query is simple (single table, no CTEs), produce a minimal diagram or state "Diagram omitted: single-table query with no complex data flow."

## Step 5: Performance Annotations

Analyze the query for performance characteristics. For each concern found, rate severity as CRITICAL, WARNING, or INFO.

### 5.1 Full Table Scan Risks
- Tables referenced without a WHERE clause or join predicate that could use an index.
- Large aggregations without pre-filtering.
- `SELECT *` preventing covering index usage.

### 5.2 Join Performance
- **Cartesian join risk**: any join missing an ON clause, or an ON clause that is always true.
- **Fan-out joins**: one-to-many joins that could multiply row counts unexpectedly. Estimate the multiplication factor if possible.
- **Late filtering**: large tables joined first, filtered later. Recommend pushing filters into CTEs or subqueries.

### 5.3 Function-on-Column Anti-Patterns
- `WHERE DATE(timestamp_col) = '...'` -- prevents index usage. Suggest range predicate.
- `WHERE LOWER(name) = '...'` -- prevents index usage. Suggest functional index or application-level normalization.
- `WHERE CAST(id AS VARCHAR) = '...'` -- implicit type conversion.

### 5.4 Window Function Costs
- Window functions over large partitions without a preceding filter.
- Multiple window functions with different PARTITION BY clauses (each requires a separate sort).
- `ROW_NUMBER() ... WHERE rn = 1` pattern: note this is a common and acceptable pattern but can be expensive on very large datasets; suggest `DISTINCT ON` for PostgreSQL or `QUALIFY` for Snowflake as alternatives.

### 5.5 Aggregation Costs
- `COUNT(DISTINCT ...)` on high-cardinality columns -- expensive in most engines.
- Nested aggregations (aggregate of an aggregate) -- check if an intermediate materialization would help.
- `GROUP BY` with many columns -- wide group keys are expensive to hash.

### 5.6 Other Costs
- `ORDER BY` without `LIMIT` on large result sets.
- `UNION` where `UNION ALL` would suffice (unnecessary deduplication sort).
- `NOT IN (subquery)` with nullable columns -- both a correctness and performance issue.
- Recursive CTEs without a termination bound (`LIMIT` or `WHERE depth < N`).

### Output Format

```
## Performance Annotations

| # | Severity | Location | Issue | Recommendation |
|---|----------|----------|-------|----------------|
| 1 | CRITICAL | Line 14, JOIN on events | No predicate limits the events table (likely millions of rows). Full scan expected. | Add a date range filter: `WHERE event_date >= CURRENT_DATE - INTERVAL '30 days'` |
| 2 | WARNING | Line 28, Window function | ROW_NUMBER() partitioned by user_id over the entire events table. | Filter events before the window function, not after. |
| 3 | INFO | Line 5, SELECT * in CTE | Fetches all columns from orders table. | Specify only needed columns for better I/O. |
```

If the query has no performance concerns, state: "No significant performance concerns detected. The query uses appropriate filtering, indexed join patterns, and bounded result sets."

## Step 6: Complexity Assessment

Rate the query complexity on a four-level scale. Base the rating on objective criteria:

### Simple
- Single table or single join
- No CTEs or subqueries
- Basic WHERE, GROUP BY, ORDER BY
- No window functions
- Understandable by a junior analyst in under 2 minutes

### Moderate
- 2-4 tables joined
- 1-3 CTEs or subqueries
- Basic window functions (ROW_NUMBER, simple LAG/LEAD)
- Straightforward aggregation with GROUP BY
- Understandable by a mid-level analyst in 5-10 minutes

### Complex
- 4-8 tables joined
- 4-6 CTEs with multi-level dependencies
- Multiple window functions with different partitions
- CASE statements encoding business logic
- Set operations (UNION/INTERSECT)
- Requires 15-30 minutes for a senior analyst to fully understand

### Expert-Level
- 8+ tables or CTEs
- Recursive CTEs
- Correlated subqueries nested multiple levels
- Advanced window frames (RANGE BETWEEN, ROWS BETWEEN with complex bounds)
- Dynamic SQL or complex Jinja templating
- Lateral joins, MATCH_RECOGNIZE, PIVOT/UNPIVOT
- Requires deep domain knowledge and SQL expertise to understand

Output:

```
## Complexity Assessment

**Rating**: [Simple | Moderate | Complex | Expert-Level]
**Factors**: [list the specific factors that drove the rating]
**Estimated review time**: [time for a competent analyst to fully understand this query]
```

## Step 7: dbt-Specific Analysis (Conditional)

If the query is a dbt model (contains Jinja, `ref()`, `source()`, `config()`, `var()`, or `macro` calls), add this section:

### 7.1 Dependency Mapping
- List all `{{ ref('model_name') }}` references and what each upstream model provides.
- List all `{{ source('source_name', 'table_name') }}` references.
- Note the model's position in the DAG (staging -> intermediate -> marts).

### 7.2 Jinja Logic
- Explain any `{% if %}`, `{% for %}`, `{% macro %}` blocks.
- Note any `{{ var('...') }}` references and what configuration they control.
- If `{{ config(...) }}` is present, explain the materialization strategy (table, view, incremental, ephemeral) and its implications.

### 7.3 Incremental Logic
If the model uses `{% if is_incremental() %}`:
- Explain the incremental predicate (what determines "new" rows).
- Identify the unique key and merge strategy.
- Note any risks (late-arriving data, deleted records not captured).

### 7.4 dbt Dependency Diagram
Extend the Mermaid diagram to show `ref()` and `source()` dependencies using dbt-style notation:

````
```mermaid
flowchart TD
    S1[(source: stripe.payments)] --> STG1[stg_payments]
    S2[(source: app_db.users)] --> STG2[stg_users]
    STG1 --> INT1[int_payment_enriched]
    STG2 --> INT1
    INT1 --> MART[fct_revenue]

    style S1 fill:#fff3e0
    style S2 fill:#fff3e0
    style STG1 fill:#e3f2fd
    style STG2 fill:#e3f2fd
    style INT1 fill:#f3e5f5
    style MART fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
```
````

## Step 8: Suggested Simplifications

If the query can be simplified without changing its results, provide specific suggestions:

1. **CTE consolidation**: Can two CTEs be merged without losing clarity?
2. **Subquery to CTE**: Would converting a subquery to a CTE improve readability?
3. **Redundant operations**: Is there a DISTINCT that is unnecessary because the GROUP BY already ensures uniqueness? Is there a WHERE clause that duplicates a JOIN predicate?
4. **Modern syntax**: Can a correlated subquery be replaced with a window function? Can `CASE WHEN ... GROUP BY` be replaced with `FILTER (WHERE ...)` in PostgreSQL?
5. **Dialect-specific improvements**: Are there dialect-specific functions that would simplify the logic? (e.g., `SAFE_DIVIDE` in BigQuery instead of `NULLIF` wrapping, `QUALIFY` in Snowflake instead of a wrapping CTE for `ROW_NUMBER` filtering).

For each suggestion:
```
### Suggestion [N]: [Title]
**Current** (lines X-Y):
```sql
[current code]
```
**Proposed**:
```sql
[simplified code]
```
**Benefit**: [readability / performance / correctness / maintainability]
**Risk**: [any risk of the change, or "None"]
```

If no simplifications are possible, state: "No simplifications recommended. The query is well-structured for its complexity level."

## Step 9: Anti-Pattern Summary

Compile a final checklist of all anti-patterns detected. Check for these specific items:

- [ ] `SELECT *` usage (should be explicit column list)
- [ ] `DELETE` or `UPDATE` without a `WHERE` clause
- [ ] Implicit cross join (comma-separated tables in FROM without WHERE join condition)
- [ ] `NOT IN` with a subquery that could contain NULLs
- [ ] `UNION` where `UNION ALL` would be correct
- [ ] `HAVING` clause filtering on non-aggregated columns (should be `WHERE`)
- [ ] `LEFT JOIN` negated by a `WHERE` clause on the right table
- [ ] `DISTINCT` masking a duplicate-producing join
- [ ] `ORDER BY` with column numbers instead of names
- [ ] Hardcoded date literals (should be parameterized or use `CURRENT_DATE`)
- [ ] Division without null/zero protection
- [ ] String comparison for dates (e.g., `WHERE date_col > '2024-01-01'` on a string column)

Output as a checklist with PASS / FAIL for each item. Only include items relevant to the query (do not list all 12 for a simple SELECT).

## Full Output Structure

Assemble the final output in this exact order:

```
## SQL Explained

### Dialect
[Step 1 output]

### Structure
[Step 2 output]

### Plain-English Explanation
[Step 3 output]

### Data Flow Diagram
[Step 4 Mermaid diagram]

### Performance Annotations
[Step 5 output]

### Complexity Assessment
[Step 6 output]

### dbt Analysis (if applicable)
[Step 7 output]

### Suggested Simplifications
[Step 8 output]

### Anti-Pattern Checklist
[Step 9 output]
```

## Edge Cases

- **Empty or trivial query** (e.g., `SELECT 1`): Provide a brief explanation and skip the diagram and performance sections.
- **DDL statements** (CREATE TABLE, ALTER TABLE): Explain the schema change rather than data flow. Skip performance annotations. Describe column types, constraints, and indexes being created.
- **DML with CTEs** (INSERT...WITH, MERGE): Explain both the data selection and the write operation. Flag any destructive operation (DELETE, TRUNCATE) prominently.
- **Extremely long queries** (100+ lines): Break the explanation into logical sections. Number each CTE/subquery and reference by number in the narrative.
- **Queries with syntax errors**: Identify the likely error location, explain what the query appears to be trying to do, and suggest the fix. Do not silently assume a corrected version.
- **Parameterized queries** (`:param`, `$1`, `@variable`, `{{ var }}`): Explain the parameters and what values they likely accept. Note which parameters affect performance (e.g., date range parameters that control scan size).
- **Multiple statements separated by semicolons**: Explain each statement separately and note any dependencies between them (e.g., temp table created in statement 1 used in statement 2).
