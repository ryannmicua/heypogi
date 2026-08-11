# Clone Compound Engineering Source

Clones the [Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin) source repository into
`external/compound-engineering/` so the skills installer can link the repo's `skills/` folder directly.

## Prerequisites

- Git

## What this does

1. Clones `https://github.com/EveryInc/compound-engineering-plugin.git` into `external/compound-engineering/`
   (or pulls latest if already cloned)
2. Keeps the local source checkout available for the skills installer at `tooling/install-ce-skills.md`

## Install

Run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/clone-ce-source.ps1
```

To suppress prompts (e.g. for scripting):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/clone-ce-source.ps1 -Quiet
```

## Verify

```powershell
ls external/compound-engineering/
git -C external/compound-engineering log --oneline -3
```

## What it modifies

| Target | Details |
|---|---|
| `external/compound-engineering/` | Git clone of https://github.com/EveryInc/compound-engineering-plugin.git |

## Notes

- The `external/compound-engineering/` directory is in `.gitignore` — it is not committed to this repo.
- Re-running the script prompts to pull latest instead of re-cloning.
