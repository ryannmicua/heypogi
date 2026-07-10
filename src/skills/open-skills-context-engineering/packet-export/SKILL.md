---
name: packet-export
description: Package validated case outputs into an editable folder and PDF — draft, citation map, checklist, supporting documents, source manifest, and unresolved questions. Use when citation guard passes and the case is ready for human review.
---

# Packet Export

Package the reviewed outputs into an editable folder and PDF: draft letter or summary, citation map, checklist, supporting documents list, source manifest, and any unresolved questions.

## Trigger Conditions

- Case outputs are validated (citation guard passed or all claims are pass/needs_review)
- User asks to "export the packet" or "package the case"
- Work is ready for human review or handoff

## Pre-Export Gate

Refuse to export while the citation guard reports any `fail` verdict. A packet ships only when every claim is `pass` or `needs_review`. The guard's verdict summary must appear in the packet README.

## Folder Structure

```
packet/
├── README.md                 # Overview, verdict summary, next steps for human
├── draft.md                  # Draft letter, summary, or response
├── draft.pdf                 # Rendered PDF for handoff
├── citation-map.json         # Claim → citation → verdict mapping
├── checklist.md              # Human review checklist
├── supporting-documents.md   # List of all supporting docs with anchors
├── source-manifest.md        # Original source files and paths
├── unresolved-questions.md   # Questions that need human judgment
└── sources/                  # Copies of original source files (if needed)
    ├── denial-letter.pdf
    └── ...
```

## Keep Markdown Editable

Markdown, JSON, and CSV outputs stay editable in the packet folder. Do not render markdown to PDF and discard the source. The markdown is the source of truth; PDF is the delivery artifact.

## PDF Export

1. Convert markdown to HTML (use a markdown-to-HTML converter available in the environment)
2. Render HTML to PDF via headless Chrome:
   ```
   chrome --headless --disable-gpu --print-to-pdf="packet/draft.pdf" packet/draft.html
   ```
3. **Headless Chrome warning**: the process can stay alive ~2 minutes after PDF is written. Verify the file appears on disk rather than trusting exit status. Use `--disable-background-networking` or a poll-then-kill wrapper.
4. Confirm the PDF has reasonable page count (single or low double digits for one case)
5. Confirm tables render with no raw markdown artifacts

## Include, Don't Hide

- Unresolved questions → `unresolved-questions.md` — list them, don't bury them
- Missing documents → note in `source-manifest.md` with reason
- Instead of hiding gaps, flag them for the human reviewer

## Never Transmit

The packet is for local export and human review only. Never transmit, submit, sign, file, or send the packet through any automated channel. That boundary belongs to the human gate.

## Verification

Export a sample packet, open the PDF, confirm:
- Page count is sane (not 50 pages for one letter)
- Tables render correctly (no raw `|---|---|` in the PDF)
- All referenced chunks resolve to actual source documents
