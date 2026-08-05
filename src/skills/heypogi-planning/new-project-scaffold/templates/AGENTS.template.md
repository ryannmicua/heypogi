# AGENTS.md

This file is phase-aware: it tells any agent how to work in this repository right now, and it is expected to rewrite itself as the project advances. The project moves through phases — each phase has different working instructions, and when a phase's exit condition is met and the operator approves, this file is rewritten to describe the next one.

## Current phase

**Phase 1 — Vision**

The idea: {{IDEA_ONE_LINER}}

The product vision is not yet written. The first job of any agent session in this repository is to help the operator turn this idea into an approved `VISION.md`.

## The phases

| Phase | Name | Output | Move to next when |
| --- | --- | --- | --- |
| 1 | Vision | `VISION.md` (+ optional `STRATEGY.md`) | Vision is written and operator-approved |
| 2 | Planning | Planning brief, then approved plan(s) in `docs/plans/` | Plan is approved |
| 3 | Building | First working version | Ships and is verified |
| 4 | Operating | Maintained product | Continuous; no automatic advance |

## Phase 1 instructions (current)

- Interview the operator to write `VISION.md` — one question at a time, in the operator's own language. Never invent product answers.
- Structure the vision with these sections: **Problem** (what's broken, for whom), **Who it's for**, **What it does** (behavior, boundaries of authority), **What success looks like** (success criteria that are verifiable in spirit — these become the definition of "good" for every later phase), **Out of scope** (explicit exclusions for the first version), **Constraints** (hard invariants any design must respect).
- If the operator wants a strategy document (recommended when the CE plugin is available): run `ce-strategy`, answering its interview from `VISION.md`'s content — do not improvise new product answers — then run the `vision-strategy-align` skill on the result and report the verdict.
- When the operator approves the vision, rewrite this file: set **Current phase** to **Phase 2 — Planning**, replace the idea line with a one-paragraph summary of the approved vision, and mark the Phase 2 instructions as current.

## Phase 2 instructions (to be installed on advancement)

- Read `VISION.md` first; it is the canonical product definition. Then read `STRATEGY.md` (if present) for derived strategic framing. If they conflict, follow `VISION.md` and surface the drift to the operator.
- Before planning, write `docs/planning-brief.md`: what the vision already decides (constraints not to re-litigate), the open decisions in dependency order — each with the question, why it matters, and what it feeds — a suggested session sequencing, and exit criteria. The brief frames questions; it decides nothing.
- Brainstorm the architecture-shaping decisions with the operator (`ce-brainstorm` if available), then produce implementation plan(s) in `docs/plans/` (`ce-plan` / the unified-plan convention if available).
- Every plan step must state acceptance criteria and a verification method — this is how later agents know what good looks like. A plan step without a verification method is not implementation-ready.
- After the operator approves the plan, rewrite this file: set **Current phase** to **Phase 3 — Building**, summarize the plan, and mark the Phase 3 instructions as current. The approved plan supersedes the planning brief; archive or delete the brief.

## Phase 3 instructions (to be installed on advancement)

- Execute the approved plan sequentially (`ce-work` if available), one step at a time, verifying each step against its stated acceptance criteria before moving on.
- Write tests alongside features; tests encode the plan's acceptance criteria. Nothing is "done" without its stated verification passing.
- Record significant technical decisions in `docs/decisions/` — one short file per decision: context, decision, consequences.
- Keep `VISION.md` and the plan in sync; surface drift to the operator rather than silently changing direction.
- After the first working version ships and is verified, rewrite this file: set **Current phase** to **Phase 4 — Operating**, and mark the Phase 4 instructions as current.

## Phase 4 instructions (to be installed on advancement)

- The product is live. Treat every change as a change to a maintained system: verify, test, and document.
- Keep `VISION.md` current; anything that changes the vision should be recorded there before implementation, followed by a `vision-strategy-align` check if `STRATEGY.md` exists.
- Keep recording significant decisions in `docs/decisions/` and durable learnings where the project's conventions put them.

## Working rules (all phases)

- Only the operator approves moving to the next phase. Rewrite this file only when a phase's exit condition is met.
- The operator is the sole authority on scope and vision. Never invent requirements or expand scope without asking.
- `VISION.md` is the canonical product definition; `STRATEGY.md` is derived from it and must not conflict with it, introduce new scope, or restate product behavior. If they conflict, `VISION.md` governs — surface the drift to the operator; never silently edit either document to resolve it.
- After either `VISION.md` or `STRATEGY.md` changes, run the `vision-strategy-align` skill and report the verdict before continuing with planning or implementation work.
- When running `ce-strategy` in this repo, answer its interview from `VISION.md`'s content — do not improvise new product answers — and run `vision-strategy-align` on the result.
- Nothing is "done" without a stated, passing verification. Definitions of good live in documents (vision success criteria, plan acceptance criteria, tests) — not in any agent's memory.
- Use `tmp/` for throwaway scratch; never commit anything in it (it is git-ignored).
- Save durable artifacts in the repository root or in `docs/`.
- When in doubt about what the operator wants, ask — one question at a time.
