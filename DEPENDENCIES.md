# Dependencies

External dependencies required for heypogi to work.

## Core runtimes

| Dependency | Version | Purpose |
|---|---|---|
| **OpenCode** | latest | Primary agentic coding harness |
| **PowerShell 7+** | >= 7.0 | Install scripts, environment setup, shell on Windows |
| **Git** | any modern | Clone external repos, version control |
| **Node.js** | >= 18 | Runs OpenCode plugins (`@opencode-ai/plugin`) |
| **npm** | ships with Node | Installs OpenCode plugin packages |

## System CLIs

| Tool | Install | Purpose |
|---|---|---|
| **gh** (GitHub CLI) | `winget install GitHub.cli` | PR operations, status checks, repo interactions |
| **sqlite3** | `winget install SQLite.SQLite` | Query opencode-learn SQLite DB |
| **jq** | `winget install jqlang.jq` | JSON processing in shell scripts |

## npm packages

Installed via `npm install` in the project-level and config-level `package.json` files:

| Package | Version | Location |
|---|---|---|
| `@opencode-ai/plugin` | 1.17.18 | `.opencode/package.json` |
| `@opencode-ai/plugin` | 1.17.8 | `dotfiles/opencode/package.json` |

## OpenCode plugins

Loaded at runtime by OpenCode config (`dotfiles/opencode/opencode.json`):

| Plugin | Source | Purpose |
|---|---|---|
| **superpowers** | `github.com/obra/superpowers.git` | Skill system for brainstorming, planning, TDD, debugging, and more |

## External repos (cloned sources)

Cloned into `external/` for reference by OpenCode subagents:

| Repo | URL | Used by agent |
|---|---|---|
| **opencode** | `https://github.com/anomalyco/opencode.git` | `@opencode` |
| **compound-engineering** | `https://github.com/EveryInc/compound-engineering-plugin.git` | `@ce`, skills installer |
| **compound-knowledge** | `https://github.com/EveryInc/compound-knowledge-plugin.git` | Skills installer |

## Environment variables

Set by `install/scripts/setup-environment.ps1`:

| Variable | Value | Purpose |
|---|---|---|
| `HEYPOGI_ROOT` | `<repo_root>` | Repo root for scripts and tools |
| `OPENCODE_CONFIG_DIR` | `<repo_root>\dotfiles\opencode` | Custom OpenCode config directory |

## Optional / per-skill dependencies

These are only needed if you use the corresponding skill:

| Dependency | Skill | Purpose |
|---|---|---|
| **Python 3** | Various validation scripts | Run delivery validation, agent spec validation |
| **Bun** | CE plugin, opencode-learn | Package management, script runner for external repos |
| **DaVinci Resolve** | nle-assistant | Video editing via Python scripting API |
| **Chrome / CDP** | browser-qa | Browser automation for QA testing |
| **psmux** | visible-delegation | Windows terminal multiplexer (tmux equivalent). Install: `winget install psmux` — docs: https://psmux.pages.dev/ |
