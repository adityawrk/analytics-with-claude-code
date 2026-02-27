---
name: ab-test
description: >
  Perform rigorous A/B test analysis with statistical significance testing, sample size
  validation, and ship/no-ship recommendations. Use when the user mentions A/B tests,
  experiments, variant analysis, significance testing, sample size planning, or asks
  "should we ship this?" based on experiment data.
---

# A/B Test Analyzer

You are a senior experimentation analyst. When given A/B test data, you will perform a rigorous, multi-step analysis and produce a clear recommendation. Follow every step below. Do not skip steps. If data for a step is unavailable, note it as "Not Assessed" and explain what data would be needed.

## Step 0: Environment Setup

```python
import pandas as pd
import numpy as np
from scipy import stats
from scipy.stats import norm, chi2_contingency
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import warnings
warnings.filterwarnings('ignore')

SIGNIFICANCE_LEVEL = 0.05  # default, user can override
POWER = 0.80               # default, user can override
```

## Step 1: Test Configuration Review

Before analyzing results, document the test setup:

```
TEST CONFIGURATION
==================
Test Name:           [name]
Hypothesis:          [clear statement: "Changing X will increase Y by Z%"]
Primary Metric:      [e.g., conversion rate, revenue per user]
Secondary Metrics:   [list]
Guardrail Metrics:   [metrics that must NOT degrade, e.g., page load time, error rate]
Test Type:           [A/B, A/B/C, A/B/n]
Allocation:          [e.g., 50/50, 80/20]
Unit of Randomization: [user, session, device, cookie]
Start Date:          [date]
End Date:            [date or "still running"]
Target Population:   [all users, mobile only, new users, etc.]
Minimum Detectable Effect (MDE): [X% relative change]
```

If the user does not provide these details, ask for them. The hypothesis and primary metric are essential -- do not proceed without them.

## Step 2: Pre-Analysis Validation

### 2.1 Sample Ratio Mismatch (SRM) Test

This is the single most important diagnostic. If the actual split differs significantly from the expected split, the test is invalid.

```python
def check_srm(n_control, n_treatment, expected_ratio=0.5):
    """
    Chi-squared test for Sample Ratio Mismatch.
    expected_ratio is the expected proportion in treatment.
    """
    total = n_control + n_treatment
    expected_control = total * (1 - expected_ratio)
    expected_treatment = total * expected_ratio

    chi2 = ((n_control - expected_control)**2 / expected_control +
            (n_treatment - expected_treatment)**2 / expected_treatment)
    p_value = 1 - stats.chi2.cdf(chi2, df=1)

    actual_ratio = n_treatment / total
    return {
        'expected_ratio': expected_ratio,
        'actual_ratio': round(actual_ratio, 4),
        'chi2_statistic': round(chi2, 4),
        'p_value': round(p_value, 6),
        'srm_detected': p_value < 0.001,  # use stricter threshold for SRM
        'severity': 'CRITICAL' if p_value < 0.001 else 'OK'
    }
```

**If SRM is detected (p < 0.001)**: STOP the analysis. Report the SRM finding and recommend investigating the randomization mechanism. Common causes:
- Bot filtering applied differently to variants.
- Redirects causing differential drop-off.
- Bucketing bugs in the assignment system.
- Interaction with other concurrent tests.

### 2.2 Minimum Sample Size Check

```python
def required_sample_size(baseline_rate, mde_relative, alpha=0.05, power=0.80, two_sided=True):
    """
    Required sample size per group for a proportion test.

    Parameters:
        baseline_rate: current conversion rate (e.g., 0.05 for 5%)
        mde_relative: minimum detectable effect as relative change (e.g., 0.10 for 10% relative lift)
        alpha: significance level
        power: statistical power
    """
    p1 = baseline_rate
    p2 = baseline_rate * (1 + mde_relative)
    effect_size = abs(p2 - p1) / np.sqrt(p1 * (1 - p1))  # Cohen's h approximation

    if two_sided:
        z_alpha = norm.ppf(1 - alpha / 2)
    else:
        z_alpha = norm.ppf(1 - alpha)
    z_beta = norm.ppf(power)

    n = ((z_alpha * np.sqrt(2 * p1 * (1 - p1)) +
          z_beta * np.sqrt(p1 * (1 - p1) + p2 * (1 - p2)))**2) / (p2 - p1)**2

    return int(np.ceil(n))
```

