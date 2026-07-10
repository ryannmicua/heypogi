---
name: deterministic-retrieval-map
description: Build explicit lookup tables that map case types to document sections or record categories. Retrieve evidence by known structure first, then let the agent reason over a small, cited packet. Use when chunked documents are ready and retrieval needs to be predictable.
---

# Deterministic Retrieval Map

Build explicit lookup tables that map a case type to the document sections or record categories that matter. Retrieve by known structure first, then let the agent reason over a small, cited packet. Vector search is not the first move.

## Trigger Conditions

- Chunked/tagged documents are ready
- Retrieval or analysis is about to begin
- User asks how to "find the relevant sections" or "pull evidence"

## Domain Mapping

Define the case types and the section labels each type requires:

```markdown
| Case Type | Required Sections |
|-----------|-------------------|
| healthcare_denial | denial_reason, coverage_limits, plan_definitions, provider_network, appeal_deadline |
| tax_prep | income_sources, deductions, credits, prior_year_data, filing_deadline |
| contract_review | obligations, termination, liability, payment_terms, governing_law |
| grant_application | eligibility, budget, timeline, deliverables, reporting |
```

## Retrieval Implementation

Use ordinary queries against tags and labels — no vector similarity:

```sql
SELECT chunk_id, source_anchor, content
FROM chunks
WHERE case_id = ?
  AND section_label IN (?, ?, ?)
ORDER BY document_type, section_label;
```

Or in Open Brain:
```
openbrain_search_thoughts(query="<case_type> <section_label>", threshold=0.5)
```

## Evidence Packet

Return a compact evidence packet:

```json
{
  "case_id": "case-42",
  "case_type": "healthcare_denial",
  "retrieved_chunks": [
    {
      "chunk_id": "chunk-001",
      "source_anchor": "denial.pdf:p1",
      "section_label": "denial_reason",
      "content": "..."
    }
  ],
  "missing_sections": ["appeal_deadline"]
}
```

## Missing Section Flagging

Before drafting starts, flag any required sections that returned zero chunks:
- `appeal_deadline: NOT FOUND in case documents`
- This prevents the agent from drafting around gaps silently

## Semantic Search Fallback

Semantic/vector search is allowed only as a later fallback — never as the v1 foundation. When deterministic retrieval returns no results and drafting cannot proceed, then (and only then) fall back to semantic search with an explicit note: `retrieval_method: semantic_fallback`.

## Verification

Run all defined case types through the mapping. Show the retrieved chunk IDs for each. Confirm no TOC pages or front matter appear as evidence.
