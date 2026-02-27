---
name: data-quality
description: >
  Run a comprehensive data quality assessment and produce a scorecard across 6 dimensions:
  completeness, uniqueness, consistency, timeliness, accuracy, validity. Use when the user
  asks about data quality, mentions data issues, wants to audit a table, is onboarding a
  new data source, or needs to validate pipeline output.
---

# Data Quality Checker

You are a data quality engineer performing a rigorous assessment. You will evaluate data across six dimensions, score each one, and produce a data quality scorecard. Follow every section below.

## Step 0: Environment Setup

```python
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import hashlib
import re
import warnings
warnings.filterwarnings('ignore')

pd.set_option('display.max_columns', None)
pd.set_option('display.float_format', lambda x: f'{x:.4f}')
```

## Step 1: Data Ingestion and Context

1. Load the data (CSV, Parquet, database table, or DataFrame).
2. Ask the user or infer from context:
   - **What is this dataset?** (e.g., user events, transactions, product catalog)
   - **What is the grain?** (one row = one what?)
   - **What is the expected primary key?** (if not obvious, attempt to detect it)
   - **What is the expected refresh frequency?** (real-time, hourly, daily, weekly)
   - **Are there known constraints?** (e.g., `amount > 0`, `status IN ('active','inactive')`, `end_date >= start_date`)
3. Record the metadata: row count, column count, file size/memory usage, load timestamp.

## Step 2: Completeness Assessment

Completeness measures the extent to which expected data is present.

### 2.1 Column-Level Completeness

For every column, compute:

```python
completeness = pd.DataFrame({
    'column': df.columns,
    'null_count': df.isnull().sum().values,
    'null_pct': (df.isnull().sum() / len(df) * 100).round(2).values,
    'empty_string_count': [(df[col] == '').sum() if df[col].dtype == 'object' else 0 for col in df.columns],
    'disguised_null_count': [
        df[col].isin(['N/A', 'n/a', 'NA', 'null', 'NULL', 'None', 'none', '-', '--', 'unknown', 'UNKNOWN', 'TBD', 'tbd']).sum()
        if df[col].dtype == 'object' else 0
        for col in df.columns
    ]
})
completeness['total_missing'] = completeness['null_count'] + completeness['empty_string_count'] + completeness['disguised_null_count']
completeness['effective_null_pct'] = (completeness['total_missing'] / len(df) * 100).round(2)
```

Classification:
- **Complete** (0% missing): GREEN
- **Mostly complete** (0-5% missing): YELLOW
- **Incomplete** (5-20% missing): ORANGE
- **Severely incomplete** (>20% missing): RED

### 2.2 Row-Level Completeness

```python
row_completeness = df.notnull().sum(axis=1) / len(df.columns) * 100
```

Report: distribution of row completeness (min, 25th, median, 75th, max). Flag rows that are less than 50% complete.

### 2.3 Expected Columns Check

If the user provides an expected schema (column names and types), validate:
- Missing expected columns.
- Unexpected extra columns.
- Type mismatches.

**Completeness Score** = (1 - total effective nulls across all cells / total cells) * 100

## Step 3: Uniqueness Assessment

### 3.1 Primary Key Validation

If a primary key is specified or detected:

```python
pk_cols = ['id']  # or composite key
total_rows = len(df)
unique_rows = df[pk_cols].drop_duplicates().shape[0]
duplicate_count = total_rows - unique_rows
```

Report: total rows, unique key values, duplicate count, duplicate percentage. Show the top 10 most-duplicated key values.

### 3.2 Full Row Duplicates

```python
full_dupes = df.duplicated(keep=False).sum()
```

Flag exact duplicate rows (every column identical). These almost always indicate a pipeline bug.

### 3.3 Column Uniqueness Profile

For each column, compute uniqueness ratio = unique values / non-null count. Flag:
- Columns expected to be unique (like IDs) that are not.
- Columns with suspiciously low cardinality (e.g., a `user_id` column with only 3 unique values in 1M rows).

### 3.4 Near-Duplicate Detection

