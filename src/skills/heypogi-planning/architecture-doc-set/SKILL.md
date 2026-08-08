---
name: architecture-doc-set
description: Create a living, multi-file system architecture and design documentation set for an existing codebase, so a reader can understand how the system works and why it is designed this way without going through the codebase. Use when the user asks for "architecture documentation", "design documentation", "system architecture doc", "how the system works" documentation, or wants a lookup-able, update-able design reference for a shipped or in-progress feature. Produces a cross-linked doc set under docs/architecture/ with an index, system overview, design decisions, state machine (when applicable), data/security, and mechanism docs — each with verified code citations, an authority hierarchy, and maintenance rules. Not for writing user guides, tutorials, or quickstarts (use write-docs-diataxis for those), and not for capturing problem-solving history (use ce-compound).
---

# Architecture Doc Set

Create a living, multi-file system architecture and design documentation set for an existing codebase. The goal: a reader can understand how the system works and why it is designed this way **without going through the codebase**, and the set is structured so it stays current as the system evolves.

The set describes the **current design**. It is not a user guide, not a tutorial, and not a problem-history store. It states how the system is now and links to history where history explains the present.

## The model

Every architecture set has one index file and a small number of content files. The index is the maintenance contract; the content files are the lookup surface.

| File | Role |
|---|---|
| `docs/architecture/README.md` | **Index + maintenance contract**: what the set covers, reading order, authority hierarchy, relationship-to-other-docs boundary, maintenance rules (change → touch matrix), last-verified convention, conflict log. Always created. |
| `system-overview.md` | One page: what the system is, the layered/component architecture, the end-to-end primary flow, and the core invariants. Always created. |
| `design-decisions.md` | The settled design decisions distilled: decision, rationale, where enforced (code citation), status including supersessions. Always created. |
| `state-machine.md` | States, transitions, terminal/recovery paths, and how states map to outcomes/exit codes. Created when the system has a lifecycle. |
| `data-and-security.md` | Data model, input handling, security guarantees (what is untrusted, what may never be emitted). Created when data flows through untrusted input or security boundaries exist. |
| `<mechanism>.md` | One file per cluster of load-bearing primitives (e.g. filesystem-and-projection.md for a storage layer). Created as the domain requires — the set is multi-file by design, sized to the system. |

Two principles hold for every file:

- **Verified, not remembered.** Every architectural claim carries a code citation (`src/...:NNN`) and/or a design-authority citation (`PLAN:NNN`), checked against the tree while writing — never asserted from memory or from conversation.
- **Current design, linked history.** Where a topic also exists in a problem-history store (e.g. `docs/solutions/`), this set states the current design and links to the history — it never re-narrates incidents, root causes, or fix stories.

## Step 1 — Intake

Ask the operator (briefly; one message unless answers are unclear):

1. **Scope** — the feature, module, or system to document (path or name). If unclear, default to the whole repository and say so.
2. **Design authority** — where the settled design decisions live (a plan under `docs/plans/`, ADRs, a design doc). If none exists, say that the set will derive decisions from the code and mark them "derived from code" rather than inventing a false authority.
3. **Existing verified docs** — any behavioral explanation docs (e.g. a how-it-works page) whose diagrams and claims can be reused after re-verification.

Do not interview for the architecture itself here. That is the investigation's job, done in the repo.

## Step 2 — Grounding

Read, in order:

1. `AGENTS.md` — repo conventions, artifact roots, required reading.
2. `CONCEPTS.md` (if present) — the vocabulary authority. The set uses its terms exactly; the set never invents terms.
3. The design authority (plan/ADRs) — the decisions to distill.
4. Frozen contract surfaces (e.g. `contracts/`) — the tie-breaker for disputes.
5. Existing verified behavioral docs — candidates for reuse.
6. `VISION.md` / product docs — only as needed for the overview's framing.

**Terminology discipline.** While grounding, check for concept-vs-filename mismatches (the concept "marker" vs the file `manifest.json` is the canonical example). If the operator-facing vocabulary and an artifact name disagree and the operator has not already settled a convention, surface it as an intake question — never silently pick a side. When settled, apply the **pairing convention**: every first mention of the concept in each file pairs the concept and the filename in one breath ("the marker — the manifest file at `.workstream/manifest.json`"); subsequent mentions may use the concept alone.

## Step 3 — Set design

Before writing, design the set on paper:

1. Decide the content-file list per the model (which mechanism files, whether state-machine/data-and-security apply).
2. Decide the **authority hierarchy** and state it in the README. Default precedence: frozen contracts → design authority (plan/ADRs) → code → documentation. When documents disagree, the lower document is wrong, not the higher one.
3. Decide the **boundary table** (relationship to other documentation): current design (this set), problem history (solutions store), frozen authority (contracts), design origin (plans), operator-facing docs (usage), vocabulary (CONCEPTS.md). One row each, with the boundary rule.
4. Confirm the plan with the operator if the set shape is unusual (e.g. no lifecycle → no state-machine.md). If the shape follows the standard model, proceed without asking.

## Step 4 — Write

Write the files in this order (index last, so it can reference the finished content):