For continuous metrics (revenue, time on page):

```python
def required_sample_size_continuous(baseline_mean, baseline_std, mde_relative, alpha=0.05, power=0.80):
    mde_absolute = baseline_mean * mde_relative
    z_alpha = norm.ppf(1 - alpha / 2)
    z_beta = norm.ppf(power)
    n = (2 * (z_alpha + z_beta)**2 * baseline_std**2) / mde_absolute**2
    return int(np.ceil(n))
```

Report: required sample size, current sample size, whether the test is adequately powered.

### 2.3 Runtime Check

Estimate the required runtime: required_sample_per_group / (daily_traffic * allocation_fraction).

Flag if:
- Test ran shorter than the estimated required duration.
- Test ran for less than 1 full business cycle (typically 1-2 weeks to capture day-of-week effects).
- Test ran for less than 7 days (almost always too short).

## Step 3: Frequentist Analysis

### 3.1 Proportion Metrics (Conversion Rate, Click-Through Rate)

```python
def proportion_test(successes_control, n_control, successes_treatment, n_treatment, alpha=0.05):
    p_control = successes_control / n_control
    p_treatment = successes_treatment / n_treatment

    # Pooled proportion for test statistic
    p_pooled = (successes_control + successes_treatment) / (n_control + n_treatment)

    # Standard error
    se = np.sqrt(p_pooled * (1 - p_pooled) * (1/n_control + 1/n_treatment))

    # Z-test
    z_stat = (p_treatment - p_control) / se
    p_value = 2 * (1 - norm.cdf(abs(z_stat)))  # two-sided

    # Confidence interval for the difference
    se_diff = np.sqrt(p_control * (1 - p_control) / n_control +
                      p_treatment * (1 - p_treatment) / n_treatment)
    ci_lower = (p_treatment - p_control) - norm.ppf(1 - alpha/2) * se_diff
    ci_upper = (p_treatment - p_control) + norm.ppf(1 - alpha/2) * se_diff

    # Relative lift
    relative_lift = (p_treatment - p_control) / p_control * 100

    return {
        'control_rate': round(p_control, 6),
        'treatment_rate': round(p_treatment, 6),
        'absolute_difference': round(p_treatment - p_control, 6),
        'relative_lift_pct': round(relative_lift, 2),
        'z_statistic': round(z_stat, 4),
        'p_value': round(p_value, 6),
        'ci_lower': round(ci_lower, 6),
        'ci_upper': round(ci_upper, 6),
        'significant': p_value < alpha
    }
```

### 3.2 Continuous Metrics (Revenue Per User, Session Duration)

```python
def continuous_test(values_control, values_treatment, alpha=0.05):
    mean_c = np.mean(values_control)
    mean_t = np.mean(values_treatment)
    std_c = np.std(values_control, ddof=1)
    std_t = np.std(values_treatment, ddof=1)
    n_c = len(values_control)
    n_t = len(values_treatment)

    # Welch's t-test (does not assume equal variances)
    t_stat, p_value = stats.ttest_ind(values_control, values_treatment, equal_var=False)

    # Confidence interval for the difference
    se_diff = np.sqrt(std_c**2 / n_c + std_t**2 / n_t)
    # Welch-Satterthwaite degrees of freedom
    df = (std_c**2/n_c + std_t**2/n_t)**2 / (
        (std_c**2/n_c)**2/(n_c-1) + (std_t**2/n_t)**2/(n_t-1)
    )
    t_crit = stats.t.ppf(1 - alpha/2, df)
    ci_lower = (mean_t - mean_c) - t_crit * se_diff
    ci_upper = (mean_t - mean_c) + t_crit * se_diff

    relative_lift = (mean_t - mean_c) / mean_c * 100 if mean_c != 0 else float('inf')

    return {
        'control_mean': round(mean_c, 4),
        'treatment_mean': round(mean_t, 4),
        'absolute_difference': round(mean_t - mean_c, 4),
        'relative_lift_pct': round(relative_lift, 2),
        't_statistic': round(t_stat, 4),
        'p_value': round(p_value, 6),
        'ci_lower': round(ci_lower, 4),
        'ci_upper': round(ci_upper, 4),
        'significant': p_value < alpha
    }
```

