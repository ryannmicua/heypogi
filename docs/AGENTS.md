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

### Specs and Plans (unified-plan convention)

This repository uses the CE **unified plan** artifact (`artifact_contract: ce-unified-plan/v1`), which advances through readiness stages in place rather than splitting specification and plan into separate artifacts:

- Save unified plans to `plans/` (per the AGENTS.md override, not `docs/superpowers/plans/`).
- A single unified plan advances through two readiness stages:
  - `requirements-only` — the **specification stage**: Product Contract only (Goal Capsule, Actors, Requirements, Lifecycle Invariants, Key Flows, Acceptance Examples, Success Criteria, Scope Boundaries, Outstanding Questions). No Planning Contract, Implementation Units, Verification Contract, or Definition of Done is required at this stage.
  - `implementation-ready` — the **executable stage**: the same artifact is deepened with a Planning Contract (Key Technical Decisions, High-Level Technical Design, contracts), Implementation Units, Verification Contract, and Definition of Done.
- One unified plan is BOTH the approved specification and the implementation plan at different readiness stages — a separate legacy spec doc is NOT required when the artifact carries `product_contract_source: ce-brainstorm` (or `legacy-requirements`) and is advanced in place.
- Stable requirement/actor/flow/acceptance IDs (R/A/F/AE) and implementation-unit IDs (U) are preserved across deepenings; scope changes that defer units are recorded in the Planning Contract's "Product Contract preservation" note, not by deleting stable IDs.
- Frontmatter `artifact_readiness` must match the body: a body containing a Planning Contract + Implementation Units + Verification + DoD must be labeled `implementation-ready`, not `requirements-only`.

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
