---
name: setup-env
description: Use when managing heypogi environment variables - initial setup, validating vars, debugging missing or misconfigured env vars, or after changing env var requirements. Triggers include "setup env", "check env", "env vars", "missing env vars", "environment setup", or debugging Paseo/OpenCode connection issues related to env configuration.
---

# Setup Environment Variables

## Overview

Heypogi centralizes environment variables into `~/.config/heypogi/` with three files managed by `tooling/env/setup-env.sh`. The setup script generates env files from templates, updates `~/.bashrc` idempotently, and integrates with systemd for the Paseo daemon. A companion `check-env.sh` validates required variables and reports status.

## Env File Layout

| File | Purpose | Permissions | Source |
|---|---|---|---|
| `~/.config/heypogi/.env-common` | heypogi-managed vars (HEYPOGI_ROOT, OPENCODE_CONFIG_DIR, PATH) | 644 | Generated from `env-common.template` |
| `~/.config/heypogi/.env-override` | User customizations | 640 | Empty, user-maintained |
| `~/.config/heypogi/.env-secrets` | Credentials (PASEO_PASSWORD, GH_PAT_COPILOT, etc.) | 600 | From `env-secrets.template` |

Load order: common, then override, then secrets. Override wins on conflicts.

## How to Use

First-time setup:

```bash
bash tooling/env/setup-env.sh
```

Verify env vars:

```bash
bash tooling/env/check-env.sh
```

JSON output:

```bash
bash tooling/env/check-env.sh --json
```

The setup script is idempotent - safe to run multiple times. It:
- Creates `~/.config/heypogi/` if missing
- Generates `.env-common` from template (replaces `__REPO_ROOT__` with detected repo root)
- Creates empty `.env-override` if missing
- Creates `.env-secrets` from template if missing (never overwrites existing)
- Updates `~/.bashrc` with a marker-bounded source block (`# >>> heypogi env >>>` / `# <<< heypogi <<<`)

## Verify

`check-env.sh` validates against the env var registry and outputs a table:

```
VARIABLE                       STATUS     SOURCE          CONDITION
--------                       ------     ------          ---------
HEYPOGI_ROOT                   set        .env-common
OPENCODE_CONFIG_DIR            set        .env-common
PATH                           set        .env-common
PASEO_PASSWORD                 set        .env-secrets    when Paseo uses auth
GH_PAT_COPILOT                 set        .env-secrets    when Copilot reviews used
```

Secrets are never exposed in output - only shown as "set".

Exit codes:
- `0` - all required vars present
- `1` - missing required vars (always-required ones like HEYPOGI_ROOT)
- `2` - parse error (no vars loaded at all)

## Systemd Integration

The Paseo daemon service (`dev-stack.sh startup install -a paseo`) uses `EnvironmentFile=` lines pointing to all three heypogi env files. For new installs, the full `paseo.service` template is rendered. For existing installs, missing `EnvironmentFile=` lines are appended. The `-` prefix in `EnvironmentFile=-` means systemd won't error if a file is missing.

## When Not to Use

- Windows/PowerShell environments (use `tooling/machine/setup-environment.ps1` instead)
- Paseo daemon runtime behavior or configuration (use the paseo-reference skill)
- OpenChamber env vars or UI password setup (use dev-stack.sh)
- Adding new env var registry entries (edit `check-env.sh` directly)
