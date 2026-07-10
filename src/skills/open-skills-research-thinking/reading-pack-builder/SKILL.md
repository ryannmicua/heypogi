---
name: reading-pack-builder
description: Build a self-contained local HTML reading pack from a set of documents -- one at a time, deliberate order, with index and progress tracking. Use when reviewing a pile of documents or asking for a "reading pack."
---

# Reading Pack Builder

Take a pile of local documents and build a controlled reading surface: a local HTML reading pack that presents one document at a time, in a deliberate order, with an index and progress tracking.

## Trigger Conditions

- User has a pile of documents to review
- User asks for a "reading pack" or "review pack"
- User needs to present materials to a reviewer in structured order
- Preparing for a review session where document order matters

## Setup Interview

On first use, ask:
- Where reading packs should be saved (default: `work/reading-packs/<name>/`)
- Visual preferences (font, spacing, color scheme) -- inherit from `html-artifacts` conventions if available

## Document Conversion

Convert each source document to clean, self-contained HTML:
- Markdown -> HTML (preserve headings, lists, tables, code blocks)
- Text -> HTML (wrap in `<pre>` or basic formatting)
- Keep anchors/citations intact as navigable links

## Index Page

```html
<!DOCTYPE html>
<html>
<head><title>Reading Pack: <name></title></head>
<body>
  <h1>Reading Pack: <name></h1>
  <p>Generated: <date></p>
  <h2>Reading Order</h2>
  <ol>
    <li><a href="doc-01.html">Document Title</a> -- <one-line summary> <span class="why">Why first: <reasoning></span></li>
    <li><a href="doc-02.html">Document Title</a> -- <one-line summary> <span class="why">Why here: <reasoning></span></li>
  </ol>
  <h2>Document List</h2>
  <table>
    <tr><th>Document</th><th>Source</th><th>Pages</th><th>Status</th></tr>
    <!-- rows -->
  </table>
</body>
</html>
```

## Navigation

Each document page includes:
- Previous/Next navigation
- "Back to Index" link
- Current position indicator (e.g., "Document 3 of 14")

## Progress Tracking

Store read/unread state in `localStorage`:
- Index page shows per-document status (unread / read)
- Progress persists across browser sessions (same browser, same machine)
- The pack itself is pure static HTML -- no server needed

## Self-Containment

Everything works offline as local files. No CDN dependencies, no server, no build step. Open `index.html` in a browser and read.

## Output

```
work/reading-packs/<name>/
├── index.html
├── doc-01.html
├── doc-02.html
├── doc-03.html
├── style.css
├── script.js
└── README.md          # What this pack is, when generated, reading order notes
```

## Verification

Build a pack from 3 or more documents. Open `index.html` in a browser. Confirm:
- Navigation works (prev/next/index)
- Progress tracking persists across page reloads
- All documents render correctly without raw markdown artifacts
