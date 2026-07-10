---
name: browser-qa
description: Professional-grade web testing through browser automation via Chrome DevTools Protocol. Performance traces, Core Web Vitals, network monitoring, console error capture, device emulation, and accessibility checks -- with evidence. Use when verifying web changes or auditing a page.
---

# Browser Automation QA

Upgrade from eyeballing pages to measuring them. Performance traces, Core Web Vitals, network monitoring, console errors, responsive testing, accessibility checks -- all with metrics and screenshots as evidence.

## Trigger Conditions

- Verifying a web change before merge
- Checking performance after a UI update
- Auditing a page for issues
- Testing responsive behavior
- User asks to "QA this page" or "check the site"

## Setup

Requires a Chrome DevTools MCP (Model Context Protocol) server connected to the harness. The agent should:
1. Install and configure a Chrome DevTools MCP server
2. Verify connection: navigate to any page and confirm screenshot capture works
3. Walk through any manual installation steps the agent cannot automate

## Check Recipes by Change Type

### Layout / Styling Changes
- Screenshots at desktop (1280px), tablet (768px), and mobile (375px)
- Compare against baseline screenshots if available
- Check for visual regressions: overlapping elements, truncated text, layout breaks

### Performance-Relevant Changes
- Run a performance trace
- Measure Core Web Vitals:
  - **LCP** (Largest Contentful Paint): target < 2.5s
  - **INP** (Interaction to Next Paint): target < 200ms
  - **CLS** (Cumulative Layout Shift): target < 0.1
- Compare against stated project thresholds; flag regressions

### New Features / Pages
- Script a walkthrough of the full user flow
- Monitor console for errors during walkthrough
- Check all network requests for failures (4xx, 5xx)
- Verify key user actions succeed

### Accessibility
- Check heading hierarchy
- Verify focus states on interactive elements
- Check color contrast on key text elements
- Test keyboard navigation through the flow

## Evidence Rule

Every finding ships with its artifact -- never "looks fine" without proof:

| Finding Type | Evidence Required |
|-------------|-------------------|
| Visual issue | Screenshot with issue highlighted |
| Performance issue | Trace excerpt showing the metric |
| Console error | Copied error message with stack trace |
| Network failure | Failed request with status code and URL |
| Responsive issue | Screenshots at the failing breakpoint |

## Report Format

```markdown
# Browser QA Report: <page/feature>
**Date**: YYYY-MM-DD
**URL**: <tested URL>
**Change type**: <layout/performance/new-feature>

## Checks Performed
| Check | Result | Evidence |
|-------|--------|----------|
| Desktop layout | PASS | [screenshot] |
| Mobile layout | PASS | [screenshot] |
| Console errors | FAIL | 2 errors: [details] |
| LCP | PASS | 1.8s (threshold 2.5s) |

## Failures
### 1. Console Error on Cart Page
**Reproduction**: Navigate to /cart, add item, observe console
**Error**: `Uncaught TypeError: Cannot read property 'price' of undefined`
**Evidence**: [screenshot + log excerpt]

## Performance Summary
| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| LCP | 1.8s | 2.5s | PASS |
| INP | 150ms | 200ms | PASS |
| CLS | 0.05 | 0.1 | PASS |
```

## Integration with Runbook

Findings about how to test a page get written to the repo's testing runbook per `testing-runbook-creator`.
- Page-specific selectors discovered during QA -> testing runbook
- Workflow-specific test paths -> testing runbook
- Test account quirks -> testing runbook
- General QA methodology stays in this skill

## Verification

Audit one live page. Show the report with screenshots, metrics, console output, and any failures found.