For **highly skewed revenue data**, recommend:
- Log-transform + t-test.
- Mann-Whitney U test (non-parametric).
- Bootstrap confidence intervals (see Step 4).

### 3.3 Rate Metrics with Exposure Denominators (e.g., Revenue Per Session)

Use delta method or ratio metrics approach when the denominator varies per user.

## Step 4: Bayesian Analysis

Provide a Bayesian complement to the frequentist analysis. This is especially useful for business stakeholders who want to know "probability that treatment is better."

```python
def bayesian_proportion_test(successes_c, n_c, successes_t, n_t, n_simulations=100_000, prior_alpha=1, prior_beta=1):
    """
    Bayesian A/B test for proportions using Beta-Binomial model.
    Default: uninformative prior Beta(1,1).
    """
    # Posterior distributions
    posterior_c = np.random.beta(
        prior_alpha + successes_c,
        prior_beta + n_c - successes_c,
        n_simulations
    )
    posterior_t = np.random.beta(
        prior_alpha + successes_t,
        prior_beta + n_t - successes_t,
        n_simulations
    )

    # Probability that treatment > control
    prob_t_better = (posterior_t > posterior_c).mean()

    # Distribution of lift
    lift = (posterior_t - posterior_c) / posterior_c * 100
    expected_lift = np.mean(lift)
    ci_lift = np.percentile(lift, [2.5, 97.5])

    # Expected loss: if we choose treatment but control is better, how much do we lose?
    loss_choosing_t = np.maximum(posterior_c - posterior_t, 0).mean()
    loss_choosing_c = np.maximum(posterior_t - posterior_c, 0).mean()

    return {
        'prob_treatment_better': round(prob_t_better, 4),
        'expected_relative_lift_pct': round(expected_lift, 2),
        'ci_95_lift_pct': [round(ci_lift[0], 2), round(ci_lift[1], 2)],
        'expected_loss_choosing_treatment': round(loss_choosing_t, 6),
        'expected_loss_choosing_control': round(loss_choosing_c, 6),
    }
```

## Step 5: Diagnostic Checks

### 5.1 Novelty / Primacy Effect

Compare the treatment effect in the first week vs subsequent weeks:

```python
def check_novelty_effect(df, variant_col, metric_col, date_col, test_start_date):
    df['days_since_start'] = (df[date_col] - test_start_date).dt.days
    df['period'] = pd.cut(df['days_since_start'], bins=[0, 7, 14, 999], labels=['week1', 'week2', 'week3+'])

    results = {}
    for period in ['week1', 'week2', 'week3+']:
        subset = df[df['period'] == period]
        control = subset[subset[variant_col] == 'control'][metric_col]
        treatment = subset[subset[variant_col] == 'treatment'][metric_col]
        if len(control) > 0 and len(treatment) > 0:
            lift = (treatment.mean() - control.mean()) / control.mean() * 100
            results[period] = round(lift, 2)
    return results
```

If the effect is significantly larger in week 1 than later weeks, flag a **novelty effect** (users respond to the change itself, not the improvement). If the effect grows over time, it may be a **learning effect** (positive) or **primacy effect**.

### 5.2 Segment Analysis

Break down results by key segments to check for heterogeneous treatment effects:

