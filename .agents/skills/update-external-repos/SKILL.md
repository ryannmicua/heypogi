---
name: update-external-repos
description: Use when the user asks to update, refresh, pull, sync, or get the latest from external repos in this project. Triggers include "update externals", "pull external repos", "refresh sources", "update compound-engineering", "update opencode source", "sync external dependencies", or when external references seem stale.
---

# Update External Repos

## Overview

This project vendors three external repos under `external/` via standalone clones (not submodules). This skill pulls the latest from all three and keeps the local freshness tracker current.

## External Repositories

| Directory | Remote | URL |
|---|---|---|
| `external/compound-engineering/` | origin | https://github.com/EveryInc/compound-engineering-plugin.git |
| `external/compound-knowledge/` | origin | https://github.com/EveryInc/compound-knowledge-plugin.git |
| `external/opencode/` | origin | https://github.com/anomalyco/opencode.git |

## How to Update

Run the clone scripts for each external repo. Each script clones if missing, or pulls if present:

Windows:

```powershell
& ".\tooling\sources\clone-ce-source.ps1" -Quiet
& ".\tooling\sources\clone-knowledge-source.ps1" -Quiet
& ".\tooling\sources\clone-opencode-source.ps1" -Quiet
```

Linux/macOS:

```bash
bash tooling/sources/clone-ce-source.sh --quiet
bash tooling/sources/clone-knowledge-source.sh --quiet
bash tooling/sources/clone-opencode-source.sh --quiet
```

The `-Quiet` / `--quiet` flag skips the interactive Y/N prompt and pulls automatically. Each
successful clone or pull records its UTC timestamp, branch, commit, and remote in
the ignored local ledger at `external/.repo-update-status.json`.

## Verify the Update

After pulling, check the latest commits and confirm the freshness tracker:

Windows:

```powershell
foreach ($dir in @("compound-engineering", "compound-knowledge", "opencode")) {
  $path = ".\external\$dir"
  Write-Host "$dir : $(git -C $path log --oneline -1)"
}

& ".\tooling\sources\get-external-repo-status.ps1"
```

Linux/macOS:

```bash
for dir in compound-engineering compound-knowledge opencode; do
  echo "$dir : $(git -C "external/$dir" log --oneline -1)"
done

bash tooling/sources/get-external-repo-status.sh
```

The status command reports `CURRENT` for each successfully refreshed repository.
It exits with code `1` when an update record is missing or older than the configured
freshness window (seven days by default).

## When Not to Use

- The user asks to clone external repos for the first time (use the install scripts instead)
- The user asks about reinstalling/linking skills (use the install-skills or install-ce-skills skill)
