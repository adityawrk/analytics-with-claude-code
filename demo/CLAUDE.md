# Demo Analytics Environment

You are working with a DuckDB analytics database at `demo/data/analytics_demo.duckdb`.
Use the DuckDB CLI (`duckdb data/analytics_demo.duckdb`) or Python (`import duckdb`) to run queries.

## Database Schema

**customers** (~2,000 rows)
- customer_id (INTEGER PK), name (VARCHAR), email (VARCHAR)
- city (VARCHAR, nullable — some nulls exist), signup_date (DATE)
- segment (VARCHAR): 'enterprise', 'mid-market', 'smb'

**orders** (~10,000 rows)
- order_id (INTEGER PK), customer_id (INTEGER FK→customers)
- order_date (DATE), product_id (INTEGER FK→products)
- quantity (INTEGER), unit_price (DECIMAL(10,2)), total_amount (DECIMAL(10,2))
- status (VARCHAR): 'completed', 'cancelled', 'returned'
- payment_method (VARCHAR): 'credit_card', 'debit_card', 'paypal', 'wire_transfer'

**products** (~200 rows)
- product_id (INTEGER PK), name (VARCHAR)
- category (VARCHAR), subcategory (VARCHAR)
- cost_price (DECIMAL(10,2)), list_price (DECIMAL(10,2))
- Note: a few products intentionally have list_price < cost_price

**events** (~50,000 rows)
- event_id (INTEGER PK), customer_id (INTEGER FK→customers)
- event_type (VARCHAR): 'page_view', 'add_to_cart', 'checkout_start', 'purchase'
- event_date (TIMESTAMP), session_id (VARCHAR), device_type (VARCHAR): 'desktop', 'mobile', 'tablet'

## Key Relationships
- orders.customer_id → customers.customer_id
- orders.product_id → products.product_id
- events.customer_id → customers.customer_id

## Date Range
All data spans 2024-01-01 to 2025-12-31. Use this when interpreting "last quarter", "last month", etc. — treat 2025-12-31 as the current date.

## Metric Definitions
- **Revenue**: SUM(total_amount) WHERE status = 'completed'
- **Gross Revenue**: SUM(total_amount) for all orders regardless of status
- **AOV** (Average Order Value): Revenue / COUNT(DISTINCT order_id) WHERE status = 'completed'
- **Conversion Rate**: COUNT(DISTINCT purchase events) / COUNT(DISTINCT page_view sessions)
- **Customer LTV**: Revenue per customer over their full history

## Known Data Quality Issues
There are intentional quality issues planted in the data. Do not "fix" them silently — surface them when running /data-quality or /eda so the user can see them.
