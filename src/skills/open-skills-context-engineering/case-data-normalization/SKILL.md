---
name: case-data-normalization
description: Extract messy document facts into a structured, reviewable ledger. Separates source-backed facts from inferred classifications so humans can see which fields came from the page and which need judgment.
---

# Case Data Normalization

Turn messy facts from documents into a normalized case ledger: dates, parties, amounts, codes, categories, document links, confidence, and review status. Separate extracted facts from inferred classifications.

## Trigger Conditions

- Source documents are chunked and tagged
- Facts need to be extracted into queryable records
- User asks to "normalize" or "structure" case data

## Minimum Schema

Define the domain schema before extraction. Typical fields:

| Field | Source | Description |
|-------|--------|-------------|
| `record_id` | Generated | Unique record identifier |
| `case_id` | Assigned | Which case this belongs to |
| `source_anchors` | Ingestion | List of source anchors backing this record |
| `fact_type` | Domain | e.g. charge, denial, payment, coverage_clause |
| `date` | Extracted | Date of the event (absolute, parsed) |
| `party` | Extracted | Which party this concerns |
| `amount` | Extracted | Dollar amount, if applicable |
| `code` | Extracted | CPT, ICD, procedure, or reference code |
| `category` | Classified | Agent-assigned category |
| `confidence` | Computed | High/medium/low based on extraction quality |
| `review_status` | Computed | `pass`, `needs_review`, or `fail` |
| `unresolved_question` | Computed | Filled when review_status is `needs_review` |

## Separation Rule

Source-backed facts and agent classifications must be stored separately or clearly labeled:
- **Extracted**: came directly from the page (date, amount, code, name)
- **Classified**: agent-assigned (category, inferred relationship, priority)

A human must be able to see which fields came from evidence and which came from judgment.

## Sanity Checks

Run field-level checks against the source before accepting:

1. **Names look like names** — a street address in a name field is the canonical failure
2. **Dates parse to real absolute dates** — compute days remaining for deadlines; reject `00/00/0000` or future dates for past events
3. **Amounts reconcile against line-item sums** — if a claim says $1,500 total and line items sum to $1,200, flag it

## Cross-Document Deduplication

When two documents state the same fact, compare field by field:
- Denial letter CPT code vs. EOB row
- Receipt amount vs. bank line
- Policy clause vs. plan document

One real-world event = one record citing all supporting sources. Mismatches become `needs_review` with an unresolved question naming which source governs the tracked value.

## Review Status

Records that fail sanity checks get `review_status: needs_review` with a concrete unresolved question. Never use a default `pending` status — every flagged record must explain what's wrong.

## Verification

Normalize one sample case. Show which fields came directly from source evidence and which were classified by the agent.
