---
name: heypogi
last_updated: 2026-08-11
---

# heypogi Strategy

## Target problem

AI coding agents (OpenCode, Claude Code, Codex) and the Dev Stack daemons they run in drift out of sync across the user's multiple machines because config isn't centralized in a version-controlled kit. Without one, keeping conventions, skills, and setup coherent across machines requires manually re-teaching each tool instance the same things every time, which is slow and error-prone.

## Our approach

Treat config as a versioned kit (prompts, skills, templates, agent configs) plus idempotent install scripts, so any machine converges to the same state on demand — rather than trying to keep machines live-synced or sharing runtime state.

## Who it's for

**Primary:** AI agents acting on the user's behalf (via `ce-ideate`/`ce-brainstorm`/`ce-plan` and general Claude Code/OpenCode/Codex sessions) - they're hiring heypogi to make repo-structure and convention decisions consistent with what the user would choose, without needing to ask each time.

## Key metrics

- **Config drift incidents** - count of times a machine behaves differently from another (inconsistent agent answers, missing skill, stale dotfile) traced back to heypogi being out of sync; noticed informally, logged in `docs/open_items_register.md` if it recurs. Should trend toward zero.
- **Time-to-working-machine** - how long from fresh clone to `dev-stack.ps1 status` reporting fully green, and whether any manual/undocumented fix was needed. Tracked per new-machine setup.
- **Dev Stack version staleness** - how far installed `opencode-ai`/`@openchamber/web`/`@getpaseo/cli` fall behind latest before being noticed and fixed, per `dev-stack.ps1 status` output.

## Tracks

### The kit (src/)

Prompts, skills, templates, agent configs, and plugins - used by OpenCode, Claude Code, and Codex - all configured the same in all machines/environments managed by heypogi.

_Why it serves the approach:_ this is the versioned half of "kit + installer" - what defines how agents behave once a machine is set up.

### Dev Stack install/repair (tooling/)

The idempotent PowerShell scripts (`dev-stack.ps1` and friends) that install, verify, and repair OpenCode, OpenChamber, and Paseo on any machine.

_Why it serves the approach:_ this is the "installer" half - what makes convergence-on-demand possible instead of manual setup.

### Dotfiles/machine config (dotfiles/)

Machine-level config synced into each tool's native config dir (e.g. `OPENCODE_CONFIG_DIR`) so tool-native settings are version-controlled too, not just heypogi's own assets.

_Why it serves the approach:_ without this, tool-native settings would still drift even if the kit itself were reproducible - this closes that gap.
