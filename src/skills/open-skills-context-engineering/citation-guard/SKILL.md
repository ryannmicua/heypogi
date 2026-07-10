---
name: citation-guard
description: Validate that substantive draft claims are grounded in known evidence. Checks that cited chunks exist AND support the claimed amount, date, or language. Use before finalizing any draft that makes evidence-backed claims.
---

# Citation Guard

Validate that generated draft claims are grounded in known evidence. A citation that resolves but does not support its claim fails. Verdicts are three-state: `pass`, `needs_review`, `fail`.

## Trigger Conditions

- A draft has been generated with citations to case evidence
- Before packet export or final delivery
- User asks to "validate citations" or "check the draft"

## Substantive Claims

Define what counts as a substantive claim for the current domain:

| Domain | Substantive Claims |
|--------|-------------------|
| Healthcare | Amounts, dates of service, denial codes, coverage statements, deadlines |
| Tax | Income figures, deduction amounts, filing dates, eligibility criteria |
| Legal/Contract | Obligation language, dates, monetary amounts, liability clauses |
| Any | Any claim that, if wrong, changes the outcome |

General disclaimers and process labels (e.g. "This letter responds to...") do not need citations when they are boilerplate from the runbook.

## Citation Syntax

Prescribe ONE machine-checkable citation syntax. Every citation in the domain must use it:

```
[record:<case-id>:<fact-type>:<identifier>]
[chunk:<chunk-id>]
```

Example: `[record:case-42:expense:adobe_feb]` or `[chunk:eoc-017]`

## Validation Steps

### 1. Resolve
Every citation must resolve against the case store (SQLite or Open Brain). A citation that does not resolve to an existing record or chunk is a `fail`.

### 2. Verify Support (Not Just Existence)
Compare the claimed amount, date, or quoted language against the cited record's stored values:
- Claim: "$1,500 for physical therapy on 2024-03-15"
- Cited chunk says "$1,200 for occupational therapy on 2024-03-22"
- → `fail`: citation exists but does not support the claim

### 3. Verdict Assignment

| Verdict | Condition |
|---------|-----------|
| `pass` | Citation resolves AND stored values match the claim |
| `needs_review` | Underlying record is itself flagged `needs_review` — not a soft pass for unsupported claims |
| `fail` | Citation does not resolve, OR resolves but contradicts the claim |

## Validation Report

```json
{
  "run_id": "validate-2024-03-15-001",
  "draft_path": "work/case-42/draft.md",
  "total_claims": 12,
  "pass": 10,
  "needs_review": 1,
  "fail": 1,
  "results": [
    {
      "claim": "...",
      "citation": "[chunk:eoc-017]",
      "verdict": "pass",
      "detail": "Chunk content matches claimed amount of $1,500"
    },
    {
      "claim": "...",
      "citation": "[record:case-42:charge:nonexistent]",
      "verdict": "fail",
      "detail": "Record does not exist in case store"
    }
  ]
}
```

## Gate Rule

Exit nonzero when any claim fails — so the guard can gate downstream pipeline steps. A packet must not export while the citation guard reports any `fail`.

## Two-Sided Verification Test

1. **Positive test**: Run on a fully-cited draft → must PASS (exit 0)
2. **Negative test**: Copy the draft, insert one fabricated-but-well-formed citation (plausible ID that does not exist) → must FAIL (nonzero exit)
3. Save both reports as artifacts — the fabricated sentence itself must appear as the failing item in the failure report
