---
title: "userspace-shims.sh status always reports drift for installed tools — resolve() cannot canonicalize file symlinks"
date: 2026-09-10
category: setup
module: "tooling/bin (userspace shims)"
problem_type: bug
component: bootstrap_convergence
symptoms:
  - "bootstrap.sh install --force fails at Step 1b on any re-run after tools are installed"
  - "dev-stack.sh startup install -a paseo refuses with 'userspace-shims install failed; refusing to enable the unit over an unprovisioned path'"
  - "WARN: shim ~/.local/bin/paseo points at /home/rgm/.local/bin/paseo (want /home/rgm/.local/node-bin/paseo) even though the symlink is correct"
root_cause: symlink_comparison_bug
resolution_type: code_fix
severity: medium
related_components: [tooling, bootstrap, dev-stack]
tags: [userspace-shims, symlinks, readlink, bootstrap, paseo, idempotency]
---

# userspace-shims.sh status always reports drift for installed tools

## Problem

`tooling/bin/userspace-shims.sh status` (and therefore `install`, which ends
in a status check) always reported drift for the `paseo`/`openchamber` shims
once those tools were installed — even when the symlinks on disk were exactly
right. Consequences:

- Every `bootstrap.sh install` re-run failed at Step 1b (exit 1) on a machine
  that already had tools installed. Only a first-ever run (tools absent, "no
  shim expected") could pass Step 1b.
- `dev-stack.sh startup install -a paseo` failed at its R32 gate, which runs
  `userspace-shims.sh install -q` and refuses to enable the unit over an
  "unprovisioned path" — so Step 6a of bootstrap could never complete after
  Step 4 installed the tools.

## Symptoms

```text
WARN: shim ~/.local/bin/paseo points at /home/rgm/.local/bin/paseo (want /home/rgm/.local/node-bin/paseo).
WARN: shim ~/.local/bin/openchamber points at /home/rgm/.local/node-bin/openchamber (want ...).
ERROR: userspace-shims install failed; refusing to enable the unit over an unprovisioned path.
```

Meanwhile on disk everything was correct:

```bash
$ ls -l ~/.local/bin/paseo
paseo -> /home/rgm/.local/node-bin/paseo
$ readlink -f ~/.local/bin/paseo ~/.local/node-bin/paseo
/home/rgm/.nvm/versions/node/v24.20.0/lib/node_modules/@getpaseo/cli/bin/paseo
/home/rgm/.nvm/versions/node/v24.20.0/lib/node_modules/@getpaseo/cli/bin/paseo
```

Both sides resolve to the same canonical binary.

## Root Cause

The script's `resolve()` helper only canonicalized **directories**:

```bash
resolve() { cd "$1" 2>/dev/null && pwd -P || printf '%s' "$1"; }
```

`cd` into a file path always fails, so for file symlinks `resolve()` echoed
its input back unchanged — no symlink resolution at all. The status check
then compared two literal strings:

- `got` = `/home/rgm/.local/bin/paseo`
- `want` = `/home/rgm/.local/node-bin/paseo`

which can never be equal because the parent directories differ. Any existing
shim was therefore reported as drift, unconditionally. The installer was
self-contradicting: `ensure_shim` created the link and logged `OK`, and the
trailing `do_status` immediately WARNed about it.

This also violates the Bash script standard's idempotency rule: "treat a
symlink as correct only when its **resolved** intended target is correct"
(`docs/standards/bash-scripts.md`).

## What Didn't Work

Reinstalling Paseo/OpenChamber from scratch (`npm uninstall -g`, removing the
shims, re-running bootstrap) let Step 1b pass — because with no tools
installed there is "no shim expected" — but Step 6a failed on the same gate
as soon as Step 4 had reinstalled the tools. The workaround cannot converge;
only fixing the comparison can.

## Solution

Two changes in `tooling/bin/userspace-shims.sh` (uncommitted; on both the
local checkout and `rgm-dev-01`):

1. **`resolve()` canonicalizes files too**, via `readlink -f` (coreutils,
   present on all target systems: Ubuntu 22.04+, Debian 12+), keeping the
   `cd`/`pwd -P` logic as fallback:

   ```bash
   resolve() {
       if command -v readlink >/dev/null 2>&1; then
           local out
           if out="$(readlink -f -- "$1" 2>/dev/null)" && [[ -n "$out" ]]; then
               printf '%s' "$out"
               return 0
           fi
       fi
       cd "$1" 2>/dev/null && pwd -P || printf '%s' "$1"
   }
   ```

2. **`ensure_shim()` keeps writing the node-bin-relative target**
   (`ln -sfn "$src"`, i.e. `~/.local/bin/paseo ->
   ~/.local/node-bin/paseo`) instead of the canonicalized path, so shims
   keep floating across Node upgrades when `node-bin` is repointed.
   Correctness is now judged by the canonical comparison in `do_status`,
   which matches the function's own documented contract
   (`~/.local/bin/<tool> -> ../node-bin/<tool>`).

## Verification (on rgm-dev-01)

- `bash -n` passes; `shellcheck -S warning` passes.
- `userspace-shims.sh status` → exit 0, shims reported `OK` with canonical targets.
- Second `install` (no `-f`) → "already correct; skipping", exit 0, shim
  mtimes unchanged (no unnecessary rewrite).
- `install --dry-run` → exit 0, shim mtimes unchanged (write-free preview).
- `dev-stack.sh startup install -a paseo` (the exact gate that failed) →
  exit 0; daemon healthy, unit active, allowlist-only env preserved.

## Prevention

- When comparing symlink state in reconcilers, always compare
  canonicalized targets (`readlink -f` on both sides), never raw path
  strings — a symlink's parent directory will legitimately differ from its
  target's.
- The existing `status`-when-compliant test from the Bash standard's
  verification list (`docs/standards/bash-scripts.md`, "Status when
  compliant, drifted, and indeterminate") would have caught this: it fails
  on any machine with the tools installed, which is exactly the state the
  test matrix must cover.

## Related Issues

- `tooling/bin/userspace-shims.sh` — `resolve()`, `do_status()`, `ensure_shim()`.
- `tooling/dev-stack/dev-stack.sh` — `do_startup` `install` verb (R32 gate
  calling `userspace-shims.sh install -q`).
- `bootstrap/bootstrap.sh` — Steps 1b and 6a.
- `docs/standards/bash-scripts.md` — "Treat a symlink as correct only when
  its resolved intended target is correct."
