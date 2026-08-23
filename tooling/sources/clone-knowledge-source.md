# Clone Compound Knowledge Source

Clones the [Compound Knowledge](https://github.com/EveryInc/compound-knowledge-plugin) source repository into
`external/compound-knowledge/` so the skills installer can link the repo's `skills/` folder directly.

## Prerequisites

- Git

## What this does

1. Clones `https://github.com/EveryInc/compound-knowledge-plugin.git` into `external/compound-knowledge/`
   (or pulls latest if already cloned)
2. Keeps the local source checkout available for the skills installer at `tooling/skills/install-knowledge-skills.md`

## Install

Run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/sources/clone-knowledge-source.ps1
```

To suppress prompts (e.g. for scripting):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/sources/clone-knowledge-source.ps1 -Quiet
```

### Linux/macOS

Run from the repo root:

```bash
bash tooling/sources/clone-knowledge-source.sh
```

To suppress prompts:

```bash
bash tooling/sources/clone-knowledge-source.sh --quiet
```

## Verify

```powershell
ls external/compound-knowledge/
git -C external/compound-knowledge log --oneline -3
```

## What it modifies

| Target | Details |
|---|---|
| `external/compound-knowledge/` | Git clone of https://github.com/EveryInc/compound-knowledge-plugin.git |

## Notes

- The `external/compound-knowledge/` directory is in `.gitignore` — it is not committed to this repo.
- Re-running the script prompts to pull latest instead of re-cloning.
