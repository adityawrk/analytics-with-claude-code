# Analytics with Claude Code — Live Demo

**Try a complete analytics workflow in under 60 seconds.**
No database server. No API keys. No configuration.

This demo bundles a realistic DuckDB dataset so you can experience every skill,
slash command, and agent workflow without connecting to a production system.

---

## Quick Start

```bash
cd demo
pip install duckdb           # or use your preferred virtual environment
python setup_demo_data.py    # generates the sample database (~3 seconds)
claude                       # start Claude Code in this directory
```

That's it. The `CLAUDE.md` in this directory tells Claude about the dataset,
so it's ready to answer questions immediately.

---

## 5 Things to Try

Work through these in order — each one builds on the last and shows
progressively more powerful capabilities.

### 1. Run Exploratory Data Analysis

```
/eda
```

Claude scans every table, profiles columns, spots outliers, and produces a
structured summary — all without you writing a single query.

### 2. Ask a Plain-English Question

```
What were the top 10 customers by revenue last quarter?
```

Watch Claude translate natural language into precise SQL, execute it against
DuckDB, and return a formatted result. Try follow-up questions — context
carries over.

### 3. Request a Complex Multi-Step Analysis

```
Build a cohort retention analysis grouped by signup month.
```

This requires joining customers to orders, bucketing by cohort, pivoting by
period, and formatting the output. Claude handles the entire pipeline.

### 4. Explain a Generated Query

After any of the above, run:

```
/explain-sql
```

Claude takes the last generated query and walks through it clause-by-clause:
what each CTE does, where filters apply, and what the optimizer sees.

### 5. Map the Full Data Model

```
Use the data-explorer agent to map all tables and relationships.
```

The agent inspects every table, infers foreign keys, identifies join paths,
and produces a relationship diagram you can paste into documentation.

---

## What's in the Sample Data

The demo database (`data/analytics_demo.duckdb`) contains four tables that
model a realistic e-commerce business:

| Table       | Rows    | Description                                    |
|-------------|---------|------------------------------------------------|
| `customers` | ~2,000  | Customer profiles with segments and cities     |
| `orders`    | ~10,000 | Two years of orders with status and payments   |
| `products`  | ~200    | Product catalog with cost and list prices      |
| `events`    | ~50,000 | Clickstream funnel events with device info     |

**Date range:** 2024-01-01 to 2025-12-31

**Realistic characteristics baked in:**

- Revenue follows seasonal patterns (Q4 spike, Q1 dip)
- ~15% of orders are cancelled or returned
- Customer activity follows a Pareto distribution (power users exist)
- Funnel drop-off mirrors real e-commerce conversion rates
- A handful of intentional data quality issues (null cities, duplicate orders,
  mispriced products) so `/data-quality` has something to find

---

## Using the Demo as a Learning Sandbox

This dataset is designed to exercise every skill in the repository:

| Skill / Command         | What to try in the demo                                     |
|-------------------------|-------------------------------------------------------------|
| `/eda`                  | Profile the full database or a single table                 |
| `/data-quality`         | Find the planted nulls, duplicates, and pricing errors      |
| `/sql-optimizer`        | Write a slow query on purpose, then optimize it             |
| `/explain-sql`          | Understand any generated query step by step                 |
| `/metric-calculator`    | Define and compute MRR, churn rate, or LTV                  |
| `/metric-reconciler`    | Compare revenue calculated two different ways               |
| `/ab-test`              | Simulate a test using the events table                      |
| `/pipeline-builder`     | Build a transformation pipeline for the orders table        |
| `data-explorer` agent   | Map the schema and all join paths                           |

When you're comfortable, move on to the [challenges](../challenges/) to test
your skills against progressively harder scenarios.

---

## Troubleshooting

**`ModuleNotFoundError: No module named 'duckdb'`**
Run `pip install duckdb` (or `pip3 install duckdb`).

**Database file not found**
Run `python setup_demo_data.py` from inside the `demo/` directory. The script
creates `data/analytics_demo.duckdb`.

**Want to start fresh?**
Just run `python setup_demo_data.py` again — it drops and recreates all tables.
