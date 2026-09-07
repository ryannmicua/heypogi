# Bootstrap — Open Items

Things to address in bootstrap.sh. Delegation refactor landed 2026-09-07
(plan `docs/plans/2026-09-07-feat-bootstrap-delegation-plan.md`):
bootstrap is now a thin orchestrator over `tooling/` (env-first order,
`--user` target context, run-history markers, `status` verb).

## To Do

### bootstrap.sh

- [ ] Git config — set `user.name` and `user.email` (prompt or accept as args)
- [ ] Post-install verification — run each CLI with `--version` and confirm
- [ ] Non-interactive API key setup — accept `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` as env vars or args
- [ ] SSH key generation for GitHub — optional, operator may prefer to bring their own

### cloud-init (heypogi-ai-dev-vm.yaml)

- [ ] Clone URL is placeholder — replace `yourusername` with actual

## Decisions Needed

- Should git config be interactive (prompt) or accept `--git-name` / `--git-email` args?
- `userspace-shims.sh` always runs (outside every `--skip-*` subset): accepted
  because it is cheap, idempotent, and owns shared PATH layout - revisit if a
  skip flag ever needs a fully untouched `~/.local`.
- Docker missing is an exit-3 blocker (plan R24), overriding the old
  "optional" README wording. Revisit if headless VMs without Docker must converge.
- `tooling/bin/dev-stack` stays git-ignored by decision and is converged by
  `userspace-shims.sh install` instead of bootstrap.

## Resolved

- **Delegation refactor (2026-09-07)**: bootstrap thinned to orchestrator;
  install logic moved to `tooling/machine/` (new `check-prereqs.sh`,
  `install-claude-cli.sh`, `install-gh-cli.sh`; retrofitted
  `install-codex-cli.sh`), `tooling/env/` (`setup-env.sh` status/install +
  new `require-env.sh` guard), `tooling/sources/` (acquired before skills),
  `tooling/dev-stack/` (Paseo seed/merge, legacy migration, linger,
  fail-closed bind, secrets allowlist), `tooling/bin/userspace-shims.sh`.
  All leaves: `status`/`install` + `-f`/`-q`/`--dry-run` + exits 0/1/2/3.
- **Paseo schema reconcile**: `seed_paseo_config` does an additive,
  versioned merge supporting the tracked template and live 0.4.0+
  (`daemon.listen`, no `features.webUi` key) - preserves password,
  providers, runtime, overrides; patches only `listen`.
- **paseo.service template**: exists at `tooling/dev-stack/paseo.service`
  (user unit) and is installed by `startup install`; the legacy system
  unit is stopped/disabled/migrated (R22).
- **Copy dev-stack.sh to `tooling/bin`**: superseded - the `dev-stack`
  entry point is a git-ignored symlink converged by `userspace-shims.sh`.
- **Post-install verification**: superseded by per-leaf `status` verbs +
  `bootstrap.sh status` aggregation (0/1/3).
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
  state) to the user unit's `ExecStart` in `tooling/dev-stack/paseo.service`.
- **`dev-stack.sh status` dies silently when a service isn't running**: `get_listening_pid()`'s
  pipeline (`ss | grep | grep -oP | head -1`) returns the exit status of the first `grep` under
  `set -euo pipefail`, so when a port has nothing listening, the whole script exits immediately
  instead of reporting a clean FAIL line. Fixed with a trailing `|| echo ""`, matching the
  fallback pattern already used by `get_version()`. Also cleaned up `write_status_report()`, which
  was printing every status line twice (a superseded first attempt at coloring output was left in
  next to the working "simpler approach" replacement).
