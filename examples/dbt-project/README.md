# Example: Building dbt Models with Claude Code

## Scenario
You're setting up analytics for an e-commerce platform. The raw data lands in a `raw` schema with tables for orders, customers, and products. You need to build a proper dbt project with staging, intermediate, and mart layers.

## Steps

### 1. Use the data explorer agent to understand the source
```bash
cd examples/dbt-project
claude
```

```
> Use the data-explorer agent to map all tables in the raw schema,
> their columns, relationships, and data quality
```

The agent will:
- Query `information_schema` to discover tables
- Profile each table (row counts, key columns, freshness)
- Map foreign key relationships
- Document findings

### 2. Use the pipeline builder agent to create models
```
> Use the pipeline-builder agent to create dbt models for this e-commerce data.
> I need: staging models for all raw tables, an intermediate model joining
> orders with customers, and mart models for fct_orders and dim_customers.
```

The agent will create:
- `models/staging/stg_raw__orders.sql` + schema.yml
- `models/staging/stg_raw__customers.sql` + schema.yml
- `models/staging/stg_raw__products.sql` + schema.yml
- `models/intermediate/int_orders__enriched.sql`
- `models/marts/fct_orders.sql` + schema.yml
- `models/marts/dim_customers.sql` + schema.yml

### 3. Validate with the analytics reviewer
```
> Use the analytics-reviewer agent to review all the dbt models we just created.
> Check SQL logic, test coverage, and documentation completeness.
```

### 4. Run and test
```
> Run dbt build and fix any issues
```

## What You'll Learn
- How to orchestrate multiple agents for a complete workflow
- How the data-explorer agent maps unfamiliar data
- How the pipeline-builder agent follows dbt conventions
- How the analytics-reviewer agent catches issues before production
