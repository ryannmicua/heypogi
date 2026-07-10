---
name: html-artifacts
description: Render dense or visual output -- plans, reports, comparisons, diagrams, walkthroughs -- as a single self-contained HTML file with consistent house styling. Use when output would be dense, visual, interactive, or worth keeping.
---

# HTML Artifact Builder

Turn dense agent output into a single self-contained HTML file with consistent, polished styling. One file, inline CSS/JS, no external dependencies, openable anywhere.

## Trigger Conditions

- Output would be dense, visual, interactive, or worth keeping/sharing
- User says "make this a page" or "render as HTML"
- Complex comparisons, timelines, reports, or dashboards
- Any output where a long chat response is insufficient

## Setup

On first use, interview for:
- Visual preferences: typeface direction (serif/sans-serif/mono), color palette or brand color, dark or light default
- Where artifact files should be saved (default: `work/artifacts/`)

## Hard Rules

1. **One file** — everything in a single `.html` file
2. **Inline CSS and JS** — no `<link>` or `<script src="...">`
3. **No external dependencies** — no CDN fonts, no frameworks, no API calls
4. **Works offline** — open the file directly in a browser, no server needed
5. **Accessible** — readable at any viewport width

## House Style Tokens

Define once at the top of every artifact:

```css
:root {
  --font-body: system-ui, -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
  --color-muted: #6b7280;
  --color-accent: #2563eb;
  --color-border: #e5e7eb;
  --color-surface: #f9fafb;
  --max-width: 800px;
  --spacing: 1.5rem;
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #111827;
    --color-text: #f3f4f6;
    --color-muted: #9ca3af;
    --color-accent: #60a5fa;
    --color-border: #374151;
    --color-surface: #1f2937;
  }
}
```

## Layout Patterns

### Report
```html
<header><h1></h1><p class="meta"></p></header>
<main>
  <section><h2>Summary</h2></section>
  <section><h2>Findings</h2></section>
  <section><h2>Recommendations</h2></section>
</main>
```

### Comparison Table
```html
<table class="comparison">
  <thead><tr><th>Dimension</th><th>A</th><th>B</th></tr></thead>
  <tbody><!-- rows --></tbody>
</table>
```

### Timeline
```html
<ol class="timeline">
  <li><time></time><h3></h3><p></p></li>
</ol>
```

### Dashboard
Grid layout with metric cards, tables, and charts (inline SVG or Canvas).

## Verification

Open the HTML file in a browser and confirm:
- Renders correctly at various widths
- Dark/light mode toggles cleanly
- All content is visible, no broken layouts
- File can be shared and opened standalone
