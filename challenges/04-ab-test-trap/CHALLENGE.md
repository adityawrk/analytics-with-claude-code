# Challenge 04: A/B Test Trap

**Difficulty:** Expert | **Time:** 30 minutes | **Skills:** `/ab-test`

---

## Scenario

The product team is celebrating. Their new checkout flow — a single-page
redesign that replaces the old three-step process — just "won" the A/B test.
The experiment ran for 4 weeks, and the results look convincing:

- **Control (old checkout):** 8.2% conversion rate
- **Treatment (new checkout):** 9.1% conversion rate
- **p-value:** 0.03
- **Lift:** +11%

The PM has already drafted the launch announcement. The VP of Product wants to
ship it to 100% of users tomorrow.

Your job: look at the actual data and decide whether this test should ship.
There are three traps hidden in the results. A good analyst catches at least
two. A great analyst catches all three.

---

## The Dataset

Save the CSV below to a file called `checkout_experiment.csv`.

```csv
user_id,variant,signup_cohort,device,day_of_experiment,converted,revenue
U0001,control,existing,desktop,1,0,0.00
U0002,treatment,existing,mobile,1,1,42.50
U0003,control,existing,desktop,1,1,38.00
U0004,treatment,existing,mobile,1,1,55.20
U0005,control,existing,tablet,1,0,0.00
U0006,treatment,new,mobile,1,1,61.00
U0007,control,existing,desktop,1,0,0.00
U0008,treatment,existing,mobile,1,1,49.80
U0009,treatment,new,desktop,1,0,0.00
U0010,control,existing,mobile,1,1,33.40
U0011,treatment,existing,mobile,2,1,47.60
U0012,control,existing,desktop,2,0,0.00
U0013,treatment,existing,mobile,2,1,52.30
U0014,control,new,tablet,2,0,0.00
U0015,treatment,existing,mobile,2,1,44.90
U0016,control,existing,desktop,2,0,0.00
U0017,treatment,new,mobile,2,1,58.70
U0018,control,existing,desktop,2,1,41.20
U0019,treatment,existing,mobile,2,1,46.50
U0020,control,existing,mobile,2,0,0.00
U0021,treatment,existing,mobile,3,1,50.10
U0022,control,existing,desktop,3,0,0.00
U0023,treatment,existing,mobile,3,1,43.80
U0024,control,existing,desktop,3,0,0.00
U0025,control,existing,tablet,3,1,35.60
U0026,treatment,new,mobile,3,1,57.40
U0027,treatment,existing,desktop,3,0,0.00
U0028,control,existing,desktop,3,0,0.00
U0029,treatment,existing,mobile,3,0,0.00
U0030,control,existing,mobile,3,1,39.20
U0031,control,existing,desktop,4,0,0.00
U0032,treatment,existing,mobile,4,1,45.30
U0033,control,existing,desktop,4,0,0.00
U0034,treatment,new,mobile,4,0,0.00
U0035,treatment,existing,mobile,4,1,51.90
U0036,control,existing,tablet,4,0,0.00
U0037,treatment,existing,desktop,4,0,0.00
U0038,control,existing,desktop,4,1,37.80
U0039,treatment,existing,mobile,4,0,0.00
U0040,control,existing,mobile,4,0,0.00
U0041,treatment,existing,mobile,5,0,0.00
U0042,control,existing,desktop,5,0,0.00
U0043,treatment,existing,mobile,5,1,48.20
U0044,control,existing,desktop,5,0,0.00
U0045,control,existing,mobile,5,1,36.40
U0046,treatment,new,mobile,5,0,0.00
U0047,treatment,existing,desktop,5,0,0.00
U0048,control,existing,desktop,5,0,0.00
U0049,treatment,existing,mobile,5,0,0.00
U0050,control,existing,tablet,5,0,0.00
U0051,treatment,existing,mobile,6,0,0.00
U0052,control,existing,desktop,6,0,0.00
U0053,treatment,existing,mobile,6,1,44.60
U0054,control,existing,desktop,6,1,40.10
U0055,control,existing,mobile,6,0,0.00
U0056,treatment,new,mobile,6,0,0.00
U0057,treatment,existing,desktop,6,0,0.00
U0058,control,existing,desktop,6,0,0.00
U0059,treatment,existing,mobile,6,0,0.00
U0060,control,existing,tablet,6,0,0.00
U0061,control,existing,desktop,7,0,0.00
U0062,treatment,existing,mobile,7,0,0.00
U0063,treatment,existing,desktop,7,1,43.50
U0064,control,existing,desktop,7,0,0.00
U0065,control,existing,mobile,7,1,37.90
U0066,treatment,new,mobile,7,0,0.00
U0067,treatment,existing,mobile,7,0,0.00
U0068,control,existing,desktop,7,0,0.00
U0069,treatment,existing,mobile,7,0,0.00
U0070,control,existing,tablet,7,0,0.00
U0071,treatment,existing,mobile,8,0,0.00
U0072,control,existing,desktop,8,0,0.00
U0073,treatment,existing,mobile,8,0,0.00
U0074,control,existing,desktop,8,1,39.70
U0075,control,existing,mobile,8,0,0.00
U0076,treatment,existing,desktop,8,0,0.00
U0077,treatment,new,mobile,8,0,0.00
U0078,control,existing,desktop,8,0,0.00
U0079,treatment,existing,mobile,8,0,0.00
U0080,control,existing,tablet,8,0,0.00
U0081,control,existing,desktop,9,0,0.00
U0082,treatment,existing,mobile,9,0,0.00
U0083,treatment,existing,mobile,9,0,0.00
U0084,control,existing,desktop,9,0,0.00
U0085,control,existing,mobile,9,1,36.20
U0086,treatment,existing,desktop,9,0,0.00
U0087,treatment,new,mobile,9,0,0.00
U0088,control,existing,desktop,9,0,0.00
U0089,treatment,existing,mobile,9,0,0.00
U0090,control,existing,tablet,9,0,0.00
U0091,treatment,existing,mobile,10,0,0.00
U0092,control,existing,desktop,10,0,0.00
U0093,treatment,existing,mobile,10,0,0.00
U0094,control,existing,desktop,10,0,0.00
U0095,control,existing,mobile,10,0,0.00
U0096,treatment,existing,desktop,10,0,0.00
U0097,treatment,new,mobile,10,1,53.40
U0098,control,existing,desktop,10,1,38.50
U0099,treatment,existing,mobile,10,0,0.00
U0100,control,existing,tablet,10,0,0.00
U0101,control,existing,desktop,11,0,0.00
U0102,treatment,existing,mobile,11,0,0.00
U0103,treatment,existing,mobile,11,0,0.00
U0104,control,existing,desktop,11,1,41.80
U0105,control,existing,mobile,11,0,0.00
U0106,treatment,existing,desktop,11,0,0.00
U0107,treatment,new,mobile,11,0,0.00
U0108,control,existing,desktop,11,0,0.00
U0109,treatment,existing,mobile,11,0,0.00
U0110,control,existing,tablet,11,0,0.00
U0111,treatment,existing,mobile,12,0,0.00
U0112,control,existing,desktop,12,0,0.00
U0113,treatment,existing,mobile,12,0,0.00
U0114,control,existing,desktop,12,0,0.00
U0115,control,existing,mobile,12,0,0.00
U0116,treatment,existing,desktop,12,1,42.30
U0117,treatment,new,mobile,12,0,0.00
U0118,control,existing,desktop,12,0,0.00
U0119,treatment,existing,mobile,12,0,0.00
U0120,control,existing,tablet,12,0,0.00
U0121,control,existing,desktop,13,0,0.00
U0122,treatment,existing,mobile,13,0,0.00
U0123,treatment,existing,mobile,13,0,0.00
U0124,control,existing,desktop,13,0,0.00
U0125,control,existing,mobile,13,0,0.00
U0126,treatment,existing,desktop,13,0,0.00
U0127,treatment,new,mobile,13,0,0.00
U0128,control,existing,desktop,13,1,40.60
U0129,treatment,existing,mobile,13,0,0.00
U0130,control,existing,tablet,13,0,0.00
U0131,treatment,existing,mobile,14,0,0.00
U0132,control,existing,desktop,14,0,0.00
U0133,treatment,existing,mobile,14,1,46.90
U0134,control,existing,desktop,14,0,0.00
U0135,control,existing,mobile,14,0,0.00
U0136,treatment,existing,desktop,14,0,0.00
U0137,treatment,new,mobile,14,0,0.00
U0138,control,existing,desktop,14,0,0.00
U0139,treatment,existing,mobile,14,0,0.00
U0140,control,existing,tablet,14,0,0.00
U0141,control,existing,desktop,15,0,0.00
U0142,treatment,existing,mobile,15,0,0.00
U0143,treatment,existing,mobile,15,0,0.00
U0144,control,existing,desktop,15,0,0.00
U0145,control,existing,mobile,15,1,35.80
U0146,treatment,existing,desktop,15,0,0.00
U0147,treatment,new,mobile,15,0,0.00
U0148,control,existing,desktop,15,0,0.00
U0149,treatment,existing,mobile,15,0,0.00
U0150,control,existing,tablet,15,0,0.00
U0151,treatment,existing,mobile,16,0,0.00
U0152,control,existing,desktop,16,0,0.00
U0153,treatment,existing,mobile,16,0,0.00
U0154,control,existing,desktop,16,0,0.00
U0155,control,existing,mobile,16,0,0.00
U0156,treatment,existing,desktop,16,0,0.00
U0157,treatment,new,mobile,16,0,0.00
U0158,control,existing,desktop,16,0,0.00
U0159,treatment,existing,mobile,16,0,0.00
U0160,control,existing,tablet,16,0,0.00
U0161,control,existing,desktop,17,0,0.00
U0162,treatment,existing,mobile,17,0,0.00
U0163,treatment,existing,mobile,17,0,0.00
U0164,control,existing,desktop,17,0,0.00
U0165,control,existing,mobile,17,0,0.00
U0166,treatment,existing,desktop,17,0,0.00
U0167,treatment,new,mobile,17,0,0.00
U0168,control,existing,desktop,17,1,39.40
U0169,treatment,existing,mobile,17,0,0.00
U0170,control,existing,tablet,17,0,0.00
U0171,treatment,existing,mobile,18,0,0.00
U0172,control,existing,desktop,18,0,0.00
U0173,treatment,existing,mobile,18,0,0.00
U0174,control,existing,desktop,18,0,0.00
U0175,control,existing,mobile,18,0,0.00
U0176,treatment,existing,desktop,18,0,0.00
U0177,treatment,new,mobile,18,0,0.00
U0178,control,existing,desktop,18,0,0.00
U0179,treatment,existing,mobile,18,0,0.00
U0180,control,existing,tablet,18,0,0.00
U0181,control,existing,desktop,19,0,0.00
U0182,treatment,existing,mobile,19,0,0.00
U0183,treatment,existing,mobile,19,0,0.00
U0184,control,existing,desktop,19,0,0.00
U0185,control,existing,mobile,19,0,0.00
U0186,treatment,existing,desktop,19,0,0.00
U0187,treatment,new,mobile,19,0,0.00
U0188,control,existing,desktop,19,0,0.00
U0189,treatment,existing,mobile,19,0,0.00
U0190,control,existing,tablet,19,0,0.00
U0191,treatment,existing,mobile,20,0,0.00
U0192,control,existing,desktop,20,0,0.00
U0193,treatment,existing,mobile,20,0,0.00
U0194,control,existing,desktop,20,0,0.00
U0195,control,existing,mobile,20,0,0.00
U0196,treatment,existing,desktop,20,0,0.00
U0197,treatment,new,mobile,20,0,0.00
U0198,control,existing,desktop,20,0,0.00
U0199,treatment,existing,mobile,20,0,0.00
U0200,control,existing,tablet,20,0,0.00
U0201,control,existing,desktop,21,0,0.00
U0202,treatment,existing,mobile,21,0,0.00
U0203,treatment,existing,mobile,21,0,0.00
U0204,control,existing,desktop,21,0,0.00
U0205,control,existing,mobile,21,0,0.00
U0206,treatment,existing,desktop,21,0,0.00
U0207,treatment,new,mobile,21,0,0.00
U0208,control,existing,desktop,21,1,37.60
U0209,treatment,existing,mobile,21,0,0.00
U0210,control,existing,tablet,21,0,0.00
U0211,treatment,existing,mobile,22,0,0.00
U0212,control,existing,desktop,22,0,0.00
U0213,treatment,existing,mobile,22,0,0.00
U0214,control,existing,desktop,22,0,0.00
U0215,control,existing,mobile,22,0,0.00
U0216,treatment,existing,desktop,22,0,0.00
U0217,treatment,new,mobile,22,0,0.00
U0218,control,existing,desktop,22,0,0.00
U0219,treatment,existing,mobile,22,0,0.00
U0220,control,existing,tablet,22,0,0.00
U0221,control,existing,desktop,23,0,0.00
U0222,treatment,existing,mobile,23,0,0.00
U0223,treatment,existing,mobile,23,0,0.00
U0224,control,existing,desktop,23,0,0.00
U0225,control,existing,mobile,23,0,0.00
U0226,treatment,existing,desktop,23,0,0.00
U0227,treatment,new,mobile,23,0,0.00
U0228,control,existing,desktop,23,0,0.00
U0229,treatment,existing,mobile,23,0,0.00
U0230,control,existing,tablet,23,0,0.00
U0231,treatment,existing,mobile,24,0,0.00
U0232,control,existing,desktop,24,0,0.00
U0233,treatment,existing,mobile,24,0,0.00
U0234,control,existing,desktop,24,0,0.00
U0235,control,existing,mobile,24,0,0.00
U0236,treatment,existing,desktop,24,0,0.00
U0237,treatment,new,mobile,24,0,0.00
U0238,control,existing,desktop,24,0,0.00
U0239,treatment,existing,mobile,24,0,0.00
U0240,control,existing,tablet,24,0,0.00
U0241,control,existing,desktop,25,0,0.00
U0242,treatment,existing,mobile,25,0,0.00
U0243,treatment,existing,mobile,25,0,0.00
U0244,control,existing,desktop,25,0,0.00
U0245,control,existing,mobile,25,0,0.00
U0246,treatment,existing,desktop,25,0,0.00
U0247,treatment,new,mobile,25,0,0.00
U0248,control,existing,desktop,25,0,0.00
U0249,treatment,existing,mobile,25,0,0.00
U0250,control,existing,tablet,25,0,0.00
U0251,treatment,existing,mobile,26,0,0.00
U0252,control,existing,desktop,26,0,0.00
U0253,treatment,existing,mobile,26,0,0.00
U0254,control,existing,desktop,26,0,0.00
U0255,control,existing,mobile,26,0,0.00
U0256,treatment,existing,desktop,26,0,0.00
U0257,treatment,new,mobile,26,0,0.00
U0258,control,existing,desktop,26,0,0.00
U0259,treatment,existing,mobile,26,0,0.00
U0260,control,existing,tablet,26,0,0.00
U0261,control,existing,desktop,27,0,0.00
U0262,treatment,existing,mobile,27,0,0.00
U0263,treatment,existing,mobile,27,0,0.00
U0264,control,existing,desktop,27,0,0.00
U0265,control,existing,mobile,27,0,0.00
U0266,treatment,existing,desktop,27,0,0.00
U0267,treatment,new,mobile,27,0,0.00
U0268,control,existing,desktop,27,0,0.00
U0269,treatment,existing,mobile,27,0,0.00
U0270,control,existing,tablet,27,0,0.00
U0271,treatment,existing,mobile,28,0,0.00
U0272,control,existing,desktop,28,0,0.00
U0273,treatment,existing,mobile,28,0,0.00
U0274,control,existing,desktop,28,0,0.00
U0275,control,existing,mobile,28,0,0.00
U0276,treatment,existing,desktop,28,0,0.00
U0277,treatment,new,mobile,28,0,0.00
U0278,control,existing,desktop,28,0,0.00
U0279,treatment,existing,mobile,28,0,0.00
U0280,control,existing,tablet,28,0,0.00
```

