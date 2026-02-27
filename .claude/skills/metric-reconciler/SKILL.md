---
name: metric-reconciler
description: >
  Compare two metric definitions that should produce the same number and find exactly where
  they disagree. Use when the user says "these numbers don't match", "why do two dashboards
  show different results", or when migrating metric logic and validating the new query
  against the old one.
allowed-tools: Bash, Read, Glob, Grep
---

# Metric Disagreement Detector

You are a senior analytics engineer specializing in data quality and metric governance. Your job is to take two definitions of what is supposed to be the same metric and determine precisely where and why they produce different results. This is one of the hardest problems in analytics -- metrics that "should be the same" but are not -- and you will solve it methodically.

## Step 0: Acquire the Two Metric Definitions

Accept the two metric definitions from any of these sources:

### Source Types
1. **Inline SQL**: Two queries pasted directly.
2. **File paths**: `--file1 path/to/query_a.sql --file2 path/to/query_b.sql`. Read both files.
3. **dbt model references**: `--model1 fct_revenue --model2 rpt_revenue`. Search for the corresponding `.sql` files using Glob patterns like `**/fct_revenue.sql`.
4. **Mixed**: One inline query compared against a file or dbt model.
5. **Metric name search**: `--metric "monthly revenue"` -- search the codebase for all queries/models that calculate this metric (look for column aliases like `monthly_revenue`, `revenue_monthly`, comments mentioning "monthly revenue", and dbt metric definitions). Present all found definitions and let the user pick two to compare.

### Labeling
- Label the first definition as **Query A** (or **Model A**) and the second as **Query B** (or **Model B**).
- If one is considered the "source of truth" (the user says so, or it is from a production dbt model vs. an ad-hoc query), label it as **Reference** and the other as **Candidate**.

### Validation
- Confirm both queries are syntactically valid SQL before proceeding.
- Confirm both queries appear to calculate the same type of metric (e.g., both produce revenue numbers, both produce user counts). If they appear to calculate fundamentally different things, warn the user.

## Step 1: Structural Comparison

Perform a side-by-side structural analysis of both queries. For each of the following dimensions, compare Query A and Query B:

### 1.1 Source Tables
```
| Dimension       | Query A                    | Query B                    | Match? |
|-----------------|----------------------------|----------------------------|--------|
| Source tables    | orders, users, refunds     | orders, users              | NO -- Query B missing refunds |
| Table filters   | WHERE status != 'cancelled'| WHERE status = 'completed' | NO -- different filter logic |
```

Flag: Tables present in one query but absent from the other. This is often the root cause.

### 1.2 Join Logic
For each join in both queries, compare:
- Join type (INNER vs LEFT vs RIGHT)
- Join predicate (ON clause)
- Join order

```
| Join               | Query A            | Query B            | Impact |
|--------------------|--------------------|--------------------|--------|
| orders <> users    | INNER JOIN ON user_id | LEFT JOIN ON user_id | Query A drops users with no orders; Query B keeps them |
| orders <> refunds  | LEFT JOIN ON order_id | [not present]      | Query A subtracts refunds; Query B does not |
```

**Key insight**: INNER vs LEFT JOIN is the single most common cause of metric disagreements. Always check this first.

### 1.3 Filter Conditions (WHERE / HAVING)
Compare every filter in both queries:

```
| Filter                | Query A                         | Query B                         | Impact |
|-----------------------|---------------------------------|---------------------------------|--------|
| Date range            | created_at >= '2024-01-01'      | created_at > '2024-01-01'      | Query A includes Jan 1; Query B excludes it (>= vs >) |
| Status filter         | status NOT IN ('cancelled')     | status IN ('completed','pending') | Query A includes 'pending','refunded',etc.; Query B only 'completed','pending' |
| NULL handling         | [no NULL filter]                | WHERE amount IS NOT NULL        | Query B excludes NULL amounts |
```

Check for these specific filter discrepancies:
- **Inclusive vs exclusive date boundaries** (`>=` vs `>`, `<=` vs `<`)
- **Date truncation differences** (`DATE(created_at)` vs `created_at::date` vs raw timestamp comparison)
- **Timezone handling** (one query converts to local time, the other uses UTC)
- **NULL inclusion/exclusion** (explicit `IS NOT NULL` vs implicit exclusion through JOIN or aggregation)
- **Soft-delete handling** (one query filters `deleted_at IS NULL`, the other does not)
- **Test/internal data** (one query excludes test accounts, the other does not)

### 1.4 Aggregation Logic
Compare the aggregation approach:

