---
name: html-artifacts
description: Render dense, visual, interactive, reusable, or shareable output as a polished single-file HTML artifact instead of a long chat response. Use for plans, reports, research explainers, review summaries, comparisons, diagrams, timelines, dashboards, walkthroughs, or any result whose structure or value would benefit from visual presentation or offline retention; offer an artifact when useful and produce one when explicitly requested.
---

# HTML Artifacts

Create a durable visual deliverable, then keep the chat handoff brief.

## Decide and route

- Produce an artifact when the user asks for HTML or when the result is dense, visual, interactive, worth keeping, or worth sharing.
- Offer an artifact before producing one when the benefit is plausible but the request is primarily conversational or the extra file would be surprising.
- Keep a normal chat response for short answers that do not gain clarity or durability from a file.
- Save project-bound artifacts in `<project-root>/output-html/`.
- Save artifacts not tied to a project in `[OneDrive root]/hq/output-html/`. Resolve the actual OneDrive root from the environment or user context; ask only when it cannot be discovered safely.
- Use a descriptive kebab-case filename such as `architecture-review-2026-07-12.html`. Do not overwrite an existing artifact unless the user requested an update.

## Build the artifact

1. Start from `assets/artifact-template.html` when practical.
2. Define all house-style tokens once in the first `:root` block. Override tokens there, never through scattered magic values.
3. Select the smallest layout pattern that fits the content: report, comparison table, timeline, diagram, or dashboard.
4. Preserve information hierarchy: title and purpose, key takeaway, evidence or details, then implications or next actions.
5. Add lightweight interaction only when it improves comprehension, such as filtering, tabs, disclosure controls, or diagram focus states.
6. Make responsive behavior and print output usable.
7. For workshops, handoffs, and other specialist materials, add a concise plain-language vocabulary when labels, abbreviations, phases, or evidence codes would be unclear to a new reader. Define the label at first use when practical and collect the full set in a linked reading guide near the end.

## Hard rules

- Deliver exactly one `.html` file.
- Inline all CSS and JavaScript.
- Use no external libraries, fonts, images, stylesheets, APIs, CDNs, or network requests.
- Ensure the artifact works offline when opened directly from disk.
- Use semantic HTML, visible keyboard focus, sufficient contrast, and reduced-motion handling.
- Escape or safely encode untrusted content. Do not inject user-provided strings through `innerHTML`.
- Prefer system font stacks; do not embed large font binaries.

## House style

Use the tokens in `assets/artifact-template.html` as the canonical defaults:

- Direction: modern sans-serif, crisp, restrained, editorially structured.
- Canvas: warm off-white with white surfaces.
- Primary: deep blue; accent: warm gold.
- Appearance: light by default.
- Spacing: an eight-step scale from compact labels to major section rhythm.
- Shape: modest rounded corners, fine blue-gray borders, and restrained shadows.

Keep gold for emphasis and highlights rather than long text. Use blue for headings, links, controls, and data emphasis.

### Avoid generic AI-report styling

- Compose the page around the document's actual job and audience; do not apply a dashboard or card-grid pattern by default.
- Use elevation, rounded surfaces, pills, badges, and accent color selectively. Repeating the same rounded card for every paragraph makes a document feel templated and obscures hierarchy.
- Prefer an editorial rhythm: a purposeful hero, clear section dividers, varied but consistent content groupings, readable type scale, and sufficient quiet space.
- Avoid decorative gradients, oversized motivational headlines, dense rows of status pills, and arbitrary visual flourishes unless they serve the content.
- Make evidence status understandable. Use plain-language definitions for codes such as participant-reported, observed, open question, working assumption, or facilitator suggestion; never assume the reader attended the source session.

## Layout patterns

- **Report:** executive summary, metric or finding cards, evidence sections, recommendations, sources or notes.
- **Comparison table:** sticky or prominent row/column labels, scannable criteria, highlighted differences, responsive horizontal scroll, and a concise verdict.
- **Timeline:** vertical flow on narrow screens and horizontal or stepped flow when space permits; show dates, milestones, status, and dependencies.
- **Diagram:** use accessible HTML/CSS shapes or inline SVG; include a text legend or explanation and meaningful labels. Keep connectors legible at all viewport sizes.
- **Dashboard:** summary metrics first, followed by charts or progress views, filters only when useful, and a plain-language interpretation near every visualization.

Combine patterns only when the content genuinely needs them.

## Verify before declaring completion

1. Open the saved file in an available browser.
2. Inspect the rendered result at a normal desktop viewport and a narrow/mobile viewport.
3. Capture a screenshot when the harness supports it and visually check hierarchy, overflow, clipping, contrast, and empty states.
4. Exercise every control and confirm there are no console errors or network dependencies.
5. Fix any rendering problem and repeat verification.
6. Only then provide the file link and a one-sentence summary in chat.

If the available preview surface blocks local files, do not claim visual browser validation. Complete static checks (document structure, anchor targets, and external dependencies), open the artifact in the workspace when possible, and state the limitation succinctly.

Never declare an artifact complete based only on reading its source.