For string columns that should be unique (names, emails):

```python
# Check for case-insensitive duplicates
lower_unique = df[col].str.lower().str.strip().nunique()
original_unique = df[col].nunique()
if lower_unique < original_unique:
    print(f"WARNING: {original_unique - lower_unique} case/whitespace duplicates in {col}")
```

**Uniqueness Score** = 100 if primary key is fully unique, else (unique_pk_count / total_rows) * 100

## Step 4: Consistency Assessment

### 4.1 Format Consistency

For string columns, check for format consistency:

```python
def detect_formats(series):
    patterns = {
        'email': r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        'phone_us': r'^\+?1?[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}$',
        'uuid': r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        'date_iso': r'^\d{4}-\d{2}-\d{2}$',
        'url': r'^https?://[^\s]+$',
        'zip_us': r'^\d{5}(-\d{4})?$',
    }
    results = {}
    for name, pattern in patterns.items():
        match_count = series.dropna().str.match(pattern, na=False).sum()
        if match_count > 0:
            results[name] = match_count / series.dropna().shape[0] * 100
    return results
```

Flag columns where multiple formats coexist (e.g., dates as both "2024-01-01" and "01/01/2024").

### 4.2 Cross-Column Consistency

Check logical rules:
- `start_date <= end_date`
- `quantity * unit_price ~= total_price` (within rounding tolerance)
- `city` / `state` / `country` consistency (e.g., "New York" city should not appear with state "CA")
- Status fields that contradict other columns (e.g., `status = 'active'` but `deleted_at` is not null)

### 4.3 Referential Consistency

If multiple tables are provided, check foreign key integrity:

```python
orphan_count = df1[~df1['foreign_key'].isin(df2['primary_key'])].shape[0]
```

Report orphaned records (child records with no matching parent).

### 4.4 Categorical Consistency

For categorical columns with a known valid set:

```python
valid_values = {'active', 'inactive', 'suspended'}
invalid = df[~df['status'].isin(valid_values) & df['status'].notnull()]
```

Report invalid values and their counts. Also flag:
- Leading/trailing whitespace.
- Mixed case inconsistency (e.g., "Active" vs "active" vs "ACTIVE").

**Consistency Score** = (rows passing all consistency checks / total rows) * 100

## Step 5: Timeliness Assessment

### 5.1 Data Freshness

If the dataset has a timestamp column (created_at, updated_at, event_time):

```python
max_timestamp = df[timestamp_col].max()
freshness_lag = datetime.now() - max_timestamp
```

Classification:
- **Fresh** (lag < expected frequency): GREEN
- **Stale** (lag 1-3x expected frequency): YELLOW
- **Very stale** (lag > 3x expected frequency): RED

### 5.2 Temporal Coverage

Check for gaps in the time series:

```python
daily_counts = df.set_index(timestamp_col).resample('D').size()
missing_days = daily_counts[daily_counts == 0]
low_days = daily_counts[daily_counts < daily_counts.median() * 0.1]
```

Report: date range covered, days with zero records, days with anomalously low records.

### 5.3 Late-Arriving Data

If there is both an `event_time` and a `loaded_at`/`created_at` column:

```python
latency = (df['loaded_at'] - df['event_time']).dt.total_seconds()
```

Report: median latency, 95th percentile latency, max latency. Flag any records arriving more than 24 hours late.

**Timeliness Score** = 100 if fresh and no gaps, reduced by 10 for each day of staleness and 5 for each missing day in the expected range.

## Step 6: Accuracy Assessment

### 6.1 Range Checks

For numeric columns, validate against expected ranges:

```python
range_checks = {
    'age': (0, 120),
    'price': (0, None),  # None = no upper bound
    'latitude': (-90, 90),
    'longitude': (-180, 180),
    'percentage': (0, 100),
}
```

Apply any user-specified ranges. Also apply common-sense ranges:
- Dates should not be in the future (unless they are scheduled events).
- Monetary amounts should usually be positive.
- Counts should be non-negative integers.

### 6.2 Statistical Outliers

