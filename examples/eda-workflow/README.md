# Example: Exploratory Data Analysis Workflow

## Scenario
You've just received `sample_sales.csv` -- a dataset of 10,000 e-commerce transactions. Before building any models or dashboards, you need to understand the data.

## Sample Data
The `data/` directory contains `sample_sales.csv` with these columns:
- `order_id` -- Unique order identifier
- `customer_id` -- Customer identifier
- `order_date` -- Transaction date
- `product_category` -- Product category
- `quantity` -- Items purchased
- `unit_price` -- Price per item
- `total_amount` -- Order total
- `city` -- Customer city
- `payment_method` -- Payment type
- `status` -- Order status (completed, cancelled, returned)

## Steps

### 1. Start Claude Code in your project
```bash
cd examples/eda-workflow
claude
```

### 2. Run the EDA skill
```
> /eda data/sample_sales.csv
```

Claude will:
- Read the file and report shape, dtypes, memory usage
- Calculate null rates for every column
- Generate summary statistics for numeric columns
- Show value distributions for categorical columns
- Identify outliers using IQR method
- Compute correlation matrix for numeric columns
- Produce a structured markdown report

### 3. Follow up with targeted questions
```
> What's the revenue trend by month? Is there seasonality?
> Which product categories have the highest return rates?
> Are there any customers with suspiciously high order volumes?
```

### 4. Run data quality checks
```
> /data-quality data/sample_sales.csv
```

This validates completeness, uniqueness, and value ranges.

## Expected Output
After running `/eda`, you should see a structured report covering:
- Dataset overview (rows, columns, dtypes)
- Missing value analysis
- Numeric column distributions (mean, median, std, min, max, quartiles)
- Categorical column breakdowns (top values, cardinality)
- Correlation matrix
- Outlier detection results
- Key findings and recommended next steps

## What You'll Learn
- How to use the `/eda` skill for rapid dataset understanding
- How to chain skills with natural language follow-ups
- How Claude Code maintains context across a session
