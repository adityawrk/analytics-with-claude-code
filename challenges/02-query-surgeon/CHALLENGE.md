# Challenge 02: Query Surgeon

**Difficulty:** Intermediate | **Time:** 15 minutes | **Skills:** `/sql-optimizer`, `/explain-sql`

---

## Scenario

A junior analyst wrote a query to generate the monthly revenue report. It
produces the correct results, but it takes 45 seconds to run on the demo
dataset — and on production (with 100x the data) it times out entirely.

Your job: rewrite this query so it runs in under 1 second while returning
identical results.

---

## The Terrible Query

This query is meant to answer: "For each month in 2025, show total revenue,
number of unique customers, average order value, and the top-selling product
category — but only for completed orders from customers who signed up before
2025."

```sql
SELECT *
FROM (
    SELECT
        (SELECT EXTRACT(YEAR FROM o.order_date)) as order_year,
        (SELECT EXTRACT(MONTH FROM o.order_date)) as order_month,
        (SELECT SUM(o2.total_amount)
         FROM orders o2
         WHERE EXTRACT(YEAR FROM o2.order_date) = EXTRACT(YEAR FROM o.order_date)
           AND EXTRACT(MONTH FROM o2.order_date) = EXTRACT(MONTH FROM o.order_date)
           AND o2.status = 'completed'
           AND o2.customer_id IN (
               SELECT customer_id FROM customers
               WHERE signup_date < '2025-01-01'
           )
        ) as total_revenue,
        (SELECT COUNT(DISTINCT o3.customer_id)
         FROM orders o3
         WHERE EXTRACT(YEAR FROM o3.order_date) = EXTRACT(YEAR FROM o3.order_date)
           AND EXTRACT(MONTH FROM o3.order_date) = EXTRACT(MONTH FROM o.order_date)
           AND o3.status = 'completed'
           AND o3.customer_id IN (
               SELECT customer_id FROM customers
               WHERE signup_date < '2025-01-01'
           )
        ) as unique_customers,
        (SELECT SUM(o4.total_amount) / COUNT(*)
         FROM orders o4
         WHERE EXTRACT(YEAR FROM o4.order_date) = EXTRACT(YEAR FROM o4.order_date)
           AND EXTRACT(MONTH FROM o4.order_date) = EXTRACT(MONTH FROM o.order_date)
           AND o4.status = 'completed'
           AND o4.customer_id IN (
               SELECT customer_id FROM customers
               WHERE signup_date < '2025-01-01'
           )
        ) as avg_order_value,
        (SELECT p.category
         FROM products p
         WHERE p.product_id = (
             SELECT o5.product_id
             FROM orders o5
             WHERE EXTRACT(YEAR FROM o5.order_date) = EXTRACT(YEAR FROM o.order_date)
               AND EXTRACT(MONTH FROM o5.order_date) = EXTRACT(MONTH FROM o.order_date)
               AND o5.status = 'completed'
               AND o5.customer_id IN (
                   SELECT customer_id FROM customers
                   WHERE signup_date < '2025-01-01'
               )
             GROUP BY o5.product_id
             ORDER BY SUM(o5.total_amount) DESC
             LIMIT 1
         )
        ) as top_category
    FROM orders o
    WHERE o.order_date >= '2025-01-01'
      AND o.order_date < '2026-01-01'
      OR o.status = 'completed'
      OR o.status = 'cancelled'
      OR o.status = 'returned'
) subq
WHERE subq.order_year = 2025
GROUP BY subq.order_year, subq.order_month, subq.total_revenue,
         subq.unique_customers, subq.avg_order_value, subq.top_category
ORDER BY subq.order_month
```

---

## What's Wrong With It

Don't read this section until you've tried to spot the problems yourself.
Use `/explain-sql` first to have Claude walk through the query, then use
`/sql-optimizer` to fix it.

<details>
<summary>Click to reveal the problems (spoilers)</summary>

1. **SELECT * with unnecessary outer wrapper** — The outer query adds nothing;
   the GROUP BY just deduplicates what shouldn't be duplicated in the first place.

2. **Correlated subqueries instead of joins** — Each column is computed by a
   separate subquery that re-scans the orders table. This means the orders table
   is scanned 5+ times instead of once.

3. **Repeated IN subquery** — The `customer_id IN (SELECT ...)` filter is
   identical in four places but evaluated independently each time.

4. **EXTRACT on every row** — Using `EXTRACT(YEAR FROM ...)` and
   `EXTRACT(MONTH FROM ...)` prevents the use of date-range indexes. A
   simple `BETWEEN` or `>=`/`<` on the date column is far more efficient.

5. **OR instead of proper WHERE** — The WHERE clause uses OR across unrelated
   conditions (`o.order_date >= '2025-01-01' ... OR o.status = 'completed'`),
   which effectively selects almost all rows and bypasses any date filtering.
   The operator precedence means this doesn't do what the author intended.

6. **Bug in unique_customers** — The subquery compares
   `EXTRACT(YEAR FROM o3.order_date) = EXTRACT(YEAR FROM o3.order_date)` (same
   alias on both sides), which is always true — it counts all months, not the
   current month.

7. **Missing parentheses around OR conditions** — The WHERE clause lacks
   parentheses, so AND/OR precedence produces unintended results.

8. **AVG calculated as SUM/COUNT(*)** — This includes cancelled/returned orders
   in the denominator even though the SUM only covers completed ones (the
   status filter is in a subquery but COUNT(*) counts all rows matched by the
   outer conditions).

</details>

---

## Your Mission

1. **Start** by running `/explain-sql` on the query above. Read Claude's
   analysis of what each part does (and where it goes wrong).

2. **Run** `/sql-optimizer` and let Claude propose a rewritten version.

3. **Verify** the optimized query returns the same results as the original
   (for the rows where the original is actually correct).

4. **Compare** execution plans if possible — use `EXPLAIN ANALYZE` in DuckDB.

---

## Success Criteria

- [ ] All 5+ performance problems identified
- [ ] The logical bug (self-join on same alias) identified
- [ ] Rewritten query uses CTEs instead of correlated subqueries
- [ ] Rewritten query scans the orders table once (or twice at most)
- [ ] Results match for all 12 months of 2025
- [ ] Execution time is under 1 second on the demo dataset

**Bonus:** Can you write it as a single pass with window functions?
