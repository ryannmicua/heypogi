## heypogi

`heypogi` is my personal kit of tools, prompts, templates, skills, plugins, and agents. It's meant to grow incrementally as my needs grow.

## First-time setup

1. **[`install/setup-environment.md`](install/setup-environment.md)** — sets `HEYPOGI_ROOT` and `OPENCODE_CONFIG_DIR`, writes PowerShell profile
2. **[`install/clone-opencode-source.md`](install/clone-opencode-source.md)** — clones OpenCode source for the `@opencode` subagent
3. **[`install/install-skills.md`](install/install-skills.md)** — installs local skills into your agent environment

## Plugin setup

### Compound Engineering

1. **[`install/clone-ce-source.md`](install/clone-ce-source.md)** — clones Compound Engineering source for the skills installer
2. **[`install/install-ce-skills.md`](install/install-ce-skills.md)** — installs Compound Engineering plugin skills into your agent environment

### Compound Knowledge

1. **[`install/clone-knowledge-source.md`](install/clone-knowledge-source.md)** — clones Compound Knowledge source for the skills installer
2. **[`install/install-knowledge-skills.md`](install/install-knowledge-skills.md)** — installs Compound Knowledge plugin skills into your agent environment

Restart your terminal after step 1 (or reload your profile with `. $PROFILE`).

## Repository structure

- `src/` - the reusable "kit" (prompts, templates, skills, plugins, agents, tools)
- `docs/` - project management artifacts (specs, plans, findings, reports, open items)

Start here:
- `src/README.md`
- `docs/README.md`

## What goes where

Put reusable assets in `src/`:
- `src/prompts/` - copy/paste prompts you reuse
- `src/templates/` - reusable file templates and checklists
- `src/skills/` - Codex skills (`SKILL.md` + supporting files)
- `src/plugins/` - Codex plugin scaffolds/manifests
- `src/agents/` - agent configs/profiles
- `src/tools/` - scripts/CLIs/utilities

Put change-control / project tracking in `docs/`:
- `docs/open_items_register.md` - blockers/risks/issues
- `docs/specs/` - design specs
- `docs/plans/` - implementation plans
- `docs/findings/` - reviews/findings
- `docs/reports/` - status reports
- `docs/session_digests/` - session summaries (LoreSpec)

## Conventions (lightweight)

- Prefer small, composable assets over giant "do-everything" docs.
- Add a short `README.md` in new folders so future-you remembers intent.
- Name things clearly; when unsure, optimize for searchability.
- Keep `docs/` for tracking and decisions; keep `src/` for reusable assets.

## Typical workflow

1. Add (or refine) a reusable asset under `src/`.
2. If it changes how you work, capture the rationale in `docs/` (spec/plan/decision as appropriate).
3. Keep iterating: prune duplicates, promote repeated patterns into templates/skills.