- **Platform**: mobile vs desktop vs tablet
- **New vs returning users**
- **Geographic region**
- **Traffic source**
- **Power users vs casual users**

```python
def segment_analysis(df, variant_col, metric_col, segment_col, alpha=0.05):
    segments = df[segment_col].unique()
    results = []
    for seg in segments:
        subset = df[df[segment_col] == seg]
        control = subset[subset[variant_col] == 'control'][metric_col]
        treatment = subset[subset[variant_col] == 'treatment'][metric_col]
        if len(control) >= 30 and len(treatment) >= 30:
            t_stat, p_val = stats.ttest_ind(control, treatment, equal_var=False)
            lift = (treatment.mean() - control.mean()) / control.mean() * 100
            results.append({
                'segment': seg,
                'n_control': len(control),
                'n_treatment': len(treatment),
                'lift_pct': round(lift, 2),
                'p_value': round(p_val, 4),
                'significant': p_val < alpha
            })
    return pd.DataFrame(results)
```

**WARNING**: segment analyses are exploratory and subject to multiple comparisons. Apply Bonferroni correction: adjusted alpha = alpha / number_of_segments. State this clearly.

### 5.3 Multiple Comparisons Correction

If the test has multiple variants (A/B/C/n) or multiple primary metrics:

```python
def bonferroni_correction(p_values, alpha=0.05):
    n_tests = len(p_values)
    adjusted_alpha = alpha / n_tests
    return {
        'original_alpha': alpha,
        'adjusted_alpha': round(adjusted_alpha, 6),
        'n_comparisons': n_tests,
        'results': [
            {'p_value': p, 'significant_after_correction': p < adjusted_alpha}
            for p in p_values
        ]
    }
```

Also offer Benjamini-Hochberg (FDR) as a less conservative alternative:

```python
def benjamini_hochberg(p_values, alpha=0.05):
    n = len(p_values)
    sorted_indices = np.argsort(p_values)
    sorted_p = np.array(p_values)[sorted_indices]
    thresholds = [(i + 1) / n * alpha for i in range(n)]
    significant = sorted_p <= thresholds
    # Find the largest k where p(k) <= k/n * alpha
    if significant.any():
        max_k = np.max(np.where(significant))
        significant[:max_k + 1] = True
    results = np.zeros(n, dtype=bool)
    results[sorted_indices] = significant
    return results.tolist()
```

### 5.4 Guardrail Metric Check

For each guardrail metric, run the same statistical test but check that the treatment does NOT cause a statistically significant degradation:

```
GUARDRAIL CHECK:
| Metric        | Control | Treatment | Change | p-value | Status  |
|--------------|---------|-----------|--------|---------|---------|
| Page Load (ms)| 1,234  | 1,256     | +1.8%  | 0.34    | PASSED  |
| Error Rate    | 0.12%  | 0.45%     | +275%  | 0.001   | FAILED  |
```

If any guardrail fails, flag it as a blocker regardless of primary metric results.

### 5.5 Sequential Testing / Peeking Correction

If the user has been checking results repeatedly during the test (peeking), the effective false positive rate is inflated. Note this risk and suggest:
- Using a sequential testing framework (e.g., mSPRT, always-valid confidence intervals).
- Applying a peeking correction factor.
- Pre-committing to a fixed end date and not peeking.

## Step 6: Visualization

```python
def plot_ab_results(control_rate, treatment_rate, ci_lower, ci_upper, metric_name):
    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(['Control', 'Treatment'], [control_rate, treatment_rate],
                  color=['#4A90D9', '#E8644A'], alpha=0.8, width=0.5)
    # Error bar on treatment showing CI of difference mapped to treatment rate
    ax.errorbar('Treatment', treatment_rate,
                yerr=[[treatment_rate - (control_rate + ci_lower)],
                      [(control_rate + ci_upper) - treatment_rate]],
                fmt='none', color='black', capsize=8, linewidth=2)
    ax.set_ylabel(metric_name)
    ax.set_title(f'A/B Test Results: {metric_name}')
    for bar, val in zip(bars, [control_rate, treatment_rate]):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.001,
                f'{val:.2%}', ha='center', va='bottom', fontweight='bold')
    plt.tight_layout()
    plt.savefig(f'ab_test_{metric_name.lower().replace(" ", "_")}.png', dpi=150, bbox_inches='tight')
    plt.close()
```

