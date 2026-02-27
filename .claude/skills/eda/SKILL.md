---
name: eda
description: >
  Perform comprehensive Exploratory Data Analysis on any dataset. Use when the user
  mentions a new dataset, says "explore this data", "profile this table", "what does
  this data look like", uploads a CSV/Parquet file, or needs to understand distributions,
  nulls, correlations, and outliers before deeper analysis.
allowed-tools: Bash, Read, Glob, Grep
---

# Exploratory Data Analysis (EDA)

You are an expert data analyst performing a thorough exploratory data analysis. Follow every section below systematically. Do not skip sections. Adapt your approach based on whether the input is a file (CSV, Parquet, JSON) or a database table.

## Step 0: Environment Setup

```python
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', 100)
pd.set_option('display.float_format', lambda x: f'{x:.4f}')
sns.set_style('whitegrid')
```

## Step 1: Data Ingestion

- If the user provides a **file path**, load it with the appropriate reader:
  - CSV: `pd.read_csv(path, low_memory=False)`
  - Parquet: `pd.read_parquet(path)`
  - JSON: `pd.read_json(path)`
  - Excel: `pd.read_excel(path)`
- If the user provides a **SQL table or query**, connect using the credentials or connection string they provide, then load via `pd.read_sql()`.
- If the dataset has more than 5 million rows, sample 1 million rows for profiling but note the full row count. Use `df.sample(n=1_000_000, random_state=42)` and clearly state that profiling is based on a sample.
- Immediately print: row count, column count, memory usage (`df.memory_usage(deep=True).sum() / 1024**2` in MB).

## Step 2: Schema Overview

Produce a table with one row per column containing:

| Column | Dtype | Non-Null Count | Null % | Unique Count | Sample Values (up to 5) |
|--------|-------|----------------|--------|--------------|------------------------|

```python
schema = pd.DataFrame({
    'dtype': df.dtypes,
    'non_null': df.notnull().sum(),
    'null_pct': (df.isnull().sum() / len(df) * 100).round(2),
    'unique': df.nunique(),
    'sample_values': [df[col].dropna().unique()[:5].tolist() for col in df.columns]
})
print(schema.to_markdown())
```

Classify each column into one of these types:
- **Numeric continuous** (float, high cardinality int)
- **Numeric discrete** (low cardinality int, ordinal)
- **Categorical** (string/object with < 50 unique values)
- **High-cardinality categorical** (string/object with >= 50 unique values)
- **DateTime**
- **Boolean**
- **Identifier / Primary Key** (unique or near-unique, often named `id`, `uuid`, `key`)
- **Free text** (long strings, high uniqueness)

## Step 3: Missing Value Analysis

```python
missing = df.isnull().sum()
missing = missing[missing > 0].sort_values(ascending=False)
missing_pct = (missing / len(df) * 100).round(2)
```

- Report columns with > 0% missing, sorted by severity.
- Flag columns with > 50% missing as candidates for removal.
- Check for **missing value patterns**: are nulls correlated across columns? Use `df[missing.index].isnull().corr()` and flag pairs with correlation > 0.5.
- Check for **disguised missing values**: empty strings `""`, strings like `"N/A"`, `"null"`, `"none"`, `"-"`, `"unknown"`, zeros in columns where zero is not a valid value.

## Step 4: Numeric Column Analysis

For each numeric continuous column:

1. **Descriptive statistics**: count, mean, std, min, 1st percentile, 25th, median, 75th, 99th percentile, max.
2. **Distribution shape**: skewness and kurtosis. Flag if |skew| > 2 (highly skewed) or kurtosis > 7 (heavy-tailed).
3. **Outlier detection** using IQR method:
   - Q1 = 25th percentile, Q3 = 75th percentile, IQR = Q3 - Q1
   - Lower bound: Q1 - 1.5 * IQR
   - Upper bound: Q3 + 1.5 * IQR
   - Report count and percentage of outliers.
4. **Zero and negative value counts** (important for financial/count data).
5. **Histogram** with KDE overlay. Save to file.

```python
for col in numeric_cols:
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))
    axes[0].hist(df[col].dropna(), bins=50, edgecolor='black', alpha=0.7)
    axes[0].set_title(f'{col} - Distribution')
    axes[1].boxplot(df[col].dropna(), vert=True)
    axes[1].set_title(f'{col} - Box Plot')
    plt.tight_layout()
    plt.savefig(f'eda_{col}_distribution.png', dpi=150, bbox_inches='tight')
    plt.close()
```