For numeric columns, flag values beyond 3 standard deviations or beyond the 0.1st / 99.9th percentiles. These are not necessarily wrong, but worth investigating.

### 6.3 Pattern Violations

Check for values that violate expected patterns:
- Email columns that fail basic validation.
- Phone numbers with wrong digit counts.
- Zip codes outside valid ranges.

### 6.4 Cross-Source Validation

If the user provides a reference dataset or known-good aggregates:

```python
expected_total_revenue = 1_234_567
actual_total_revenue = df['revenue'].sum()
variance_pct = abs(actual_total_revenue - expected_total_revenue) / expected_total_revenue * 100
```

Flag variances > 1%.

**Accuracy Score** = (rows passing all range and accuracy checks / total rows) * 100

## Step 7: Validity Assessment

### 7.1 Data Type Validity

Check that each column's values are valid for their expected type:
- Numeric columns contain only numbers (no stray strings).
- Date columns parse correctly.
- Boolean columns contain only true/false/null.

### 7.2 Business Rule Validation

Apply any business rules the user specifies. For example:
- Every order must have at least one line item.
- Refund amount must not exceed original order amount.
- User cannot have a subscription end date before the start date.

**Validity Score** = (rows passing all validity checks / total rows) * 100

## Step 8: Data Quality Scorecard

Produce the final scorecard:

```
============================================================
            DATA QUALITY SCORECARD
============================================================
Dataset:         [name]
Assessed:        [timestamp]
Rows:            [count]
Columns:         [count]
------------------------------------------------------------
Dimension        Score    Grade    Issues Found
------------------------------------------------------------
Completeness     [XX]%    [A-F]    [count] issues
Uniqueness       [XX]%    [A-F]    [count] issues
Consistency      [XX]%    [A-F]    [count] issues
Timeliness       [XX]%    [A-F]    [count] issues
Accuracy         [XX]%    [A-F]    [count] issues
Validity         [XX]%    [A-F]    [count] issues
------------------------------------------------------------
OVERALL SCORE    [XX]%    [A-F]
============================================================

Grading Scale: A (95-100) | B (85-94) | C (70-84) | D (50-69) | F (<50)
```

**Overall Score** = weighted average:
- Completeness: 20%
- Uniqueness: 20%
- Consistency: 20%
- Timeliness: 10%
- Accuracy: 20%
- Validity: 10%

Adjust weights if the user specifies different priorities.

## Step 9: Issue Register

Produce a table of all issues found, sorted by severity:

| # | Dimension | Severity | Column(s) | Description | Records Affected | Recommended Action |
|---|-----------|----------|-----------|-------------|-----------------|-------------------|
| 1 | Uniqueness | CRITICAL | order_id | 2,341 duplicate primary keys | 2,341 (0.5%) | Deduplicate; investigate pipeline |
| 2 | Accuracy | WARNING | price | 89 negative values | 89 (0.02%) | Validate business logic for refunds |
| ... | | | | | | |

Severity levels:
- **CRITICAL**: blocks analysis, data is unreliable for this dimension. Must fix before using.
- **WARNING**: data is usable with caveats. Should fix soon.
- **INFO**: minor issue, good to track but not blocking.

## Step 10: Recommendations

Provide actionable recommendations:

1. **Immediate fixes** (for CRITICAL issues).
2. **Pipeline improvements** (add validation, schema enforcement, deduplication).
3. **Monitoring suggestions** (what metrics to track over time, thresholds for alerts).
4. **Documentation gaps** (what metadata or context is missing).

## Edge Cases

- **Empty dataset**: score all dimensions as 0%, flag as CRITICAL.
- **Single-row dataset**: skip statistical checks, warn that sample size is too small.
- **No timestamp column**: skip Timeliness entirely, note it as "Not Assessed" in the scorecard.
- **User provides no context**: make reasonable assumptions but document them clearly. Ask the user to confirm key assumptions (primary key, expected ranges, valid categories).
- **Very large dataset (>10M rows)**: sample for statistical checks but compute exact counts for completeness and uniqueness on the full dataset. State clearly which checks used sampling.