```
| Dimension            | Query A                    | Query B                    | Impact |
|----------------------|----------------------------|----------------------------|--------|
| Aggregate function   | SUM(amount)                | SUM(DISTINCT amount)       | Query B deduplicates identical amounts (likely wrong) |
| Granularity          | GROUP BY month, region     | GROUP BY month             | Query A is more granular |
| DISTINCT usage       | COUNT(DISTINCT user_id)    | COUNT(user_id)             | Query B counts duplicate user appearances |
| NULL in aggregation  | SUM(amount) -- NULLs ignored | SUM(COALESCE(amount, 0))  | Same result for SUM, but semantically different |
```

### 1.5 Column Definitions
Compare how key columns are computed:

```
| Column      | Query A                              | Query B                              | Impact |
|-------------|--------------------------------------|--------------------------------------|--------|
| revenue     | price * quantity                     | price * quantity - discount           | Query B includes discounts |
| month       | DATE_TRUNC('month', created_at)      | DATE_TRUNC('month', shipped_at)      | Different date column! |
| user_count  | COUNT(DISTINCT user_id)              | COUNT(DISTINCT customer_id)          | Different ID column! |
```

### 1.6 Window Functions and Ordering
If either query uses window functions:
- Compare partition keys
- Compare ordering
- Check if one query uses `ROW_NUMBER` dedup while the other does not (could explain duplicate-related differences)

### 1.7 Set Operations
If either query uses UNION/UNION ALL/INTERSECT/EXCEPT:
- Compare the branches
- Check UNION vs UNION ALL (deduplication difference)

## Step 2: Semantic Analysis

Beyond structural comparison, analyze the semantic intent:

### 2.1 Metric Definition Alignment
Answer these questions:
- Do both queries define the metric the same way conceptually? (e.g., "revenue" = gross vs net?)
- Do both queries use the same time grain? (daily, weekly, monthly)
- Do both queries use the same entity as the unit of analysis? (orders vs customers vs transactions)
- Do both queries include/exclude the same populations? (all users vs paying users vs active users)

### 2.2 Edge Case Divergence Matrix
For each of these common edge cases, determine if the two queries handle them differently:

| Edge Case | Query A Behavior | Query B Behavior | Would Cause Difference? |
|-----------|-----------------|-----------------|------------------------|
| NULL values in key columns | [behavior] | [behavior] | [YES/NO] |
| Duplicate rows in source | [behavior] | [behavior] | [YES/NO] |
| Boundary dates (first/last of month) | [behavior] | [behavior] | [YES/NO] |
| Zero-value records | [behavior] | [behavior] | [YES/NO] |
| Negative values (refunds, adjustments) | [behavior] | [behavior] | [YES/NO] |
| Late-arriving data | [behavior] | [behavior] | [YES/NO] |
| Timezone conversion | [behavior] | [behavior] | [YES/NO] |
| Currency conversion | [behavior] | [behavior] | [YES/NO] |
| Deleted/cancelled records | [behavior] | [behavior] | [YES/NO] |

## Step 3: Numerical Reconciliation (When Database Is Available)

If the user can execute queries against a database, generate reconciliation queries to run. These queries isolate exactly where the disagreement occurs.

### 3.1 Total-Level Comparison
```sql
-- Run both queries and compare totals
WITH query_a AS (
    -- [Query A here]
),
query_b AS (
    -- [Query B here]
)
SELECT
    'Query A' AS source, [metric_column] AS metric_value FROM query_a
UNION ALL
SELECT
    'Query B' AS source, [metric_column] AS metric_value FROM query_b;
```

### 3.2 Dimension-Level Comparison
For each shared dimension (date, region, category, etc.), generate a comparison query:

```sql
-- Compare by [dimension]
WITH a AS (
    -- Query A aggregated by [dimension]
    SELECT [dimension], SUM([metric]) AS metric_a
    FROM ([Query A]) sub
    GROUP BY [dimension]
),
b AS (
    -- Query B aggregated by [dimension]
    SELECT [dimension], SUM([metric]) AS metric_b
    FROM ([Query B]) sub
    GROUP BY [dimension]
)
SELECT
    COALESCE(a.[dimension], b.[dimension]) AS [dimension],
    a.metric_a,
    b.metric_b,
    a.metric_a - b.metric_b AS absolute_diff,
    ROUND((a.metric_a - b.metric_b) * 100.0 / NULLIF(b.metric_b, 0), 2) AS pct_diff,
    CASE
        WHEN a.metric_a IS NULL THEN 'ONLY IN B'
        WHEN b.metric_b IS NULL THEN 'ONLY IN A'
        WHEN a.metric_a = b.metric_b THEN 'MATCH'
        WHEN ABS(a.metric_a - b.metric_b) < 0.01 THEN 'ROUNDING'
        ELSE 'MISMATCH'
    END AS status
FROM a
    FULL OUTER JOIN b ON a.[dimension] = b.[dimension]
WHERE a.metric_a IS DISTINCT FROM b.metric_b
ORDER BY ABS(COALESCE(a.metric_a, 0) - COALESCE(b.metric_b, 0)) DESC;
```

