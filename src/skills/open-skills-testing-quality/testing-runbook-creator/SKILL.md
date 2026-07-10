---
name: testing-runbook-creator
description: Capture testing knowledge as durable repo-local runbook entries so future sessions inherit what was learned. Use during ANY testing, verification, smoke-testing, QA, or debugging activity -- not just when explicitly asked for a runbook.
---

# Testing Runbook Creator

Testing discoveries must not die in chat. Whenever you test, verify, smoke-test, QA, or debug anything in a repo, leave behind a runbook entry so session twenty inherits what sessions one through nineteen learned.

## Trigger Conditions

- ANY testing or verification activity in a repo (not just when user says "runbook")
- Smoke-testing a feature
- QA or debugging a workflow
- Verifying a fix
- User manually navigating and testing something

## Runbook Location

Create or maintain at `docs/testing-runbook.md`. If the project has an established testing docs location, use that instead (ask on first run).

## Entry Format

```markdown
### <Page / Workflow / Feature Name>

**Last tested**: YYYY-MM-DD
**Tested by**: <agent/session identifier>

**How to test (step by step)**:
1. Navigate to <route/URL>
2. <action>
3. Verify: <expected result>

**Safe actions**:
- <actions that do not modify real data, send emails, charge money>

**Destructive actions**:
- <actions that DO modify real data, send emails, charge money, etc.>
- Never perform these without explicit user confirmation

**Setup / seed data required**:
- <test accounts, fixture data, env vars, database state>

**Cleanup steps** (if any):
- <how to undo what testing did>

**Verification commands**:
```
<exact command>  # Expected: <output>
<exact command>  # Expected: <output>
```

**Gotchas**:
- <anything that tripped you up or might trip the next session>
```

## Read-First Rule

Before testing anything, check whether the runbook already covers it. If an entry exists, follow the existing recipe. Don't rediscover.

## Update Rule

When reality differs from the runbook -- a route changed, a selector broke, a test account expired -- fix the runbook in the same session. Stale runbooks are worse than no runbook.

## Record as You Go

Write discoveries immediately, not as an end-of-session afterthought. The best runbook entry is written while fingers are still on the keys.

## Verification

Smoke-test one workflow and show the runbook entry it produces. The next agent session should be able to repeat the test without asking questions.