1. `system-overview.md` — what the system is (one screen), the layered/component architecture with each component's one-line responsibility, the end-to-end primary flow (diagram encouraged: mermaid or ASCII, GitHub-renderable), and the core invariants (the rules that must never break, each with an enforcement citation).
2. `design-decisions.md` — one entry per settled decision: decision (one sentence), rationale (why), enforced-at (code citation), status (including supersessions — e.g. a path or value later changed by a dated operator decision, with the supersession named and linked).
3. `state-machine.md` (when applicable) — states, transitions, terminal vs recovery, the primary lifecycle flows, and the mapping to outcomes/exit codes.
4. `<mechanism>.md` files — each load-bearing primitive cluster: what it guarantees, how it works, the failure/fail-closed behavior, and the code anchors.
5. `data-and-security.md` (when applicable) — the data model, what input is untrusted and how it is bounded, and the security guarantees (what may never be emitted, what fails closed).
6. `README.md` — index, reading order, authority hierarchy, boundary table, maintenance rules (see Step 6), last-verified convention, conflict log (empty table).

**Writing rules:**

- **Cite both sides.** Where a decision's rationale and enforcement both matter, cite the design authority (`PLAN:NNN`) and the code (`src/...:NNN`) side by side.
- **Reuse, don't re-derive.** Existing verified diagrams and claims can be copied into this set — after re-verifying every anchor against the tree.
- **Reuse of history is a link, not a paragraph.** If a paragraph would re-narrate an incident documented elsewhere (a bug fix, a drift story, a stack-selection debate), replace it with a one-line current-design statement plus a link.
- **Diagrams must be standalone-readable** — labels on every node, legend where color carries meaning, in a format that renders in the repo (mermaid, ASCII, or a referenced image).
- **No scope creep.** The set documents the current design; it does not propose redesigns, flag code-quality issues (unless they contradict a documented decision — that is a conflict-log entry), or duplicate operator-facing guides.

## Step 5 — Verify

Before committing, run the mechanical gates:

1. **Anchor check** — every `file:line` citation resolves: the file exists and the named symbol is at or near the cited line. Spot-check at least 30 anchors by opening the cited lines; more for larger sets.
2. **Link check** — every relative link between the set's files (and to linked docs) resolves.
3. **Terminology grep gates** — grep the set for: stale/old paths (must be zero), forbidden terms (must be zero), and the pairing-convention check (every first mention of the concept pairs the filename; no standalone use of a filename-as-concept).
4. **Validator** — if the CE plugin's `validate-doc-claims.py` is available, run it per file and adjudicate flags (fix, annotate, or confirm-intentional with a durable note — e.g. workspace-relative contract paths are false positives, but repo paths, SHAs, and links must resolve).
5. **Duplication check** — grep for any paragraph that substantially re-narrates a solutions-store incident; replace with a link if found.
6. **Contract-vs-code conflict scan** — spot-check the boundary claims (exit codes, state/outcome alignment, vocabulary, paths). Genuine conflicts go in the README conflict log, never silently resolved.

## Step 6 — Maintenance rules (bake into the README)

The set stays current only if the README tells future agents what to touch when. Include a change → touch matrix:

| Change | Touch | Also check |
|---|---|---|
| A dated operator decision changes a design value (path, cap, rule, term) | `design-decisions.md` — update the affected decision's status line | Record the supersession **first** per the governance convention (dated decision digest before edits; name what is superseded; leave historical records historical); add a maintenance note linking the digest |
| The state machine changes | `state-machine.md` | `system-overview.md` (invariants), README index; change the authoritative protocol/state table first |
| The schema/data model changes | `data-and-security.md` | `design-decisions.md` (versioning/bounds decisions); frozen surface changes require a new surface version, not an edit, unless the plan permits |
| New commands/flows land | `system-overview.md` (flow + layer descriptions) | README index if scope changes; state-machine if new outcomes/exit codes enter |

**Last-verified convention:** every file's frontmatter carries `verified: YYYY-MM-DD`. When a maintainer re-verifies citations against the tree, update the date. A `verified` date older than the last tree change means the file needs re-verification.

**Conflict log:** the README holds an empty conflict table. Rows are added (date, conflict, resolution task) whenever a genuine contract/plan/code disagreement surfaces during maintenance. Documenting a conflict is the maintenance task; resolving it is a separate, operator-gated decision.

## Step 7 — Deliver

- One atomic commit containing only the new set (repo-style message, e.g. `docs(architecture): add system architecture and design set for <feature>`).
- Do not push or open a PR unless asked.
- Report per file: path, what it covers, key anchors; the verification results (anchors checked, grep gates, validator flags and adjudications); and any conflicts found (or "none").

## What It Is Not

- **Not a user guide.** Installation, quickstarts, tutorials, how-tos, references for operators belong in a Diataxis-structured usage set (`write-docs-diataxis`).
- **Not problem history.** Incidents, root causes, fixes, and prevention belong in the solutions store (`ce-compound`).
- **Not a code review.** The set records the design as it is; it does not propose improvements. A documented decision that the code contradicts is a conflict-log entry, not a refactor request.
- **Not a planning artifact.** The set describes the shipped/current state; plans describe intent and record the decisions this set distills.

## Quality Bar

The set is done when a reader unfamiliar with the codebase can answer, from the set alone: what the system does, how it is shaped, why it is shaped that way, how the primary flow behaves end-to-end, what the invariants are, and what to touch when the design changes — and every claim they rely on carries a verified citation.
