# new-project-scaffold

Scaffolds a new project repository that carries the operator from a raw idea to a first working version through explicit phases, with grounding documents, testable definitions of "good", and a phase-aware `AGENTS.md` that rewrites itself as the project advances.

## When to use

- "New project", "start a project", "scaffold a project"
- Turning a raw idea into a properly grounded repository

## What it does

1. **Intake** — project name, target directory (must be new or empty), one-two sentence idea, and whether the CE plugin is part of the workflow.
2. **Preflight** — verifies the target is empty and runs `git init`; never scaffolds over existing work.
3. **Scaffolds** — creates `AGENTS.md` and `README.md` from templates, plus `.gitignore` and `tmp/` and `docs/` placeholders written inline. `VISION.md`, `STRATEGY.md`, and the planning brief are deliberately *not* scaffolded — they are operator-partnered phase outputs.
4. **Initial commit** — on request.
5. **Hands off** — summarizes and offers to begin the Phase 1 vision interview immediately.

## The four phases

| Phase | Name | Output | Exit condition |
|---|---|---|---|
| 1 | Vision | `VISION.md` (+ optional `STRATEGY.md`) | Vision written and operator-approved |
| 2 | Planning | `docs/planning-brief.md` → approved plan in `docs/plans/` | Plan approved |
| 3 | Building | First working version | Ships and is verified |
| 4 | Operating | Maintained product | Continuous; no automatic advance |

`AGENTS.md` always states the current phase and its instructions; when a phase's exit condition is met (operator-approved), the agent rewrites the file for the next phase. The scaffold installs Phase 1 as current.

## Principles baked into every phase

- **Grounding** — `VISION.md` is canonical; `STRATEGY.md` is derived and checked with the `vision-strategy-align` skill. Agents never invent requirements.
- **Testability** — "what good looks like" is written down before work happens; nothing is "done" without its stated verification passing.

## Boundaries

- Scaffolds and hands off; does not write the vision, strategy, brief, or plan itself.
- Never scaffolds into a directory with existing content.
- Companion skills: `vision-strategy-align`, CE's `ce-strategy`, `ce-brainstorm`, `ce-plan`, `ce-work`.
