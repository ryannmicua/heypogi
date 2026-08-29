# Global Instructions Manager

Install a single source file (`dotfiles/instructions/RULES.md`) to each AI coding agent's expected global instructions location.

## Agent-to-Destination Mapping

| Agent | Binary | Destination | Method |
|-------|--------|-------------|--------|
| Codex | `codex` | `~/.agents/AGENTS.md` | Copy |
| Claude Code | `claude` | `~/.claude/CLAUDE.md` | Copy |
| agy (Antigravity) | `agy` | `~/.gemini/GEMINI.md` | Copy |
| OpenCode | `opencode` | Config reference | `opencode.json` `instructions` array |

## Scripts

- **Bash:** `bash tooling/instructions/install-instructions.sh [options]`
- **PowerShell:** `pwsh -File tooling/instructions/install-instructions.ps1 [options]`

Both scripts share the same logic and modes. The bash script runs on Linux/macOS; the PowerShell script runs on Windows, macOS, and Linux with PowerShell installed.

## Modes

### Default (Interactive)

Scans all agents, shows a detection table, then presents a selection checklist. Detected agents default to selected. Toggle by number, press Enter to confirm.

```bash
bash tooling/instructions/install-instructions.sh
```

### --auto (Non-Interactive)

Installs to all detected agents (or force-flagged agents) without prompts.

```bash
bash tooling/instructions/install-instructions.sh --auto
```

### --status (Read-Only)

Shows a color-coded table with detection status, agent version, and file state. No files are modified.

```bash
bash tooling/instructions/install-instructions.sh --status
```

### --dry-run (Preview)

Runs the full install logic but shows what would happen without modifying files.

```bash
bash tooling/instructions/install-instructions.sh --dry-run
```

### --remove (Uninstall)

Deletes installed instructions from each detected agent. Prompts for confirmation before each deletion. Use `--force` to skip confirmation.

```bash
bash tooling/instructions/install-instructions.sh --remove
bash tooling/instructions/install-instructions.sh --remove --force
```

### --json (Machine-Readable)

Emits valid JSON to stdout. Suppresses all other output. Incompatible with default interactive mode; use `--json --auto` instead.

```bash
bash tooling/instructions/install-instructions.sh --json --auto
```

JSON output format:

```json
{
  "agents": [
    {
      "name": "codex",
      "detected": true,
      "version": "0.98.0",
      "action": "installed",
      "destination": "~/.agents/AGENTS.md"
    }
  ]
}
```

## Options

| Flag | Description |
|------|-------------|
| `--source PATH` | Override default source file (default: `dotfiles/instructions/RULES.md`) |
| `--create-dest` | Create missing parent directories before copying |
| `--codex` | Force-target Codex even if not detected |
| `--claude` | Force-target Claude Code even if not detected |
| `--agy` | Force-target agy even if not detected |
| `--opencode` | Force-target OpenCode even if not detected |
| `--force` | Skip confirmation prompts (use with `--remove`) |
| `-h, --help` | Show help message |
| `--version` | Show version |

## Behavior Details

### Source Validation

The script validates that the source file exists, is a regular file, and is non-empty before any operations. If validation fails, it exits with an error message and exit code 1.

### Diff Preview

Before overwriting an existing file, the script shows a unified diff (limited to 50 lines). The overwrite prompt includes an **apply-to-all** option: `[a]pply to all, [o]verwrite, [s]kip, [q]uit`.

### Backup

Before overwriting, the existing file is saved as `<destination>.bak`. If a `.bak` file already exists from a prior run, it is overwritten silently (only the most recent backup is kept).

### Colored Output

Status tables and summaries use ANSI color when stdout is a terminal:
- **Green:** installed, up to date
- **Yellow:** differs, outdated
- **Red:** not found, error
- **Cyan:** info, config reference

Color is disabled when stdout is not a TTY or when `NO_COLOR` is set (per [no-color.org](https://no-color.org/)). `--json` always disables color.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (missing source, validation failure) |
| 2 | User abort (quit during prompt) |

## Updating Instructions

Edit `dotfiles/instructions/RULES.md`, then re-run the install script to propagate changes to all agents.

## OpenCode Config

OpenCode does not use a copy. The `dotfiles/opencode/opencode.json` file references the source directly via:

```json
{
  "instructions": ["../instructions/RULES.md"]
}
```

Changes to `RULES.md` take effect immediately when the repo is the working directory.
