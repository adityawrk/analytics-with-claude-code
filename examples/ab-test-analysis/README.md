# Example: A/B Test Analysis

## Scenario
The product team ran an experiment testing a new checkout flow. Variant A (control) uses the existing 3-step checkout. Variant B (treatment) uses a new 1-page checkout. The experiment ran for 2 weeks with 50/50 traffic split. The primary metric is conversion rate; secondary metrics are average order value and time to complete.

## Sample Data
The `data/` directory contains `experiment_results.csv` with these columns:
- `user_id` -- Unique user identifier
- `variant` -- A (control) or B (treatment)
- `converted` -- 1 if purchased, 0 if not
- `order_value` -- Order amount (null if not converted)
- `time_to_complete_seconds` -- Checkout duration (null if not converted)
- `device_type` -- mobile, desktop, tablet
- `signup_date` -- User registration date
- `session_date` -- Experiment session date

## Steps

### 1. Start Claude Code
```bash
cd examples/ab-test-analysis
claude
```

### 2. Run the A/B test skill
```
> /ab-test data/experiment_results.csv --variant-col variant --metric-col converted
```

Claude will run the full analysis pipeline:
1. **Setup validation** -- Check sample sizes, exposure dates, traffic split
2. **Sample ratio mismatch** -- Chi-squared test for 50/50 split
3. **Per-variant metrics** -- Mean, median, confidence intervals for each variant
4. **Statistical significance** -- Z-test for proportions (conversion), t-test for continuous metrics
5. **Effect size** -- Absolute and relative lift with confidence intervals
6. **Segment analysis** -- Break results by device type
7. **Recommendation** -- Ship, don't ship, or run longer

### 3. Dig deeper
```
> Is the effect consistent across mobile vs desktop?
> Check for novelty effects -- is the treatment effect stable over the 2 weeks?
> What sample size would we need to detect a 1% lift with 80% power?
```

### 4. Generate the report
```
> /report-generator --type ab-test --title "Checkout Flow Experiment Results"
```

## What You'll Learn
- How to perform rigorous A/B test analysis with Claude Code
- Statistical testing methodology (frequentist approach)
- How to check for common experimental pitfalls (SRM, novelty effects)
- How to generate stakeholder-ready reports from analysis