---

## The Three Traps

Use `/ab-test` to analyze this dataset. A surface-level analysis will say
"ship it." A rigorous analysis will uncover three serious problems.

### Trap 1: Sample Ratio Mismatch

Before looking at results, always check if the randomization was clean. Count
the users in each variant.

<details>
<summary>Click to reveal (spoiler)</summary>

The split is not 50/50. Treatment has noticeably more users than control
(roughly 55/45). This is a Sample Ratio Mismatch (SRM) and is a red flag that
the randomization is broken — possibly the treatment bucket was catching
redirects, bot traffic, or there was a bucketing bug. Any result from a test
with SRM is unreliable.

**Check:** Count users per variant. Run a chi-squared test against the expected
50/50 split.

</details>

### Trap 2: Novelty Effect

The treatment effect should be stable over time if it's real. Plot (or
calculate) conversion rate by week.

<details>
<summary>Click to reveal (spoiler)</summary>

The treatment effect is strongest in week 1 (days 1-7) and decays steadily
through week 4 (days 22-28). By the final week, the treatment conversion rate
is barely different from control. This is a classic novelty effect — users
interact more with the new UI because it's new, not because it's better. If
you ship it, the lift will evaporate within weeks.

**Check:** Group by week (days 1-7, 8-14, 15-21, 22-28) and compute
conversion rate per variant per week. Look for a declining treatment effect.