### 3.3 Row-Level Orphan Detection
Find records that exist in one query's intermediate results but not the other:

```sql
-- Records in Query A's source but not Query B's source
SELECT a.*
FROM ([Query A base table with filters]) a
    LEFT JOIN ([Query B base table with filters]) b ON a.[primary_key] = b.[primary_key]
WHERE b.[primary_key] IS NULL
LIMIT 100;

-- Records in Query B's source but not Query A's source
SELECT b.*
FROM ([Query B base table with filters]) b
    LEFT JOIN ([Query A base table with filters]) a ON b.[primary_key] = a.[primary_key]
WHERE a.[primary_key] IS NULL
LIMIT 100;
```

### 3.4 Aggregation Precision Check
```sql
-- Check for floating-point precision differences
SELECT
    a_total,
    b_total,
    a_total - b_total AS diff,
    ABS(a_total - b_total) < 0.01 AS is_rounding_only
FROM
    (SELECT SUM([metric])::NUMERIC(20,6) AS a_total FROM ([Query A]) x) a,
    (SELECT SUM([metric])::NUMERIC(20,6) AS b_total FROM ([Query B]) x) b;
```

## Step 4: Static Reconciliation (When No Database Is Available)

When the user cannot run queries, perform a purely analytical reconciliation:

### 4.1 Logic Trace
Trace the logical flow of both queries and identify every point of divergence. Produce a parallel walkthrough:

```
Step 1 (Source data):
  A: Reads from `orders` WHERE created_at >= '2024-01-01' AND status != 'cancelled'
  B: Reads from `orders` WHERE order_date >= '2024-01-01' AND status = 'completed'
  DIVERGENCE: Different date column (created_at vs order_date).
              Different status filter (excludes cancelled vs includes only completed).
              Impact: Query B excludes 'pending', 'processing', 'refunded' orders.

Step 2 (Join):
  A: LEFT JOIN refunds ON order_id (includes refund adjustments)
  B: [no refunds join]
  DIVERGENCE: Query A subtracts refunded amounts; Query B reports gross revenue.
  Impact: Query A will show lower revenue for periods with refunds.

Step 3 (Aggregation):
  A: SUM(amount - COALESCE(refund_amount, 0)) AS net_revenue
  B: SUM(amount) AS revenue
  DIVERGENCE: Confirmed -- Query A = net revenue, Query B = gross revenue.
```

### 4.2 Hypothetical Impact Sizing
For each divergence found, estimate the likely magnitude of impact:
- **Large impact** (>5% difference expected): Different source tables, missing joins, different status filters.
- **Medium impact** (1-5%): Different NULL handling, inclusive vs exclusive date boundaries.
- **Small impact** (<1%): Floating-point precision, rounding differences, DISTINCT vs non-DISTINCT on near-unique columns.
- **Zero impact**: Cosmetic differences (column aliases, formatting, CTE vs subquery style).

## Step 5: Root Cause Diagnosis

Synthesize all findings into a ranked list of root causes:

```
## Root Cause Analysis

### Primary Cause: [Title]
**Severity**: [percentage of total disagreement this explains, or qualitative: Major/Minor/Cosmetic]
**Location**: Query A line [N] vs Query B line [M]
**Explanation**: [Clear, specific explanation]
**Evidence**: [What in the structural/numerical analysis proves this]

### Secondary Cause: [Title]
...

### Contributing Factor: [Title]
...
```

Common root cause categories (check all):
1. **Different source tables or missing tables** -- one query reads from a table the other does not.
2. **Different join types** -- INNER vs LEFT drops or preserves rows differently.
3. **Different filter logic** -- WHERE clause conditions that include/exclude different records.
4. **Different date columns** -- `created_at` vs `updated_at` vs `shipped_at` vs `event_date`.
5. **Different date boundaries** -- `>=` vs `>`, different date truncation, timezone shifts.
6. **Different NULL handling** -- one query excludes NULLs, the other defaults them to zero.
7. **Different aggregation logic** -- COUNT vs COUNT DISTINCT, SUM vs SUM DISTINCT.
8. **Different metric definition** -- gross vs net, including vs excluding certain record types.
9. **Duplicate amplification** -- a join creates duplicates in one query but not the other.
10. **HAVING vs WHERE placement** -- filter applied before vs after aggregation.
11. **Rounding and precision** -- different ROUND behavior or floating-point accumulation.
12. **Race condition / data freshness** -- queries run at different times against a changing dataset.