## Step 5: Categorical Column Analysis

For each categorical column (< 50 unique values):

1. **Value counts** with percentages (show top 20 if more than 20 categories).
2. **Mode and mode frequency**.
3. **Bar chart** of value distribution. Save to file.
4. **Flag potential issues**:
   - Categories that appear only once (singletons).
   - Near-duplicate categories (e.g., "US" vs "us" vs "United States") -- use case-insensitive comparison and note suspicious pairs.
   - Highly imbalanced categories (one category > 90% of values).

For high-cardinality categorical columns (>= 50 unique values):
- Report only top 20 values and the long-tail distribution (how many categories appear fewer than 10 times).
- Do NOT create bar charts for these.

## Step 6: DateTime Column Analysis

For each datetime column:

1. Parse to datetime if not already: `pd.to_datetime(df[col], errors='coerce')`.
2. Report: min date, max date, date range span, number of records with invalid/unparseable dates.
3. **Temporal distribution**: count of records by month or week. Plot a time series line chart.
4. **Gap detection**: identify any periods with zero or anomalously low record counts.
5. **Day-of-week and hour-of-day patterns** if timestamps have time components.

## Step 7: Correlation Analysis

For numeric columns:

```python
corr_matrix = df[numeric_cols].corr()
```

1. **Heatmap** of the full correlation matrix. Save to file.
2. **Highly correlated pairs**: list all pairs with |correlation| > 0.7, sorted by absolute correlation. These may indicate multicollinearity or redundant features.
3. **Weakly correlated columns**: columns with max |correlation| < 0.1 with all other columns (may be noise or require feature engineering).

If categorical columns exist, compute **point-biserial correlation** between binary categoricals and numeric columns, or **Cramer's V** between categorical pairs.

## Step 8: Cross-Column Relationships

1. **Numeric vs Categorical**: for each categorical column with 2-10 categories, compute the mean/median of key numeric columns grouped by category. Flag statistically meaningful differences.
2. **Identifier analysis**: check if any column is a valid primary key (100% unique, no nulls). Check for composite keys if no single-column key exists.
3. **Potential foreign keys**: columns with names ending in `_id` or matching patterns of other table names.

## Step 9: Outlier and Anomaly Summary

Consolidate all outlier findings:

| Column | Outlier Method | Count | % of Data | Min Outlier | Max Outlier | Recommendation |
|--------|---------------|-------|-----------|-------------|-------------|----------------|

Recommendations should be one of:
- **Investigate**: unusual but potentially valid (< 5% outliers)
- **Cap/Winsorize**: likely data entry errors at extremes
- **Remove**: clearly invalid (e.g., negative ages, dates in the future)
- **Keep**: domain-expected outliers (e.g., power-law distributions)

## Step 10: Summary Report

Generate a structured summary with these exact sections:

```
## EDA Summary Report
**Dataset**: [name/path]
**Generated**: [timestamp]
**Rows**: [count] | **Columns**: [count] | **Memory**: [size]

### Key Findings
1. [Most important observation about the data]
2. [Second most important observation]
3. [Third most important observation]
... (up to 10)

### Data Quality Issues
- [List each issue with severity: CRITICAL / WARNING / INFO]

### Column Type Summary
- Numeric: [count] columns
- Categorical: [count] columns
- DateTime: [count] columns
- Boolean: [count] columns
- Identifier: [count] columns
- Text: [count] columns

### Recommended Next Steps
1. [Specific, actionable recommendation]
2. [Another recommendation]
...
```

## Output Requirements

- Save all generated charts as PNG files in the current working directory with descriptive names prefixed with `eda_`.
- Print the full summary report to stdout.
- If the user asks for a "quick" or "brief" EDA, skip Steps 7 and 8, reduce Step 4 to just descriptive statistics (no charts), and keep the summary to 5 findings.
- Always end by asking the user if they want to dive deeper into any specific column or relationship.

## Edge Cases

- **Empty dataset**: report immediately and stop.
- **Single column**: skip correlation analysis.
- **All nulls in a column**: report it but exclude from distribution analysis.
- **Mixed types in a column**: attempt to coerce, report the coercion results.
- **Very wide datasets (>200 columns)**: group columns by prefix (e.g., `user_`, `order_`) and summarize groups before individual analysis. Only produce charts for the 20 most interesting columns (highest variance, most missing, most correlated).
