---
name: heavy-file-ingestion
description: Convert heavy, agent-hostile files (large PDFs, slide decks, spreadsheets, CSVs, Word docs) into lightweight Markdown/CSV artifacts plus an index before any analysis. Never analyze heavy files directly in context.
---

# Heavy File Ingestion

Convert heavy, agent-hostile files into lightweight Markdown and CSV artifacts before any analysis begins. Pay the conversion cost once and every future session works from clean, greppable text.

## Trigger Conditions

- User shares a large or binary document (PDF, PPTX, XLSX, DOCX, CSV)
- Any analysis request that touches a heavy file
- User says "analyze this document" and the document is large
- Context window is at risk from raw file content

## Rule: Never Analyze Directly

Always convert to lightweight artifacts first. Never read a 200-page PDF or 40-tab spreadsheet directly into context.

## Setup

On first use, interview for:
- Where converted artifacts should live (suggest `_ingested/` folder next to source)
- Which file types the user handles most often

## Conversion Recipes

### PDF (text-based)
```bash
# Using pdftotext (poppler-utils)
pdftotext -layout "<source>.pdf" "_ingested/<name>.md"

# Or using Python with pymupdf
python -c "
import fitz
doc = fitz.open('<source>.pdf')
for page in doc:
    print(page.get_text())
" > "_ingested/<name>.md"
```

### PDF (scanned/image-based)
Use OCR via tesseract or a cloud OCR API. Note OCR confidence in the index.

### PowerPoint (PPTX)
```bash
python -c "
from pptx import Presentation
prs = Presentation('<source>.pptx')
for i, slide in enumerate(prs.slides):
    print(f'## Slide {i+1}')
    for shape in slide.shapes:
        if hasattr(shape, 'text'):
            print(shape.text)
    print()
" > "_ingested/<name>.md"
```

### Excel (XLSX)
```bash
# Convert each sheet to a separate CSV
python -c "
import pandas as pd
xls = pd.ExcelFile('<source>.xlsx')
for sheet in xls.sheet_names:
    df = pd.read_excel(xls, sheet_name=sheet)
    df.to_csv(f'_ingested/<name>_{sheet}.csv', index=False)
"
```

### CSV (large)
```bash
# If CSV is >1000 rows, produce summary + sample
# Otherwise, clean and copy
head -1000 "<source>.csv" > "_ingested/<name>.csv"
echo "... truncated to 1000 rows" >> "_ingested/<name>.csv"
```

### Word (DOCX)
```bash
python -c "
import docx
doc = docx.Document('<source>.docx')
for para in doc.paragraphs:
    print(para.text)
" > "_ingested/<name>.md"
```

## Chunking for Very Large Sources

If a converted artifact exceeds ~500 lines, split it into numbered chunks:
```
_ingested/<name>-01.md  # Pages 1-50
_ingested/<name>-02.md  # Pages 51-100
```

Each chunk must be independently readable with a header noting the page range.

## Index File

Always produce an index:

```markdown
# Ingestion Index: <source-directory>

| Artifact | Source | Type | Rows/Pages | Chunks | Summary |
|----------|--------|------|------------|--------|---------|
| report.md | report.pdf | PDF | 45 pages | 1 | Annual report 2024 |
| data.csv | data.xlsx | Excel | 500 rows | 1 | Monthly sales data |
```

## Verification

Ingest one real PDF or deck. Show the artifact folder and index. Confirm all artifacts are readable without the original.
