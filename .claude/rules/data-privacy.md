---
description: Data privacy rules for handling sensitive and personally identifiable information
---

# Data Privacy Rules

These rules apply to all code, queries, outputs, and artifacts produced in this project. Violations of these rules can create legal, regulatory, and reputational risk.

## Never log or display PII

Personally Identifiable Information (PII) must never appear in:
- Query results displayed in the terminal or notebooks
- Log files or debug output
- Error messages or exception traces
- Comments, documentation, or pull request descriptions
- Sample data in tests or seed files

PII includes but is not limited to:
- Email addresses
- Phone numbers
- Social Security Numbers (SSN) or government IDs
- IP addresses
- Physical addresses (street-level or more specific)
- Full names combined with other identifying attributes
- Financial account numbers (credit card, bank account)
- Dates of birth (when combined with other fields)

When you need to show example output, replace PII with obviously fake placeholder values:
```sql
-- Good
-- user_email: 'user_XXXX@example.com'

-- Bad
-- user_email: 'jane.doe@realcompany.com'
```

## Minimum group size for anonymity

When producing aggregated outputs (reports, dashboards, ad-hoc analysis), never display metrics for groups with fewer than 5 individuals. This prevents re-identification of individuals in small cohorts.

```sql
-- Always apply a minimum group size filter
having count(distinct user_id) >= 5
```

If a business stakeholder requests data that would violate this threshold, explain the privacy constraint and offer alternatives:
- Roll up to a coarser granularity (e.g., weekly instead of daily, region instead of city).
- Combine small groups into an "Other" bucket.
- Report only the aggregate total without the breakdown.

## Pseudonymization with hashing

When joining datasets on PII (e.g., matching users across systems by email), use a one-way hash for pseudonymization rather than passing raw PII through the pipeline.

```sql
-- Use a consistent hashing approach
select
    md5(lower(trim(email))) as hashed_email,
    ...
from raw.users
```

Rules for hashing:
- Normalize before hashing: `lower(trim(value))`.
- Use a consistent hash function across all systems (document which one).
- Never store both the hash and the raw value in the same table.
- Remember that hashing is pseudonymization, not anonymization. Hashed PII is still considered personal data under GDPR.

## Flag PII-containing tables

Any table, view, or model that contains raw PII columns must be:
1. Documented with a `pii: true` meta tag in dbt YAML.
2. Restricted via access controls (e.g., dbt groups, database GRANT/REVOKE).
3. Located in a clearly marked schema (e.g., `pii_raw`, `restricted`).

```yaml
models:
  - name: stg_users
    description: Staging model for user data. Contains PII.
    meta:
      pii: true
      pii_columns: [email, phone_number, full_name, ip_address]
      data_owner: identity-team
    columns:
      - name: email
        description: "User email address. PII - do not expose in reporting."
```

When writing queries or building models that reference PII tables:
- Select only the columns you actually need.
- Hash or drop PII columns as early as possible in the DAG.
- Never propagate raw PII into mart or reporting layers.

## Redact real user data from examples

When writing documentation, tests, seed files, or example queries:
- Never copy-paste real data from production.
- Use synthetic/fake data generators or obviously fictional values.
- If you must reference a real data shape, anonymize it fully first.

Acceptable example data patterns:
```sql
-- Synthetic seed data
select 1 as user_id, 'user_001@example.com' as email, 'Ada Lovelace' as name
union all
select 2, 'user_002@example.com', 'Grace Hopper'
```

## Regulatory awareness

- Be aware that different jurisdictions have different rules (GDPR, CCPA, HIPAA, etc.).
- When in doubt, apply the strictest standard.
- Log access to PII tables if your warehouse supports it (query history, audit logs).
- Data retention: do not build models that retain PII longer than the defined retention policy. Ask the data owner if you are unsure of the retention window.

## When you encounter PII unexpectedly

If you discover PII in a location where it should not be (e.g., a mart table, a log file, a public dashboard):
1. Do not copy or redistribute it further.
2. Flag it immediately in the appropriate channel.
3. Document where you found it and what you observed (without including the PII itself).
4. Help remediate by writing a migration or fix to remove or hash the data.
