# Document Control

This folder contains the control artifacts for managing changes to this project.

## Canonical Locations

| File | Purpose |
|------|---------|
| `open_items_register.md` | Track blockers, risks, issues |
| `specs/` | Design specifications |
| `plans/` | Implementation plans |
| `findings/` | Review findings |
| `reports/` | Status reports |
| `session_digests/` | Session summaries |

**Create the folder if it does not exist on first use**

## How to Use

### Track Open Items

For any blockers, risks, issues, assumptions, or dependencies:
- Add them to `open_items_register.md`

### Specs and Plans

For design docs and implementation plans:
- Save specs to `specs/`
- Save plans to `plans/`
- Plans must reference an approved spec

### Reviews and Reports

For findings and reports:
- Save reviews to `findings/`
- Save reports to `reports/`

### Session Digests
Session digests are past conversations, decisions, context, and issues in LoreSpec format

For session summaries:
- Save to `session_digests/`
- Preserve any explicit trail provided by the user; otherwise, link to related session digests only when clearly relevant.
- Prefer durable, repo-reusable learnings (decisions, open issues, constraints) over chatty transcript-like notes.

## Naming guidance
- Prefer `YYYY-MM-DD-<artifact-type>-<short-slug>.md` for specs, plans, findings, and reports.
- Prefer `RAID-###` entry IDs inside `open_items_register.md`.
- 
## Workflow

1. **Before working**: Check `open_items_register.md` for blockers
2. **During work**: Add new issues/risks to register
3. **After work**: Document findings in appropriate folder
