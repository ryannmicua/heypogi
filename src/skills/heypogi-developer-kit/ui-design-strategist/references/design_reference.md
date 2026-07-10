# Design Reference

## Product Design Lens

Evaluate every interface through four questions:

1. Who is using this?
2. What are they trying to accomplish?
3. What information or action matters most right now?
4. What could prevent them from succeeding?

Good UI is not just visual polish. It is a clear arrangement of priorities, actions, feedback, and constraints.

## UX Heuristics

Use these heuristics during critiques and redesigns:

- Match the user's mental model. Use labels and flows that reflect how users think about the task, not how the database or organization is structured.
- Make the primary action obvious. Every screen should have a clear next best action unless it is intentionally exploratory.
- Reduce memory load. Keep important context visible near the decision point.
- Prefer recognition over recall. Use visible options, examples, defaults, and previews.
- Make system status visible. Show loading, saving, progress, success, failure, and pending states.
- Prevent errors before validating them. Use constraints, hints, input masks, defaults, and confirmation only where needed.
- Make recovery easy. Error messages should explain what happened, what to do next, and where possible preserve user input.
- Be consistent where consistency helps learning. Break patterns only when the new pattern is clearly better.
- Design for scanning. Users often skim before reading; use hierarchy, grouping, spacing, and meaningful headings.
- Respect attention. Avoid unnecessary alerts, modals, carousels, animations, and competing calls to action.

## Visual Design Review Checklist

### Hierarchy

- Is the most important information visually dominant?
- Is there a single primary action?
- Are secondary actions visually subordinate?
- Are headings, body text, labels, and metadata clearly differentiated?

### Layout

- Does the layout follow a predictable grid?
- Are related elements grouped together?
- Is spacing used to communicate structure?
- Does the page avoid unnecessary density?
- Is the layout resilient to long labels, missing data, and localization?

### Components

- Are components used consistently?
- Are buttons, links, tabs, filters, dropdowns, and cards visually distinct by role?
- Are destructive actions visually and behaviorally protected?
- Are disabled states explained when the reason is not obvious?

### Content

- Are labels specific and action-oriented?
- Does copy explain consequences before risky actions?
- Are instructions placed near the relevant control?
- Does the interface avoid internal jargon unless the audience expects it?

### Trust and Quality

- Does the page feel reliable and intentional?
- Are alignment, spacing, typography, and icon use consistent?
- Are important actions supported by confirmation, preview, or undo when needed?

## Accessibility Checklist

Use accessibility guidance by default, not as an afterthought.

- Ensure text and interactive controls have sufficient contrast.
- Use semantic HTML where implementation advice is requested.
- Ensure all interactive controls are reachable and usable by keyboard.
- Provide visible focus states.
- Use labels for form controls.
- Do not rely only on color to communicate status or meaning.
- Make touch targets large enough for mobile use.
- Support screen reader-friendly status updates for loading, errors, and successful actions.
- Avoid motion that is excessive or required for comprehension.
- Respect reduced-motion preferences when discussing animation.

## Responsive Web Application Guidance

### Desktop

- Use available width for comparison, overview, data density, and persistent navigation.
- Keep primary actions near the content they affect.
- Avoid making users scan across very wide rows without anchors.

### Tablet

- Reduce column count.
- Keep key filters and primary actions accessible.
- Avoid hover-dependent interactions.

### Mobile

- Prioritize task completion over full feature parity.
- Collapse complex tables into cards or focused drill-down views.
- Move bulk actions and filters into clear, recoverable patterns.
- Keep forms single-column unless the fields are extremely simple.

## Common Web App Patterns

### Dashboard

Best for monitoring, prioritization, and quick navigation. Avoid using dashboards as junk drawers. Every card should answer: what changed, what matters, and what should the user do next?

### Data Table

Use when users need to compare, sort, filter, scan, or take action across many records. Include empty states, loading states, column behavior, row actions, bulk actions, and mobile alternatives.

### Form

Group fields by decision, not by database schema. Prefer progressive disclosure for advanced or conditional inputs. Put help text and validation near the field.

### Wizard

Use when the task is linear, complex, or high-stakes. Show progress, allow backtracking, preserve data, and make exit behavior clear.

### Settings Page

Use clear categories and explain consequences. Settings often need descriptions, defaults, permissions, auditability, and reset behavior.

### Public Website

Prioritize message clarity, scannability, trust cues, accessible content, and fast paths to the primary conversion or informational goal.

## Source Guidance for Further Reading

When sources are requested, prefer primary or reputable practitioner sources. Do not dump links. Group sources by purpose and explain what the user should read there.

Useful categories:

- Usability research: Nielsen Norman Group, Baymard Institute
- Accessibility standards and practice: W3C WCAG, WebAIM, ARIA Authoring Practices Guide
- Design systems: Material Design, Apple Human Interface Guidelines, Microsoft Fluent, GOV.UK Design System, IBM Carbon
- Frontend implementation: MDN Web Docs, React documentation, Tailwind documentation
- Design education and patterns: Laws of UX, Refactoring UI, Smashing Magazine, A List Apart, A Book Apart

Use current web search for source lists when the user asks for links, citations, current standards, recent articles, or tool-specific documentation.
