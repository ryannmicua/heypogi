---
name: document-chunking-tagging
description: Split ingested documents into addressable chunks and apply normalized metadata — document type, section label, domain tags, source anchor, effective date. Use after ingestion, before retrieval or analysis.
---

# Document Chunking and Tagging

Split ingested documents into addressable sections and tag each chunk with structured metadata. Favor structure-first tagging over vector similarity when source documents have known sections.

## Trigger Conditions

- Documents have been ingested and need to be prepared for retrieval
- Analysis or drafting will need to cite specific sections of documents
- User asks to "chunk" or "tag" documents

## Chunk Schema

Every chunk carries:

| Field | Description |
|-------|-------------|
| `chunk_id` | Unique identifier for this chunk |
| `case_id` or `plan_id` | Which case/plan this chunk belongs to |
| `document_type` | e.g. denial_letter, eob, policy_doc, receipt, contract |
| `section_label` | Normalized label from domain map (e.g. `coverage_limits`, `denial_reason`) |
| `domain_tags` | Domain-specific keywords (e.g. `physical_therapy`, `out_of_network`) |
| `source_anchor` | Canonical anchor back to source (from ingestion step) |
| `granularity` | `page` or `clause` — see two-tier rule below |
| `effective_date` | Date the chunk's content is effective (not the ingestion date) |
| `content` | The chunk's text, verbatim from source |

## Chunking Rules

### Structure First
Use headings, form boxes, table rows, and known document structure before semantic guessing. A document with `## Coverage Limits` gets a chunk for that section. A form with labeled fields gets a chunk per field group.

### Size Discipline
Chunks must be small enough to retrieve directly, but large enough to preserve the clause or table meaning. A half-sentence is too small; a 10-page dump is too large.

### Two-Tier Granularity (Long Documents)
For documents longer than ~5 pages:
- **Page-level chunks** (`granularity: page`): one per page, for whole-document citability
- **Clause-level chunks** (`granularity: clause`): one per named section, for precise retrieval

### Exclude Front Matter
Table of contents, index pages, and front matter must not become evidence chunks. A chunk cited as evidence must contain operative language (clauses, figures, statements), not headings or dotted page listings.

### Flag, Don't Guess
Unclassified sections get flagged for review with a `needs_review` tag. Do not invent labels.

## Verification

1. Query one chunk by `section_label` and confirm its `source_anchor` resolves to the right place
2. Pull every chunk a draft cites and read the text — if a TOC line appears as coverage evidence, chunking failed
