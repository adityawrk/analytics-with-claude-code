---
name: systematic-debug
description: >
  4-phase structured debugging with a 3-strike escalation rule. Use when a query fails,
  a pipeline breaks, results look wrong, a dbt model errors, or any analytical code
  produces unexpected output. Prevents cargo-cult debugging by enforcing reproduce →
  analyze → fix → verify in strict order.
---

# Systematic Debugging for Analytics

A 4-phase structured debugging methodology. Follow these phases in strict order.
No shortcuts. No cargo-cult debugging. No "just try this and see."

---

## Ground Rules

Read these first. They are non-negotiable.

1. **NEVER skip Phase 1.** Do not attempt a fix before reproducing the error and
   reading the full output. No exceptions.
2. **NEVER make multiple changes at once.** One variable at a time. If you change
   two things and the problem goes away, you do not know which one fixed it.
3. **3-Strike Rule.** After 3 failed fix attempts, STOP. Summarize what you have
   tried, what you have learned, and escalate to the user. Do not keep guessing.
4. **State your hypothesis.** Before every fix attempt, tell the user what you
   believe is wrong and why. "I think X because Y, so I will try Z."
5. **Clean up after yourself.** Remove all debug instrumentation (extra logging,
   LIMIT clauses, temp tables, print statements) before declaring the issue resolved.

---

## Phase 1: Reproduce and Gather Evidence

**Goal:** See the failure with your own eyes. Understand exactly what is happening
before forming any opinion about why.

### Steps

1. **Run the failing query or script exactly as reported.**
   - Use the same database, schema, and role if possible.
   - Do not modify the query before running it.
   - Capture the full error output — not just the first line.

2. **Read the complete error message.**
   - Copy the full stack trace or error output.
   - Identify the specific line, column, or object that failed.
   - Note the error code if one is provided.

3. **Check the environment.**
   - What database/warehouse is this running against?
   - What schema or dataset is active?
   - Are there any session-level settings (timezone, role, warehouse size)?

4. **Check data freshness.** *(Analytics-specific)*
   - When was the source data last updated?
   - Is the failure caused by stale or missing data rather than a code bug?
   - Run `SELECT MAX(updated_at)` or equivalent on key source tables.

5. **Check recent changes.**
   - `git log --oneline -10` on relevant files.
   - `git diff HEAD~3 -- <failing_file>` to see recent modifications.
   - Were any upstream models or sources changed recently?

6. **Record your findings.** Write a brief summary:
   - What is the exact error?
   - When did it start?
   - What is the scope (one model, one query, everything)?

**Do NOT proceed to Phase 2 until you can reliably reproduce the failure.**

---

## Phase 2: Analyze and Hypothesize

**Goal:** Understand the root cause. Narrow down from "something is broken" to
"this specific thing is wrong because of this specific reason."

### Steps

1. **Trace data lineage.**
   - If this is a dbt model, trace upstream with `ref()` and `source()`.
   - Identify which input tables feed into the failing query.
   - Check whether upstream models built successfully.

2. **Find a working example.**
   - Was this query working before? When? What changed?
   - Is there a similar query or model that still works?
   - Compare the working version to the failing version line by line.

3. **Check for common analytics gotchas.** *(Analytics-specific)*
   - **NULL aggregation:** Is `SUM()` or `COUNT()` silently dropping NULLs?
   - **Fan-out joins:** Is a JOIN producing more rows than expected? Check
     `COUNT(*)` before and after the JOIN.
   - **Timezone mismatches:** Are timestamps being compared across different
     timezones? Is `created_at` in UTC but filtered with local time?
   - **Integer division:** Is `revenue / quantity` doing integer division
     instead of decimal?
   - **Implicit casting:** Is a string being compared to a number?
   - **Schema drift:** Did a column get renamed, removed, or change type upstream?
   - **Duplicate keys:** Is the assumed primary key actually unique?

4. **Form a specific hypothesis.**
   - Write it down: "The query fails because [X] causes [Y]."
   - The hypothesis must be testable with a single change.
   - If you cannot form a hypothesis, you need more evidence — go back to Phase 1.

5. **State your hypothesis to the user before proceeding.**

---

## Phase 3: Test and Fix

**Goal:** Validate your hypothesis with a minimal, targeted change.

### Steps

1. **Make the smallest possible change.**
   - Change one thing. Run the query. Observe the result.
   - If you need to test a theory, use a `SELECT` statement or CTE — do not
     modify the production model until you have confirmed the fix.

2. **Validate the fix.**
   - Does the query run without error?
   - Does it return the expected number of rows?
   - Do the values look reasonable? Spot-check key metrics.

3. **Track your attempts.**
   - Attempt 1: Hypothesis — [X]. Change — [Y]. Result — [Z].
   - Attempt 2: Hypothesis — [X]. Change — [Y]. Result — [Z].
   - Attempt 3: Hypothesis — [X]. Change — [Y]. Result — [Z].

4. **3-Strike Escalation.** If three attempts have failed:
   - STOP. Do not try a fourth fix.
   - Summarize all three attempts and their results.
   - Present your findings to the user.
   - Ask for additional context or suggest pairing with someone who has
     domain knowledge of this part of the data.
   - Only continue after the user provides new direction.

---

## Phase 4: Verify and Clean Up

**Goal:** Confirm the fix is complete, correct, and leaves no mess behind.

### Steps

1. **Confirm the fix resolves the original error.**
   - Re-run the exact command from Phase 1 Step 1.
   - The error must be gone — not just different.

2. **Check for regressions.**
   - Run downstream models or queries that depend on the fixed model.
   - If dbt is available, run `dbt test` on the affected models.
   - Verify that fixing this did not break something else.

3. **Validate row counts and metrics.** *(Analytics-specific)*
   - Compare row counts to a known baseline or previous run.
   - Spot-check 2-3 key metrics against expected values.
   - If the fix changed output values, confirm the new values are correct
     rather than just "not erroring."

4. **Remove all debug instrumentation.**
   - Delete any temporary tables you created.
   - Remove added `LIMIT` clauses, `WHERE 1=0` filters, or debug `SELECT`s.
   - Revert any `print()` or logging statements added for debugging.
   - Confirm the final code is clean and production-ready.

5. **Write a summary.** Provide the user with:
   - **Root cause:** One sentence explaining what was wrong.
   - **Fix:** One sentence explaining what you changed.
   - **Verification:** Confirmation that the fix works and regressions were checked.
   - **Prevention:** If applicable, suggest a test or check that would catch
     this issue earlier in the future (e.g., a dbt test, a CI check, a
     data quality assertion).

---

## Quick Reference Card

```
Phase 1: REPRODUCE    — Run it. Read the error. Check the data. Check recent changes.
Phase 2: ANALYZE      — Trace lineage. Find working examples. Check gotchas. Hypothesize.
Phase 3: FIX          — One change at a time. Three strikes and escalate.
Phase 4: VERIFY       — Re-run original. Check regressions. Validate metrics. Clean up.
```

**Remember:**
- Reproduce before you hypothesize.
- Hypothesize before you fix.
- Fix one thing at a time.
- Three strikes means stop and ask for help.
- Clean up before you declare victory.
