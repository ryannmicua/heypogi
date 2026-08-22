# Bootstrap — Open Items

Things to address in bootstrap.sh.

## To Do

### bootstrap.sh

- [ ] Git config — set `user.name` and `user.email` (prompt or accept as args)
- [x] Copy dev-stack.sh to `tooling/bin` and make executable
- [ ] Post-install verification — run each CLI with `--version` and confirm
- [x] OpenChamber systemd service — decided: no, on-demand via `dev-stack start/stop` only (see Decisions Needed)
- [ ] Paseo's own generated `~/.paseo/config.json` (observed on `@getpaseo/cli@0.4.0`) uses a schema
      (`daemon.listen`, no `features.webUi` key, different `auth` shape) that doesn't match what
      Step 5's template and `dev-stack.sh`'s status checks assume. Reconcile against the current
      package's actual schema instead of the older template.
- [ ] `dev-stack.sh startup install -a paseo` references `scripts/systemd/paseo.service`, which
      doesn't exist in the repo — that template was never added. Either add it (mirroring
      bootstrap.sh's inline unit, including `--foreground`) or drop the `startup install` path.

### cloud-init (heypogi-ai-dev-vm.yaml)

- [ ] Clone URL is placeholder — replace `yourusername` with actual

### Nice to have

- [ ] Non-interactive API key setup — accept `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` as env vars or args
- [ ] SSH key generation for GitHub — optional, operator may prefer to bring their own

## Decisions Needed

- Should git config be interactive (prompt) or accept `--git-name` / `--git-email` args?

## Resolved

- **OpenChamber systemd service**: no — stays on-demand via `dev-stack start`/`stop`, matching
  Paseo's `startup`/`uninstall` verbs being explicit rather than implied by `install`.
- **Claude Code install hangs under non-interactive bootstrap**: `claude install` (the last step
  of `curl -fsSL https://claude.ai/install.sh | bash`) launches a TUI to set up the launcher/shell
  integration. Over a plain non-interactive SSH exec (no pty, no stdin) it hangs indefinitely —
  confirmed even with a pty allocated and keystrokes fed to it. There is no documented
  non-interactive flag. Fixed by wrapping the install in `timeout 90` so bootstrap can't hang
  forever, with a clear message to finish it manually from a real interactive session. Codex's and
  gh's installers do not have this problem — both complete fine non-interactively.
- **Paseo systemd service crash-looping**: `paseo daemon start` forks a detached child and the
  launcher process exits 0 immediately. Against a `Type=simple` unit, systemd reads that as the
  service exiting and restarts it forever (real crash-loop, not just noisy logs — seen with a
  restart counter over 190 on a VM that had been up only a couple hours). Fixed by adding
  `--foreground` (plus `--listen 0.0.0.0:6767 --web-ui` to match the intended remote-accessible
  state) to the unit's `ExecStart` in bootstrap.sh.
- **`dev-stack.sh status` dies silently when a service isn't running**: `get_listening_pid()`'s
  pipeline (`ss | grep | grep -oP | head -1`) returns the exit status of the first `grep` under
  `set -euo pipefail`, so when a port has nothing listening, the whole script exits immediately
  instead of reporting a clean FAIL line. Fixed with a trailing `|| echo ""`, matching the
  fallback pattern already used by `get_version()`. Also cleaned up `write_status_report()`, which
  was printing every status line twice (a superseded first attempt at coloring output was left in
  next to the working "simpler approach" replacement).