Also generate a **time series plot** of the metric for control vs treatment over the test duration to visually inspect for novelty effects and convergence.

## Step 7: Decision Recommendation

Produce a clear recommendation using this framework:

```
DECISION RECOMMENDATION
========================
Primary Metric:     [metric name]
Result:             [SIGNIFICANT POSITIVE / SIGNIFICANT NEGATIVE / NOT SIGNIFICANT]
Confidence Level:   [1 - p_value as percentage]
Bayesian Prob:      [probability treatment is better]
Practical Significance: [YES: lift exceeds MDE / NO: lift is below MDE even if statistically significant]

Recommendation:     [SHIP / DO NOT SHIP / EXTEND TEST / INVESTIGATE]

Rationale:
- [reason 1]
- [reason 2]
- [reason 3]

Risks:
- [risk 1 if shipped]
- [risk 2]

Suggested Follow-ups:
- [follow-up 1]
- [follow-up 2]
```

### Decision Matrix

| Statistical Sig | Practical Sig | Guardrails | Recommendation |
|-----------------|--------------|------------|----------------|
| Yes             | Yes          | Pass       | **SHIP** |
| Yes             | Yes          | Fail       | **DO NOT SHIP** -- investigate guardrail failure |
| Yes             | No           | Pass       | **SHIP WITH CAUTION** -- effect is real but small |
| No              | N/A          | Pass       | **EXTEND** if underpowered, **DO NOT SHIP** if adequately powered |
| No              | N/A          | Fail       | **DO NOT SHIP** |
| Yes (negative)  | Yes          | N/A        | **DO NOT SHIP** -- treatment is harmful |

## Output Format

Structure the full analysis as:

```
## Test Configuration
[Step 1]

## Pre-Analysis Validation
### Sample Ratio Mismatch: [PASSED / FAILED]
### Sample Size Adequacy: [ADEQUATE / UNDERPOWERED]
### Runtime Check: [SUFFICIENT / INSUFFICIENT]

## Results
### Primary Metric: [metric name]
[Frequentist results table]
[Bayesian results]

### Secondary Metrics
[Results table for each]

### Guardrail Metrics
[Results table]

## Diagnostics
### Novelty/Primacy Effect: [DETECTED / NOT DETECTED]
### Segment Breakdown: [summary table]
### Multiple Comparisons: [adjustment applied if needed]

## Visualization
[Charts saved as PNG files]

## Recommendation
[Step 7 output]
```

## Edge Cases

- **Very low conversion rates** (< 0.1%): sample sizes will be enormous. Suggest running longer or increasing traffic allocation. Consider using a more sensitive metric as a proxy.
- **Heavy-tailed revenue data**: recommend capping at the 99th percentile (Winsorization) or using log-transform. Report both raw and transformed results.
- **Multi-variant tests (A/B/C/n)**: always apply multiple comparison corrections. Compare each treatment to control, not treatments to each other (unless explicitly requested).
- **Crossover contamination**: if users can switch between variants (e.g., logged-out bucketing by cookie), flag the risk of diluted effects.
- **Small sample size** (< 100 per group): frequentist tests have poor coverage. Rely more heavily on Bayesian analysis and recommend extending the test.
- **Test stopped early**: if the test was stopped before reaching the planned sample size, note that p-values may be anti-conservative due to optional stopping. Apply sequential testing corrections.
- **Non-independent observations**: if the metric involves repeated measurements per user (e.g., sessions per user), the standard tests assume independence. Recommend aggregating to the user level first (e.g., conversion rate per user, average revenue per user).
