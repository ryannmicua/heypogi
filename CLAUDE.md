# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`heypogi` is a personal kit of prompts, templates, skills, plugins, and agent
configs for AI coding tools (OpenCode, Claude Code, Codex), plus the install
scripts that stand up the machine's "Dev Stack." It is not an application —
there is no build, lint, or test suite. Most "development" here is editing
Markdown/JSON assets or PowerShell install scripts.

## Repository structure

- `src/` — the reusable "kit": prompts, templates, skills, plugins, agent
  configs, tools. Each subfolder has its own `README.md`; read it before
  adding to that folder.
  - `src/skills/` — Codex skills (`SKILL.md` + supporting files)
  - `src/agents/`, `src/prompts/`, `src/templates/`, `src/plugins/`, `src/tools/`
- `docs/` — project-management artifacts for this repo, treated as a single
  project (see "Document control" below).
- `tooling/` — setup docs (`*.md`) paired with PowerShell scripts
  (`tooling/scripts/*.ps1`) that install/verify the Dev Stack.
- `dotfiles/` — machine-level config synced into tool config dirs, notably
  `dotfiles/opencode/` (OpenCode config: `opencode.json`, `agents/`,
  `commands/`) and `dotfiles/paseo/` (Paseo config).
- `external/` — cloned source repos (OpenCode, compound-engineering,
  compound-knowledge) used as reference material by subagents; not edited
  directly, refreshed via `tooling/clone-*.ps1` scripts.
- `CONCEPTS.md` — shared domain vocabulary (glossary), accreted by
  `ce-compound` / `ce-compound-refresh`. Read this to understand
  project-specific terms like "Dev Stack," "Supervisor," "Intended State,"
  "Session-Scoped Environment" before assuming a generic meaning.
- `DEPENDENCIES.md` — external dependency inventory (runtimes, CLIs, npm
  packages, env vars).

## The "Dev Stack"

This machine runs three always-on developer tools as npm CLIs (never as
desktop-app servers): **OpenCode** (agent runtime), **OpenChamber** (web UI,
port 7777), **Paseo** (headless agent daemon + web UI, port 6767). The
single entry point for installing/verifying/repairing all three is:

```powershell
tooling/scripts/check-dev-stack.ps1 status   # read-only check (default)
tooling/scripts/check-dev-stack.ps1 install  # install/update + verify (idempotent)
tooling/scripts/check-dev-stack.ps1 fix      # repair stopped daemons/autostart/config
tooling/scripts/check-dev-stack.ps1 start|stop
```

Full behavior and every check performed: `tooling/check-dev-stack.md`. Don't
manage these tools ad hoc (e.g. hand-editing autostart registrations) —
route changes through this script or its underlying scripts in
`tooling/scripts/`. `status` checks the installed vs. latest npm version of
only these three packages (`opencode-ai`, `@openchamber/web`,
`@getpaseo/cli`), not every globally installed package; `-Quiet` skips those
npm registry lookups and only checks local runtime state.

## Environment

- `HEYPOGI_ROOT` — repo root, set by `tooling/scripts/setup-environment.ps1`.
- `OPENCODE_CONFIG_DIR` — points at `dotfiles/opencode`, so OpenCode reads
  its config from this repo rather than the default user config dir.
- Shell is PowerShell 7+ on Windows; install scripts are `.ps1` (some have
  `.sh` counterparts for cross-platform skill installers).

## Document control (`docs/`)

`docs/` treats this repo as a single tracked project:

- `docs/open_items_register.md` — canonical register for
  blockers/risks/issues/assumptions/dependencies (IDs: `RAID-###`).
- `docs/specs/`, `docs/plans/` — **unified plan** convention
  (`artifact_contract: ce-unified-plan/v1`): one artifact advances in place
  through `requirements-only` → `implementation-ready` readiness stages
  rather than splitting into separate spec/plan docs. Frontmatter
  `artifact_readiness` must match what the body actually contains.
- `docs/findings/`, `docs/reports/` — review/audit findings, status reports.
- `docs/session_digests/` — LoreSpec-format session summaries; prefer
  durable, repo-reusable learnings over transcript-like notes.
- Naming: `YYYY-MM-DD-<artifact-type>-<short-slug>.md`.
- **Note the override in `AGENTS.md`**: save to `docs/specs/` and
  `docs/plans/`, *not* `docs/superpowers/specs/` or `docs/superpowers/plans/`
  (the default Superpowers locations).

## Git workflow

- When the user says "commit" or "push," commit and push directly to the
  current branch — no branching, no PRs, unless explicitly told otherwise.
  This repo does not use a PR-based workflow by default.
- Commit messages: Conventional Commits with a scope (see `paseo.json`).

## Conventions

- Prefer small, composable assets (prompts/templates/skills) over
  giant do-everything docs.
- Add a short `README.md` when creating a new folder under `src/` or `docs/`.
- Keep `docs/` for tracking/decisions and `src/` for reusable assets — don't
  mix the two.
- External repo freshness (whether `external/*` clones are stale) can be
  checked without contacting remotes via
  `tooling/scripts/get-external-repo-status.ps1` (default window: 7 days,
  override with `-MaxAgeDays`; exits 1 if anything is due for a check).
