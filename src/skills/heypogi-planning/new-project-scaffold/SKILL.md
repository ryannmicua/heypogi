---
name: new-project-scaffold
description: Scaffold a new project that carries an operator from idea to first working version through explicit phases — ideation, vision (and optional CE strategy), planning brief, implementation planning, building, operating. Use when the user says "new project", "start a project", "scaffold a project", or wants to turn an idea into a properly grounded repository. Produces a phase-aware AGENTS.md that evolves as the project advances.
---

# New Project Scaffold

Create a new project repository whose structure and agent instructions carry the operator from a raw idea to a first working version, with grounding documents, testable definitions of "good", and a phase-aware `AGENTS.md` that rewrites itself as the project advances.

## The model

Every scaffolded project moves through four phases. Each phase has different working instructions, one canonical output, and an operator-approved exit condition:

| Phase | Name | Output | Exit condition |
|---|---|---|---|
| 1 | Vision | `VISION.md` (+ optional `STRATEGY.md`) | Vision written and operator-approved |
| 2 | Planning | `docs/planning-brief.md` → approved plan in `docs/plans/` | Plan approved |
| 3 | Building | First working version | Ships and is verified |
| 4 | Operating | Maintained product | Continuous; no automatic advance |

`AGENTS.md` always states the current phase and its instructions; when a phase's exit condition is met (operator-approved), the agent rewrites the file for the next phase. The scaffold installs Phase 1 as current.

Two principles are baked into every phase:

- **Grounding:** `VISION.md` is the canonical product definition. `STRATEGY.md` (if used, typically via the CE plugin's `ce-strategy`) is derived from it and checked with the `vision-strategy-align` skill. Agents never invent requirements.
- **Testability:** "what good looks like" is written down before work happens — verifiable success criteria in the vision, acceptance criteria and verification methods on every plan step, tests encoding those criteria in the build. Nothing is "done" without its stated verification passing.

## Step 1 — Intake

Ask the operator (briefly; one message unless answers are unclear):

1. **Project name and target directory.** The directory must be new or empty (a bare `.git` is fine).
2. **The idea, in one or two sentences.** This seeds the README and AGENTS.md; the full vision comes later via the Phase 1 interview.
3. **Will the CE plugin be part of the workflow?** Only affects emphasis — the scaffold's phase instructions reference CE skills conditionally ("if available") either way.

Do not interview for the vision itself here. That is Phase 1's job, done in the new repo where the interview's output lives.

## Step 2 — Preflight

- Verify the target directory does not exist or is empty. If it has content, stop and ask — never scaffold over existing work.
- Create the directory and run `git init` if it is not already a repo.

## Step 3 — Write the scaffold

Create, filling `{{PROJECT_NAME}}` and `{{IDEA_ONE_LINER}}` placeholders:

| Path | Source / content |
|---|---|
| `AGENTS.md` | `templates/AGENTS.template.md` (in this skill's directory) |
| `README.md` | `templates/README.template.md` |
| `.gitignore` | At minimum: `tmp/*` and `!tmp/.gitkeep` |
| `tmp/.gitkeep` | Empty — scratch dir committed empty, contents ignored |
| `docs/plans/.gitkeep` | Empty |
| `docs/decisions/.gitkeep` | Empty |

`VISION.md`, `STRATEGY.md`, and `docs/planning-brief.md` are **not** scaffolded — they are phase outputs, created with the operator during Phases 1 and 2. Scaffolding placeholder versions would tempt agents to fill them without the operator.

## Step 4 — Initial commit

Ask the operator whether to make the initial commit. If yes, commit everything with a message like `Scaffold {{PROJECT_NAME}}: phase-aware new project`.

## Step 5 — Report and hand off

Summarize what was created and what happens next. Then offer to begin the Phase 1 vision interview immediately in this session — the scaffolded `AGENTS.md` contains the full Phase 1 instructions, so follow them from the new repo.

## Optional add-ons

Offer these only when the intake conversation suggests they are relevant; do not add by default:

- **`CONCEPTS.md`** — project vocabulary file (CE convention, consumed by `ce-brainstorm`). Useful once the project has domain terms worth pinning; premature at scaffold time.
- **Operating map** (`session-operating-map` skill) — only when the operator plans multiple parallel agent sessions.
- **CI, license, language tooling** — deliberately absent: the stack is a Phase 2 decision. Scaffolding it now would invent requirements.

## Boundaries

- This skill scaffolds and hands off; it does not write the vision, strategy, brief, or plan itself. Those are operator-partnered phase activities governed by the scaffolded `AGENTS.md`.
- Never scaffold into a directory with existing content.
- Companion skills: `vision-strategy-align` (the scaffolded AGENTS.md invokes it by name), CE's `ce-strategy`, `ce-brainstorm`, `ce-plan`, `ce-work` (referenced conditionally in phase instructions).
