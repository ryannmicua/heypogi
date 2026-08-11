# Clone OpenCode Source

Clones the [OpenCode](https://github.com/anomalyco/opencode) source repository into
`external/opencode/` so the `@opencode` subagent can read implementation details and
docs source directly.

## Prerequisites

- Git

## What this does

1. Clones `https://github.com/anomalyco/opencode.git` into `external/opencode/`
   (or pulls latest if already cloned)
2. The `opencode-source` reference in `dotfiles/opencode/opencode.json` uses a
   relative path (`../../external/opencode`) so the `@opencode` subagent can read it

## Install

Run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/clone-opencode-source.ps1
```

To suppress prompts (e.g. for scripting):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/clone-opencode-source.ps1 -Quiet
```

## Verify

```powershell
ls external/opencode/
git -C external/opencode log --oneline -3
```

Check that the `@opencode` agent can resolve the source:

```powershell
opencode debug config
```

You should see `opencode-source` with a path under `<repo_root>\external\opencode`.

## What it modifies

| Target | Details |
|---|---|
| `external/opencode/` | Git clone of https://github.com/anomalyco/opencode.git |

## Notes

- The `external/opencode/` directory is in `.gitignore` — it is not committed to this repo.
- Re-running the script prompts to pull latest instead of re-cloning.
