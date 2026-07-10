---
name: pdf-document-ingestion
description: Convert PDFs, scans, forms, CSVs, and loose source files into lightweight markdown or tabular artifacts with stable source anchors. Use before analysis begins — turn heavy documents into citable, greppable evidence artifacts.
---

# PDF / Document Ingestion

Turn heavy or messy documents into lightweight artifacts with stable source anchors before analysis begins. Ingestion is a chain-of-custody step: every paragraph, row, or form field needs a path back to the original file, page, heading, row, or box.

## Trigger Conditions

- A case or project receives source documents (PDFs, scans, forms, CSVs, images)
- Analysis is about to begin on documents that can't be cited cleanly
- User asks to "ingest" or "convert" documents for a case

## Requirements

### Preserve Originals
- Never modify, rename, or move original source files
- Work from copies or read-only access
- Source files stay at their original paths, recorded in the index

### Conversion
- PDFs → markdown or structured text (preserve headings, paragraphs, tables)
- Forms → extract labeled fields with their values and box/field identifiers
- CSVs → normalize to tabular format with row-number anchors
- Images/Scans → OCR to text, note OCR confidence in the index

### Source Anchors
Choose one canonical anchor convention per case. Every artifact in that case uses the same scheme:

| Source Type | Anchor Format | Example |
|-------------|---------------|---------|
| PDF | `{filename}:p{page}[{region}]` | `denial-letter.pdf:p3[tl]` |
| CSV | `{filename}:L{line}` | `charges.csv:L42` |
| Form | `{filename}:{box-label}` | `intake-form.pdf:dob-field` |
| Markdown | `{filename}:{heading-path}` | `policy.md:##Coverage##PhysicalTherapy` |

**One scheme only** — two numbering schemes in one artifact is a defect. A citation must resolve without a translation table.

### Index
Write an index listing every converted artifact:

```markdown
| Artifact | Source Path | Type | Pages/Rows | Confidence | Anchor Scheme |
|----------|------------|------|------------|------------|---------------|
```

### Never Analyze Originals
Once ingested artifacts exist, always work from the ingested versions. The originals are the ground-truth reference, not the working surface.

## Output Convention

```
work/<case-id>/ingested/
├── index.md
├── <doc-name>.md
├── <doc-name>.csv
└── ...
```

## Verification

Run on one sample document. Pick a converted paragraph and trace it back to its source anchor. The path must be unambiguous.
