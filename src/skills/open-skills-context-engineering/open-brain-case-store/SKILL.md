---
name: open-brain-case-store
description: Map document-grounded case workflows onto Open Brain (OB1) instead of SQLite. Use when already running Open Brain and want case records inside a durable personal context layer.
---

# Open Brain Case Store

Adapt the case-file schema to Open Brain for OB1 users who want normalized records, chunks, and source anchors inside their durable personal context layer instead of a local SQLite file.

## Trigger Conditions

- User has an existing Open Brain / OB1 setup
- User wants case data in their persistent context layer
- Migrating a case from SQLite to Open Brain

## Logical Schema

Start from the same logical schema used by the SQLite case store. Map each table to an Open Brain primitive:

### Source Documents → Open Brain
Capture each source document as a reference thought:
```
type: reference
topic: case-<case-id>
content: source_path, artifact_path, document_type, anchor_scheme
```

### Chunks → Open Brain
Capture each chunk as a reference thought with metadata:
```
type: reference
topic: case-<case-id>
content: chunk_id, section_label, domain_tags, source_anchor, content
```

### Normalized Records → Open Brain
Capture each record as an observation with structured content:
```
type: observation
topic: case-<case-id>
content: record_id, fact_type, date, party, amount, code, review_status, source_anchors
```

### Run Outputs → Open Brain
Capture each run as an observation with status tracking:
```
type: observation
topic: case-<case-id>
content: run_id, step, status, log summary
```

## Provenance Preservation

Every entity stored in Open Brain must carry:
- Source anchors (unchanged from ingestion)
- Original file paths
- Case ID for retrieval grouping

## Migration Path

When moving a local SQLite starter case into Open Brain:
1. Export SQLite case to JSON (`export-case` script)
2. For each row in each table, create the corresponding Open Brain thought
3. Verify query-by-case_id returns the same records
4. Keep the SQLite as a backup; do not delete it

## Query Patterns

Retrieve by case_id:
```
openbrain_search_thoughts(query="case-<case-id> <section_label>")
```

Retrieve all chunks for a section:
```
openbrain_search_thoughts(query="<section_label> case-<case-id>", limit=50)
```

## Rules

- Do not imply Open Brain is required for the beginner path — SQLite is the starter
- Preserve source anchors and provenance in every stored thought
- Use the same logical schema; mapping is structural, not conceptual

## Verification

Write one sample case record using `openbrain_capture_thought`, then search for it by `case_id` and `section_label` to confirm retrieval.
