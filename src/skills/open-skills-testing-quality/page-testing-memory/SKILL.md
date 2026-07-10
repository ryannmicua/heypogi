---
name: page-testing-memory
description: Teach the general page-QA process globally while keeping all page-specific knowledge in repo-local runbooks. Partners with testing-runbook-creator. Use when QAing or verifying any web page or UI.
---

# Page Testing Memory

Teach the general page-QA process globally, while keeping all page-specific knowledge -- selectors, routes, test accounts, seed data, cleanup quirks -- in repo-local runbooks. This is a skill about how to structure skills, disguised as a QA skill.

## Trigger Conditions

- QA or verification of any web page or UI
- Smoke-testing a feature visible in the browser
- User asks to "check this page" or "test the UI"

## Partner Skills

Designed to work as a pair with `testing-runbook-creator`. The split:
- **This skill** (global, portable): the process for how to approach testing any web page
- **Testing runbook** (repo-local): page-specific facts -- selectors, routes, test accounts, seed data, cleanup quirks

## General Page-QA Process

### 1. Identify Page States
Every page has states. Check each:
- **Empty / initial**: what shows before data loads
- **Loaded**: what shows with typical data
- **Error**: what shows when something fails
- **Loading**: what shows during data fetch
- **Edge cases**: zero results, max results, expired sessions

### 2. Test Forms
For every form on the page:
- **Valid input**: submit with correct data, verify success
- **Invalid input**: submit with bad data, verify validation errors appear
- **Edge input**: very long strings, special characters, boundary numeric values
- **Empty submission**: submit with no data, verify required-field errors

### 3. Verify Auth Boundaries
- What does an unauthenticated user see?
- What does a user with insufficient permissions see?
- What happens when the session expires mid-action?

### 4. Check Responsive Behavior
Test at standard breakpoints:
- **Desktop**: 1280px+
- **Tablet**: 768px - 1024px
- **Mobile**: 320px - 480px

### 5. Capture Evidence
Screenshots at each state and breakpoint. Evidence, not "looks fine."

## The Knowledge Split (Explicit)

| Lives Here (Global Skill) | Lives in Repo Runbook |
|---------------------------|----------------------|
| How to identify page states | The specific routes for this project |
| How to test forms | The selectors for this page's form fields |
| How to check responsive behavior | The test account credentials |
| How to verify auth boundaries | The seed data / fixture files |
| Evidence capture standards | Cleanup quirks for this project |

## Self-Policing Rule

When you learn a page-specific fact during QA, it goes into the repo runbook immediately. If you find yourself wanting to add a project detail to THIS skill, that's the signal it belongs in the repo instead.

## Verification

QA one page. Show both:
1. The QA findings (what passed, what failed, with evidence)
2. What got written to the repo's testing runbook (page-specific facts)