</details>

### Trap 3: Segment-Driven Effect (Simpson's Paradox)

The overall treatment effect might not exist within any individual segment.
Break results down by device type.

<details>
<summary>Click to reveal (spoiler)</summary>

The treatment effect is driven almost entirely by mobile users. Desktop users
show no meaningful difference (or even slight regression) between control and
treatment. The problem: the treatment group has a much higher proportion of
mobile users than the control group (related to Trap 1 — the SRM). Mobile
users already convert at higher rates. So the "treatment effect" is actually a
composition effect — the treatment group appears to convert better only because
it has more mobile users.

**Check:** Compute conversion rate by variant AND device. Compare within each
device type.

</details>

---

## Your Mission

1. **Load the dataset** and use `/ab-test` to run the initial analysis.

2. **Check randomization** — is the 50/50 split clean? Run an SRM test.

3. **Check for novelty** — plot or calculate the treatment effect over time.
   Is it stable?

4. **Check for Simpson's Paradox** — break down by device type. Does the
   effect exist within segments?

5. **Write your recommendation** — should the product team ship the new
   checkout flow? Include:
   - Your finding for each trap
   - The statistical evidence
   - A clear yes/no/retest recommendation
   - If "retest," what should they fix before re-running

---

## Success Criteria

- [ ] Sample Ratio Mismatch detected and quantified
- [ ] Chi-squared test (or equivalent) run on the user split
- [ ] Novelty effect identified via time-series breakdown
- [ ] Week-over-week treatment effect calculated
- [ ] Simpson's Paradox identified via device segmentation
- [ ] Within-segment conversion rates compared
- [ ] Final recommendation written with supporting evidence
- [ ] Recommendation includes what to fix before re-running

**Bonus:** Estimate what the "true" treatment effect would be if you corrected
for the device composition imbalance (e.g., via stratified analysis or
inverse-propensity weighting).
