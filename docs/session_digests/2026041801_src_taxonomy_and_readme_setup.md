---
lorespec: "0.1"
id: "2026041801"
date: "2026-04-18"
source: "codex"
topic: "Set up a simple src/ taxonomy and a root README for the heypogi kit repo."
tags: [heypogi, repository-structure, taxonomy, documentation]
classification:
  type: technical
  secondary_type: drafting
  domains: [developer-productivity, knowledge-management]
  value: medium
trails: [heypogi_repo_structure]
---

## Session Arc

### Started
The user described `heypogi` as a personal kit of tools, prompts, templates, skills, plugins, and agents that will be built out over time.

### Pivots
- The user asked to "add a simple taxonomy under src/." and clarified that "the docs/ folder is for project management".

### Ended
A minimal `src/` taxonomy was created and the root `README.md` was written to explain `src/` vs `docs/` responsibilities.

## ARTIFACTS

### A1 - `src/` taxonomy skeleton (folders + readmes)
**Summary:** Added a simple, trackable folder taxonomy under `src/` with short README placeholders to keep intent clear and make future additions consistent.

**Contents:**
- Folders created: `src/prompts/`, `src/templates/`, `src/plugins/`, `src/tools/`
- New docs: `src/README.md` plus per-folder `README.md` files

**Episodic source (excerpt):**
> "help me add a simple taxonomy under src/. the docs/ folder is for project management"

### A2 - Root repository `README.md`
**Summary:** Wrote a root README that positions `heypogi` as an incrementally-grown kit repo and clearly separates reusable assets (`src/`) from project management artifacts (`docs/`).

**Episodic source (excerpt):**
> "Write me this README.md according to your suggestion."

## DECISIONS

### D1 - Separate reusable kit assets from project management artifacts
- **Decision:** Use `src/` for reusable assets (prompts/templates/skills/plugins/agents/tools) and reserve `docs/` for project management artifacts (specs/plans/findings/reports/open items/session digests).
- **Issue:** Where should reusable working assets vs management/tracking docs live to avoid mixing concerns as the repo grows?
- **Positions:**
  - A) Put everything under `docs/`
  - B) Split: `src/` for reusable kit assets, `docs/` for project management
- **Arguments:**
  - A) Pros: one place to look; Cons: mixes reusable artifacts with change-control docs; harder to keep taxonomy stable.
  - B) Pros: keeps the "kit" directly usable; keeps project tracking separate; scales better as more assets accumulate.
- **Warrant:** Clear boundaries prevent entropy: when everything is mixed, future maintenance and searchability degrade quickly.
- **Qualifier:** in this case
- **Status:** settled

**Episodic source (excerpt):**
> "the docs/ folder is for project management"

## PATTERNS

### P1 - Minimal taxonomy with "tracked" placeholders
**Scope:** local (repo organization convention)

**Pattern:** When introducing new top-level taxonomy, include a short `README.md` in each folder so the directory is tracked and its intent is discoverable later.

**Steps:**
1. Create the folder(s) under the appropriate top-level root (here: `src/`).
2. Add a small `README.md` that defines: what belongs here, suggested sub-structure, and any exclusions.
3. Reference these from the repo root README so future additions follow the same mental model.

**Episodic source (excerpt):**
> "help me add a simple taxonomy under src/."

## Connections

- D1 -[led_to]-> A1
- D1 -[led_to]-> A2
- P1 -[informed_by]-> D1

## Trail Updates

- Created trail: `heypogi_repo_structure`

