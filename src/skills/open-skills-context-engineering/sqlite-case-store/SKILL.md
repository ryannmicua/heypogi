---
name: sqlite-case-store
description: Stand up a local SQLite database for document-grounded case workflows — source documents, chunks, normalized records, retrieval mappings, run outputs, and validation results. Use as the default starter backend for case files.
---

# SQLite Case Store

Create a local SQLite database for case file workflows. Local, inspectable, portable, and enough for one person's case file. Swap it later when the system earns more complexity.

## Trigger Conditions

- Starting a new case that needs durable storage
- Need to migrate from ad-hoc files to a queryable backend
- User asks to "set up the case store" or "create case database"

## Schema

### `source_documents`
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment ID |
| case_id | TEXT | Case identifier |
| source_path | TEXT | Original file path |
| artifact_path | TEXT | Ingested artifact path |
| document_type | TEXT | denial_letter, eob, policy, receipt, etc. |
| page_count | INTEGER | Number of pages/rows |
| ingestion_date | TEXT | ISO timestamp |
| anchor_scheme | TEXT | Which anchor convention used |

### `chunks`
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment ID |
| chunk_id | TEXT UNIQUE | Unique chunk identifier |
| case_id | TEXT | Case identifier |
| source_document_id | INTEGER FK | Reference to source_documents.id |
| document_type | TEXT | |
| section_label | TEXT | Normalized domain label |
| domain_tags | TEXT | JSON array of tags |
| source_anchor | TEXT | Canonical anchor string |
| granularity | TEXT | page or clause |
| effective_date | TEXT | ISO date |
| content | TEXT | Chunk text |

### `normalized_records`
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | |
| record_id | TEXT UNIQUE | Unique record identifier |
| case_id | TEXT | |
| fact_type | TEXT | charge, denial, payment, etc. |
| date | TEXT | ISO date |
| party | TEXT | |
| amount | REAL | |
| code | TEXT | CPT, ICD, reference code |
| category | TEXT | Agent-classified category |
| confidence | TEXT | high, medium, low |
| review_status | TEXT | pass, needs_review, fail |
| unresolved_question | TEXT | |
| source_anchors | TEXT | JSON array of anchor strings |

### `retrieval_mappings`
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | |
| case_type | TEXT | Domain case type |
| required_section | TEXT | Section label needed |
| chunk_ids | TEXT | JSON array of matching chunk IDs |

### `run_outputs`
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | |
| case_id | TEXT | |
| run_id | TEXT | Unique run identifier |
| step | TEXT | ingest, chunk, normalize, retrieve, draft, validate, export |
| timestamp | TEXT | ISO timestamp |
| status | TEXT | pass, fail, needs_review |
| output_path | TEXT | Path to output artifact |
| log | TEXT | Summary or error details |

### `validation_results`
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | |
| run_id | TEXT FK | Reference to run_outputs.run_id |
| claim_text | TEXT | The claim being validated |
| citation | TEXT | The citation string |
| verdict | TEXT | pass, needs_review, fail |
| detail | TEXT | Why the verdict was assigned |

## Scripts

- **migrate**: Create all tables, run idempotently
- **inspect**: `SELECT` summary views of tables
- **query-by-section**: `SELECT * FROM chunks WHERE section_label = ?`
- **export-case**: Dump all records for a case_id to JSON

## Rules

- Keep original document paths and source anchors in the database
- Do not store secrets or real private data in committed fixtures
- Store the database at `work/<case-id>/case.db`

## Verification

Run a migration, insert sample chunks, and demonstrate a `WHERE section_label` query returning the correct rows with valid source anchors.
