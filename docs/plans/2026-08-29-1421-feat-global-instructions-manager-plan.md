---
title: Global Instructions Manager - Plan
type: feat
date: 2026-08-29
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** A single source file (`dotfiles/instructions/RULES.md`) is copied to each installed AI coding agent's expected global instructions location, with detection of which agents are present, an interactive picker for the user to select targets, diff preview before overwriting, automatic backups, colored status output, and safe handling of existing files.
- **Means:** Bash and PowerShell scripts that detect agents via `command -v`, default to an interactive scan-then-select flow, offer `--auto` for non-interactive batch install on all detected agents, show diffs before overwrite prompts, back up existing files, support `--status`/`--dry-run`/`--remove`/`--source`/`--json` modes, copy the source to per-agent destinations, and validate source input. OpenCode uses a config reference instead of a copy. (KTD1, KTD2, KTD3, KTD4)
- **Execution profile:** Lightweight — 3 implementation units, no external dependencies, no cross-system impact.
- **Stop conditions:** All detected agents have rules installed or removed per user intent; OpenCode config references the source; scripts are documented.

## Product Contract

### Summary

A cross-platform install script copies a source rules file to each AI coding agent's global instructions file. Each agent expects a different filename at a different path. The script auto-detects which agents are installed (including version display) and defaults to an interactive scan-then-select flow so the user can enable or disable individual agents before proceeding. An `--auto` flag skips the interactive selection and installs to all detected agents (or force-specified agents) without prompts. Before overwriting, the script shows a diff and offers one-click apply-to-all. Existing files are backed up automatically. Additional modes include `--status` (read-only state overview), `--dry-run` (preview without changes), `--remove` (uninstall instructions), `--source` (custom source file), and `--json` (machine-readable output). The source file is validated before any operations begin. Colored output highlights status at a glance.

### Problem Frame

The user operates multiple AI coding agents (Codex, Claude Code, agy/Antigravity, OpenCode) across multiple machines. Each agent reads global instructions from a different file and path. Without a manager, the user must manually copy and maintain the same content in 3-4 locations per machine. This creates drift risk and makes updates tedious.

### Requirements

**Agent Detection**

- R1. The script detects Codex via `command -v codex`.
- R2. The script detects Claude Code via `command -v claude`.
- R3. The script detects agy (Antigravity CLI) via `command -v agy`.
- R4. The script detects OpenCode via `command -v opencode`.
- R5. Detection is best-effort: a missing binary means the agent is skipped, not an error.

**File Installation**

- R6. Codex: copy `dotfiles/instructions/RULES.md` → `~/.agents/AGENTS.md`.
- R7. Claude Code: copy `dotfiles/instructions/RULES.md` → `~/.claude/CLAUDE.md`.
- R8. agy: copy `dotfiles/instructions/RULES.md` → `~/.gemini/GEMINI.md`.
- R9. OpenCode: add `"instructions": ["../instructions/RULES.md"]` to `dotfiles/opencode/opencode.json` (config reference, no copy).

**Existing File Handling**

- R10. If the destination does not exist, copy silently and report "installed".
- R11. If the destination exists and is identical to the source, skip and report "up to date".
- R12. If the destination exists and differs from the source, prompt the user: `[o]verwrite, [s]kip, [q]uit`.
- R13. The `--create-dest` flag creates missing parent directories (`~/.agents/`, `~/.claude/`, `~/.gemini/`) with user approval before copying.

**Force Flags**

- R14. `--codex`, `--claude`, `--agy`, `--opencode` flags force-install for specific agents even if not detected.
- R15. In `--auto` mode, only detected agents (or force-flagged agents) are targeted.

**Interactive Mode**