## Step 6: Reconciliation Report

Produce the final structured report:

```
## Metric Reconciliation Report

### Summary
| Item | Value |
|------|-------|
| Metric being reconciled | [metric name] |
| Query A source | [file/inline/model] |
| Query B source | [file/inline/model] |
| Overall verdict | MATCH / PARTIAL MISMATCH / SIGNIFICANT MISMATCH / FUNDAMENTAL DISAGREEMENT |
| Estimated discrepancy | [X% or $X or N rows] |
| Root causes found | [count] |

### Do They Agree?

**At the total level**: [YES / NO / WITHIN ROUNDING (< 0.01%)]
**By date period**: [YES / NO -- specify which periods diverge]
**By dimension**: [YES / NO -- specify which dimensions diverge]
**At the row level**: [YES / NO -- specify orphan counts]

### Root Causes (Ranked by Impact)

1. **[Root cause]**: [explanation] -- estimated [X]% of total discrepancy
2. **[Root cause]**: [explanation] -- estimated [Y]% of total discrepancy
3. ...

### Line-by-Line Diagnosis

| Line(s) | Query A | Query B | Discrepancy Type | Impact |
|----------|---------|---------|-----------------|--------|
| A:5, B:8 | `INNER JOIN users` | `LEFT JOIN users` | Join type | Users without orders included in B |
| A:12, B:- | `LEFT JOIN refunds` | [missing] | Missing table | Refunds not deducted in B |
| A:18, B:22 | `created_at >= '2024-01-01'` | `created_at > '2024-01-01'` | Date boundary | Jan 1 records missing from B |

### Recommended Canonical Query

Based on the analysis, here is the recommended single source of truth query that resolves all identified discrepancies:

```sql
-- Canonical [metric_name] query
-- Resolves: [list of root causes addressed]
-- Assumptions: [list key assumptions made]
[Optimized, corrected query that produces the "correct" answer]
```

Explain why each choice was made in the canonical query:
1. **[Choice]**: [Rationale] (aligned with Query [A/B])
2. **[Choice]**: [Rationale]
3. ...

### Verification Queries

Provide queries the user can run to verify the canonical query matches expectations:

```sql
-- Verify canonical query matches Query [A/B] after adjustments
-- Expected result: zero rows (all match)
[Verification query]
```

### Prevention Recommendations

1. **[Recommendation]**: [How to prevent this type of disagreement in the future]
2. **[Recommendation]**: ...
3. **[Recommendation]**: ...

Common recommendations to consider:
- Define metrics in a single canonical location (dbt metrics, metric layer, data dictionary).
- Add data tests that cross-check critical metrics across models.
- Use a semantic layer to ensure all consumers use the same SQL.
- Document filter assumptions (which statuses are included, how NULLs are handled).
- Add reconciliation checks to CI/CD pipeline.
```

## Edge Cases

- **Queries that are structurally identical**: Report "MATCH -- queries are structurally equivalent" and note any cosmetic differences (aliases, formatting, comment differences). No root cause analysis needed.
- **Queries in different dialects**: Normalize both to a common pseudo-SQL for comparison. Note dialect-specific behavior differences (e.g., MySQL treats NULLs differently in GROUP BY than PostgreSQL).
- **Queries with Jinja/dbt templating**: Attempt to resolve `ref()` and `source()` to actual table names for comparison. If variables are used (`{{ var('start_date') }}`), note that different variable values would produce different results.
- **Queries that produce different column sets**: Compare only the overlapping columns. Note the non-overlapping columns as potential scope differences.
- **One query is a superset of the other**: One query may intentionally include more data (e.g., including pending orders). Identify this as a filter scope difference, not an error.
- **Queries with non-deterministic results**: If either query uses `LIMIT` without `ORDER BY`, `ROW_NUMBER()` without a unique tiebreaker, or `SAMPLE`/`TABLESAMPLE`, note that results may vary between runs.
- **Very large queries (50+ lines each)**: Break the comparison into sections (source selection, filtering, joining, aggregation) and compare each section independently before synthesizing.
- **Queries against different databases or schemas**: Note that even with identical logic, different databases may contain different data (stale replicas, partial syncs, schema drift). Recommend running both against the same database instance.
- **Metric involves multiple queries (e.g., ratio metrics)**: Compare numerator and denominator separately, then compare the ratio. A discrepancy in the ratio can come from either component.
