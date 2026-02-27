# Challenge 03: Metric Mystery

**Difficulty:** Advanced | **Time:** 20 minutes | **Skills:** `/metric-reconciler`

---

## Scenario

It's Monday morning. The CEO opens the weekly dashboard and announces to the
leadership team: "Great news — revenue was up 15% last month!"

The CFO frowns, checks her own report, and replies: "Actually, revenue was
down 5% compared to the prior month."

Both are looking at November 2025 data. Both are technically correct. The board
meeting is in two hours and they need to present a single number.

Your job: figure out why the numbers differ, determine which definition is
appropriate for which audience, and write a reconciliation report.

---

## The CEO's Query

This is the query behind the executive dashboard. It was written by a
contractor two years ago and nobody has touched it since.

```sql
-- CEO Dashboard: Monthly Revenue
SELECT
    DATE_TRUNC('month', order_date) AS month,
    ROUND(SUM(total_amount), 2) AS revenue
FROM orders
WHERE order_date >= '2025-10-01'
  AND order_date < '2025-12-01'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;
```

## The CFO's Query

This is the query the finance team uses for the monthly close. It was written
by the analytics engineering team and reviewed by the auditors.

```sql
-- Finance Monthly Close: Net Revenue
SELECT
    DATE_TRUNC('month', order_date) AS month,
    ROUND(
        SUM(CASE WHEN status = 'completed' THEN total_amount
                 WHEN status = 'returned' THEN -total_amount
                 ELSE 0 END),
        2
    ) AS net_revenue
FROM orders
WHERE order_date >= '2025-10-01'
  AND order_date < '2025-12-01'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;
```

---

## Why They Disagree

There are at least **three reasons** these queries produce different numbers.
Before you peek below, run both queries against the demo database and compare
the outputs. Then use `/metric-reconciler` to have Claude analyze the gap.

<details>
<summary>Click to reveal the differences (spoilers)</summary>

### Difference 1: Order Status Filtering

The CEO's query includes **all orders** regardless of status — completed,
cancelled, and returned. The CFO's query only includes completed and returned
orders, and subtracts returned amounts. Cancelled orders are excluded entirely
from the CFO's number.

**Impact:** The CEO's number is inflated by cancelled orders that never
generated real revenue.

### Difference 2: Treatment of Returns

The CEO's query counts returned orders as **positive** revenue (they're just
rows with a `total_amount`). The CFO's query counts them as **negative** —
subtracting the returned amount from the total.

**Impact:** A month with high returns looks much worse in the CFO's report
than in the CEO's.

### Difference 3: What "Up 15%" and "Down 5%" Mean

Both are comparing November 2025 to October 2025, but the underlying
numbers are so different that the month-over-month percentage change goes in
opposite directions. This happens because:

- Gross revenue (CEO) went up because order volume increased in November
  (seasonal Q4 spike), even though more orders were cancelled.
- Net revenue (CFO) went down because the return rate spiked in November
  (possibly from Q4 impulse purchases being returned), wiping out the
  volume gains.

</details>

---

## Your Mission

1. **Run both queries** against the demo database and record the results.

2. **Use `/metric-reconciler`** — paste both queries and ask Claude to
   reconcile the difference.

3. **Quantify the gap** — for each of the three differences, calculate exactly
   how many dollars it accounts for. The sum of all three gaps should equal the
   total difference between the two numbers.

4. **Write a reconciliation bridge** — a query (or set of queries) that starts
   with the CEO's number and walks step by step to the CFO's number:

   ```
   CEO Gross Revenue (November)              $XXX,XXX
   - Cancelled orders                        -$XX,XXX
   - Returned orders (counted as positive)   -$XX,XXX
   - Returns adjustment (counted as negative) -$XX,XXX
   = CFO Net Revenue (November)              $XXX,XXX
   ```

5. **Recommend** which metric to present at the board meeting, and why.

---

## Success Criteria

- [ ] Both queries executed and results compared
- [ ] All three differences identified and explained
- [ ] Dollar-level reconciliation bridge produced
- [ ] Each gap component accounts for a specific dollar amount
- [ ] Bridge walks cleanly from CEO number to CFO number
- [ ] Recommendation written for which metric to use and when

**Bonus:** Write a unified query that calculates gross revenue, net revenue,
and the bridge components all in one pass, broken down by month.