- R16. By default, the script runs a two-phase scan-then-select flow: first detect all supported agents and show their status, then present a checklist for the user to enable/disable before proceeding. The `--auto` flag skips this flow and targets all detected agents directly.
- R17. The checklist shows each agent name, its detection status (installed / not found), and the current selection state. Detected agents default to selected; non-detected default to deselected.
- R18. The user confirms the selection to proceed, or cancels to abort. Only selected agents are targeted.
- R19. Force flags (`--codex`, `--claude`, etc.) pre-select their agent in the checklist regardless of detection status. The default scan-then-select flow still runs; the forced agent is just pre-checked.

**Output**

- R20. The script prints a summary: which agents were detected, which files were installed/skipped/updated, which were skipped due to non-detection.

**Status and Dry-Run**

- R21. The `--status` flag prints a read-only overview of each agent: detection status, installed version (via `<binary> --version`), destination file state (missing / identical / differs / unknown), and color-coded health. No files are modified.
- R22. The `--dry-run` flag runs the full install logic but replaces all writes and prompts with a preview of what would happen (which files would be copied, which overwritten, which skipped). Exit behavior matches the real run.

**Diff Preview**

- R23. Before the `[o]verwrite, [s]kip, [q]uit` prompt (R12), the script shows a unified diff between the existing destination file and the source. The diff is limited to 50 lines; if longer, a truncation notice is shown.

**Apply-to-All**

- R24. The overwrite prompt is extended to: `[a]pply to all, [o]verwrite, [s]kip, [q]uit`. Selecting `a` applies the user's choice (overwrite or skip) to all remaining differing files without further prompts.

**Backup**

- R25. Before overwriting an existing file, the script saves it as `<destination>.bak` (e.g., `~/.claude/CLAUDE.md.bak`).
- R26. If a `.bak` file already exists from a prior run, it is overwritten silently (only the most recent backup is kept).

**Remove / Uninstall**

- R27. The `--remove` flag uninstalls instructions from each detected (or force-specified) agent by deleting the destination file.
- R28. `--remove` prompts for confirmation before deleting each file. A `--force` sub-flag skips confirmation.
- R29. `--remove` with `--json` emits the removal status per agent.

**Colored Output**

- R30. Status tables and summaries use ANSI color when stdout is a terminal: green for installed/up-to-date, yellow for differs/outdated, red for not found/error, cyan for info. Color is disabled when stdout is not a TTY or when `NO_COLOR` is set.

**Source Validation**

- R31. Before any operations, the script validates that the source file exists, is a regular file, and is non-empty. If validation fails, the script exits with an error message and exit code 1.

**Configurable Source**

- R32. The `--source <path>` flag overrides the default source file (`dotfiles/instructions/RULES.md`). The path must be absolute or relative to the repo root.

**JSON Output**

- R33. The `--json` flag emits a JSON object to stdout with per-agent results: `{ "agents": [{ "name": "codex", "detected": true, "version": "0.98.0", "action": "installed", "destination": "~/.agents/AGENTS.md" }, ...] }`.
- R34. `--json` suppresses all other output (no colored tables, no prompts). It is incompatible with the default interactive mode (error if both are attempted); use `--json --auto` for machine-readable output without prompts.

**Agent Version Display**

- R35. The `--status` table and `--json` output include each detected agent's version, obtained by running `<binary> --version` (first line, trimmed). If the version command fails, the version field is `"unknown"`.

### Scope Boundaries

**In scope:**
- Bash script (`tooling/instructions/install-instructions.sh`)
- PowerShell script (`tooling/instructions/install-instructions.ps1`)
- OpenCode config modification (`dotfiles/opencode/opencode.json`)
- Documentation (`tooling/instructions/README.md`)
- `--status`, `--dry-run`, `--remove`, `--source`, `--json`, `--auto` modes
- Diff preview, apply-to-all, backup, colored output, source validation, version display

**Out of scope:**
- Auto-sync or file watching — user re-runs the script after editing RULES.md
- Per-project instructions (only global)
- Symlink support (user chose copy)
- Agent-specific content differentiation (one source file for all)
- Multiple backup rotation (only most recent `.bak` is kept)
- Interactive mode combined with `--json` (mutually exclusive; use `--json --auto` instead)

## Planning Contract

### Key Technical Decisions

- KTD1. **Single source, multiple destinations.** One `RULES.md` file is copied to each agent's expected filename. This avoids content drift between agents but means all agents receive identical instructions. (session-settled: user-directed — chosen over per-agent source files: simpler maintenance)

- KTD2. **OpenCode uses config reference, not copy.** OpenCode's `instructions` array in `opencode.json` references `../instructions/RULES.md` directly. No copy is needed; changes propagate immediately when the repo is the working directory. (session-settled: user-directed — chosen over copying to `~/.config/opencode/`: avoids duplication, leverages existing `OPENCODE_CONFIG_DIR` setup)

- KTD3. **Backup as `.bak`, single rotation.** Before overwriting, the existing file is saved as `<destination>.bak`. Only the most recent backup is kept; prior `.bak` files are overwritten silently. This avoids unbounded disk usage while providing a safety net. (session-settled: user-directed — chosen over timestamped backups: simpler, sufficient for a small config file)

- KTD4. **ANSI color gated on TTY and `NO_COLOR`.** Color is used when stdout is a terminal and `NO_COLOR` is not set. `--json` always disables color. This follows the `NO_COLOR` convention (https://no-color.org/). (session-settled: convention-aligned — no alternatives considered)

### Assumptions

- The repo is cloned at the same relative path on each machine (or the script resolves its own location via `BASH_SOURCE`).
- `~/.agents/`, `~/.claude/`, `~/.gemini/` are the correct parent directories for each agent's global instructions on all target platforms.
- The user is willing to re-run the script after editing `RULES.md` (no auto-sync).

## Implementation Units

### U1. Bash install script

- **Goal:** Create `tooling/instructions/install-instructions.sh` that detects agents and copies RULES.md to each destination.
- **Dependencies:** None.
- **Files:** `tooling/instructions/install-instructions.sh`
- **Approach:**
  - Resolve repo root via `BASH_SOURCE`.
  - Define agent table: name, binary, source path, destination path.
  - Source validation (R31): check source exists, is a file, is non-empty before any operations. Default source is `dotfiles/instructions/RULES.md`; `--source` overrides (R32).
  - Colored output (R30): detect TTY and `NO_COLOR`; define `RED`, `GREEN`, `YELLOW`, `CYAN`, `RESET` helpers; disable when not TTY or `NO_COLOR` set.
  - Mode dispatch: `--status` → status_only(); `--dry-run` → dry_run(); `--remove` → remove_mode(); `--auto` → install_mode(); default → interactive_mode().
  - `--status` (R21, R35): for each agent, run detection, get version via `<binary> --version`, check destination state, print color-coded table. Exit 0.
  - `--dry-run` (R22): same as install_mode but replace `cp` with echo of what would happen; replace prompts with diff preview. Exit 0.
  - `--remove` (R27-R29): for each agent, check destination exists, prompt confirmation (or `--force` to skip), delete file. Emit results.
  - `--json` (R33-R34): collect results into a JSON structure (using `printf` and heredoc, no `jq` dependency); print at end; suppress all other output. Error if combined with default interactive mode (use `--json --auto` instead).
  - Install mode:
    - For each agent: check `command -v` (or force flag), check destination state.
    - If destination differs (R12, R23): show unified diff (limited to 50 lines via `diff --color=auto`), then prompt `[a]pply to all, [o]verwrite, [s]kip, [q]uit` (R24).
    - Before overwrite (R25-R26): save existing as `<dest>.bak`.
    - If destination missing: copy silently, report "installed".
    - If identical: skip, report "up to date".
  - `--auto` (non-interactive): same as install_mode but skips the interactive selection; targets all detected agents (or force-flagged agents) directly.
  - Default (interactive mode):
    - Phase 1 — Scan: run detection + version on all agents, print color-coded table with name, version, status, default selection.
    - Phase 2 — Select: prompt user to toggle agents by number or confirm defaults.
    - Respect force flags as pre-selections (R19).
    - On confirm, proceed with only selected agents. On cancel, exit 0.
  - `--create-dest` creates missing parent dirs before copy.
  - Exit 0 on success, 1 on error, 2 on user abort.
  - Follow existing conventions from `tooling/skills/install-skills.sh` (prompt pattern, `--create-dest` flag, summary output).
- **Test scenarios:**
  - Agent detected, destination missing → copies, reports "installed".
  - Agent detected, destination identical → skips, reports "up to date".
  - Agent detected, destination differs → shows diff, prompts; user chooses overwrite → backs up, copies.
  - Agent detected, destination differs → shows diff, prompts; user chooses skip → skips.
  - Agent detected, destination differs → shows diff, prompts; user chooses quit → exits.
  - Agent detected, destination differs → shows diff, user chooses apply-to-all → applies to all remaining.
  - Agent not detected → skips silently (unless force flag).
  - `--create-dest` with missing parent → creates dir, copies.
  - No `--create-dest` with missing parent → error with instructions.
  - Source file missing → error (R32).
  - Source file empty → error (R32).
  - `--source /nonexistent` → error.
  - `--status` → shows color-coded table with versions, no modifications.
  - `--dry-run` → shows preview of all actions, no modifications.
  - `--remove` with confirmation → deletes destination files.
  - `--remove --force` → deletes without confirmation.
  - `--json` → emits valid JSON, no other output.
  - `--json --auto` → emits valid JSON, no other output.
  - `--json` with default interactive → error, mutually exclusive.
  - Default (interactive) with detected agents → shows table, defaults detected to selected, proceeds on confirm.
  - Default (interactive) with no agents detected → shows empty selection, user cancels, exits 0.
  - Default (interactive) with force flag → forced agent pre-selected even if not detected.
  - Default (interactive) user deselects all → proceeds with nothing, reports "no agents selected".
  - `--auto` with detected agents → installs to all detected agents without prompts.
  - `--auto` with force flags → installs to forced agents regardless of detection.
  - Backup: existing `.bak` overwritten silently on second run.
  - Color: output is colored when TTY, plain when piped or `NO_COLOR` set.
  - Version: `<binary> --version` failure → version shows "unknown".
- **Verification:** Run `bash tooling/instructions/install-instructions.sh --help` shows full usage. Run `--status` with no agents installed shows empty table. Run default (no flags) and verify table output and selection prompt. Run `--auto` and verify non-interactive install. Run `--json --auto` and validate output with `python3 -c "import json,sys; json.load(sys.stdin)"`. Manually place a test file, run script, verify diff and backup behavior.

### U2. PowerShell install script

- **Goal:** Create `tooling/instructions/install-instructions.ps1` with equivalent logic for Windows/macOS PowerShell.
- **Dependencies:** U1 (same design, different language).
- **Files:** `tooling/instructions/install-instructions.ps1`
- **Approach:**
  - Same agent table and detection logic, using `Get-Command` instead of `command -v`.
  - Same source validation (R31), configurable source (R32), colored output (R30) using `Write-Host -ForegroundColor`.
  - Same mode dispatch: `-Status`, `-DryRun`, `-Remove`, `-Json`, `-Interactive`.
  - Same diff preview (R23) using `Compare-Object` or `diff.exe` if available.
  - Same apply-to-all prompt (R24).
  - Same backup logic (R25-R26) using `Copy-Item` before overwrite.
  - Same `--Remove` with confirmation (R27-R29).
  - Same `--Json` output (R33-R34) using `ConvertTo-Json`.
  - Same `--Interactive` scan-then-select flow (R16-R19).
  - Same `--CreateDest` flag.
  - Path handling uses `Join-Path` for cross-platform compatibility.
  - Follow conventions from `tooling/machine/setup-environment.ps1`.
- **Test scenarios:**
  - Same matrix as U1, adapted for PowerShell.
  - PowerShell-specific: `Get-Command` not found → agent skipped.
  - `--Interactive` with detected agents → shows table, defaults detected to selected, proceeds on confirm.
  - `--Status` → shows color-coded table with versions.
  - `--Remove` → prompts confirmation, deletes files.
  - `--Json` → emits valid JSON via `ConvertTo-Json`.
  - Path handling uses `Join-Path` for cross-platform compatibility.
- **Verification:** Run in PowerShell; verify same behavior as bash version.

### U3. OpenCode config + documentation

- **Goal:** Update `dotfiles/opencode/opencode.json` to reference RULES.md, and create `tooling/instructions/README.md`.
- **Dependencies:** None.
- **Files:** `dotfiles/opencode/opencode.json`, `tooling/instructions/README.md`
- **Approach:**
  - Add `"instructions": ["../instructions/RULES.md"]` to the root of `opencode.json`.
  - README documents: what the system does, the agent-to-destination mapping, all modes (`--status`, `--dry-run`, `--remove`, `--auto`, `--source`, `--json`), default interactive behavior, usage examples for both scripts, how to update RULES.md, backup behavior, colored output, and the `NO_COLOR` convention.
- **Test scenarios:**
  - `opencode.json` remains valid JSON after edit.
  - README accurately describes all modes and the mapping.
- **Verification:** `python3 -c "import json; json.load(open('dotfiles/opencode/opencode.json'))"` validates JSON.

## Verification Contract

- `bash tooling/instructions/install-instructions.sh --help` prints full usage including all flags.
- `bash tooling/instructions/install-instructions.sh --status` shows detection table with versions, no modifications.
- `bash tooling/instructions/install-instructions.sh --dry-run` shows preview of all actions, no modifications.
- `bash tooling/instructions/install-instructions.sh` runs without error when no agents are installed.
- `bash tooling/instructions/install-instructions.sh` (no flags) shows detection table and selection prompt (interactive by default).
- `bash tooling/instructions/install-instructions.sh --auto` runs non-interactive install on all detected agents.
- `bash tooling/instructions/install-instructions.sh --json` emits valid JSON (validate with `python3 -c "import json,sys; json.load(sys.stdin)"`).
- `bash tooling/instructions/install-instructions.sh --json --auto` emits valid JSON without prompts.
- `bash tooling/instructions/install-instructions.sh --source /nonexistent` errors with source validation message.
- Manual test: create a temp destination file, run script, verify diff is shown, backup is created, prompt appears.
- `python3 -c "import json; json.load(open('dotfiles/opencode/opencode.json'))"` passes.
- `pwsh -File tooling/instructions/install-instructions.ps1 -Help` prints usage (if PowerShell available).
- `pwsh -File tooling/instructions/install-instructions.ps1 -Status` shows version and status table.

## Definition of Done

- Both scripts detect all four agents correctly on a machine where they are installed.
- `--status` shows color-coded table with agent versions and file state.
- `--dry-run` previews all actions without modification.
- `--remove` deletes installed instructions with confirmation (or `--force`).
- Default mode (no flags) shows a detection table and selection prompt in both bash and PowerShell.
- `--auto` performs non-interactive install to all detected or force-flagged agents.
- `--json` emits valid, machine-readable output; incompatible with default interactive mode; works with `--auto`.
- `--source` overrides the default source file.
- Force flags pre-select in interactive mode.
- Diff is shown before every overwrite prompt; apply-to-all works.
- `.bak` backup is created before every overwrite.
- Source validation catches missing and empty files.
- Copied files match the source content exactly.
- Existing files are never silently overwritten.
- Colored output works in TTY, disabled under `NO_COLOR` or non-TTY.
- OpenCode config references RULES.md and is valid JSON.
- README documents the system completely, including all modes.
- No absolute paths in any script or documentation.
