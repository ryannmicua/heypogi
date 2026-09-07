---
lorespec: "0.1"
id: "2026090603"
date: "2026-09-06"
source: "other"
topic: "Migrated the full dev stack (node, npm, paseo, openchamber, opencode, codex, axi CLIs) to rootless userspace operation"
tags: [userspace, rootless, nvm, npm-prefix, paseo, systemd-user, openchamber, dev-stack]
classification:
  type: technical
  secondary_type: operational
  domains: [linux-admin, node-ecosystem, systemd, heypogi-tooling]
  value: high
trails: [heypogi-userspace-stack]
---

## Session Arc

### Started
User request: "I want all my stack to run on user space and not need root permission. This includes opencode, codex, paseo, openchamber, node, npm, etc."

### Pivots
- **P1 — npm prefix fight**: User voted `~/.local` as the global npm prefix, but implementing it broke nvm (nvm hard-errors on any prefix config, every shell). Pivoted to nvm-native version-dir globals, which still need zero root. User was informed and accepted the rationale.
- **P2 — daemon ran on wrong node**: After migrating Paseo to a user unit, `/proc/<pid>/exe` showed `/usr/bin/node` despite a correct-looking unit PATH. Root cause chain: `$HOME` is not expanded by systemd + `EnvironmentFile=` overrides `Environment=`. Fixed by expanding `$HOME` at generation time in `setup-env.sh`.
- **P3 — cutover interruption**: The tool call stopping the system service and starting the user service was interrupted mid-cutover, leaving the Paseo daemon down. Recovered by checking state first, then enabling/starting the user unit.

### Ended
All 13 CLIs resolve to userspace paths in real interactive shells; Paseo runs as a systemd user service (active, enabled, linger on); OpenChamber updated 1.22.0 -> 1.22.2 with zero sudo as proof; `dev-stack.sh status` passes all checks even with a bare caller PATH. Repo changes left uncommitted. Follow-up Q&A clarified why nvm isolates globals per Node version.

## ARTIFACT

### A1 — Rootless stack layout (live system state)
- Node/npm/npx via `~/.local/bin` shims -> `~/.nvm/versions/node/v24.20.0/bin/` (nvm default alias `v24.20.0`).
- npm global prefix = `/home/rgm/.nvm/versions/node/v24.20.0` (user-owned); `npm root -g` = `.../lib/node_modules`.
- Global CLIs in nvm prefix + shimmed: paseo 0.7.2, openchamber 1.22.2, chrome-devtools-axi 0.1.34, gh-axi 0.1.35, lavish-axi 0.1.66, quota-axi 0.1.38, tasks-axi 0.2.5, workstream (repo link).
- opencode: `~/.opencode/bin/opencode` 1.18.29. codex: `~/.local/bin/codex` (standalone install).
- Paseo daemon: `~/.config/systemd/user/paseo.service` (mode 600, carries PASEO_PASSWORD), `systemctl --user enable --now`, `loginctl enable-linger rgm` done.
- Removed (one approved sudo pass): `/etc/systemd/system/paseo.service`, `/usr/bin/{paseo,openchamber,*-axi}` shims, `/usr/lib/node_modules` globals (only apt `corepack`+`npm` remain, unused), `/usr/local/bin/opencode` shim.

### A2 — Repo changes (uncommitted, in `/home/rgm/repo/heypogi`)
- `tooling/dev-stack/dev-stack.sh`: sudo-free (npm wrapper never escalates; `systemctl --user` + `ensure_user_bus`; user-unit startup management; self-prepends userspace PATH).
- `tooling/dev-stack/paseo.service`: rewritten as systemd USER unit template (`%h` specifiers, `WantedBy=default.target`).
- `tooling/env/env-common.template`: userspace-first PATH (`~/.local/bin`, `~/.opencode/bin` ahead of `/usr/bin`).
- `tooling/env/setup-env.sh`: expands `$HOME` (and `__REPO_ROOT__`) to absolute paths at generation time so the file is valid for both bash and systemd `EnvironmentFile=`.
- `tooling/bin/userspace-shims.sh` (new, executable): re-points all `~/.local/bin` shims at the current nvm default after upgrades.

## DECISION

### D1 — npm globals live in nvm's version dir, not `~/.local`
- **Decision**: Use nvm's native per-version global prefix instead of the user-voted `~/.local` prefix.
- **Issue**: User chose `~/.local` as the global install location.
- **Positions**: (a) `prefix=~/.local` in `~/.npmrc`; (b) nvm version-dir globals + stable shims.
- **Arguments**: (a) matches the vote literally, but nvm's `nvm_die_on_prefix` rejects ANY prefix config (npmrc file, `$PREFIX`, or `$NPM_CONFIG_PREFIX`): every shell printed an incompatibility error, auto-`use` of the default version failed, and `nvm use/install` were blocked unless `--delete-prefix` (which deletes the setting). (b) needs zero root (dir is user-owned), keeps nvm fully functional; cost is globals are per-Node-version and need reinstall + re-shim on major upgrades.
- **Warrant**: Because we believe keeping nvm's version management working outweighs the literal prefix location, given the actual goal (never need root) is satisfied either way.
- **Qualifier**: in this case
- **Status**: settled (user accepted rationale in follow-up; documented upgrade path via `nvm reinstall-packages` + `userspace-shims.sh`)

### D2 — Paseo autostart via systemd user unit + linger
- **Decision**: Migrate from `/etc/systemd/system/paseo.service` to `~/.config/systemd/user/paseo.service` with `loginctl enable-linger`.
- **Issue**: How should the Paseo daemon autostart without root?
- **Positions**: (a) user unit + linger (one-time sudo); (b) manual `nohup` start, no autostart.
- **Arguments**: (a) preserves boot-persistent autostart with zero ongoing root; (b) avoids even one-time sudo but loses autostart.
- **Warrant**: Because we believe autostart parity is worth a single audited sudo command.
- **Qualifier**: always
- **Status**: settled

## INSIGHT

### I1 — systemd `EnvironmentFile=` beats `Environment=` regardless of order
The running Paseo daemon inherited PATH from the heypogi env files even though the unit set `Environment=PATH=...` AFTER the `EnvironmentFile=` lines (`systemctl --user show` displayed the unit value, `/proc/<pid>/environ` showed the file value). Ordering within the unit does not save you; the file wins. Source: observed during this session, verified via `/proc/<pid>/environ` vs `systemctl --user show -p Environment`. Confidence: high for this systemd version's behavior.

### I2 — systemd performs no `$VAR` expansion in units or env files
`Environment=PATH=$HOME/.local/bin:...` and the same line in an `EnvironmentFile` both arrived at the process literally unexpanded (`$HOME` visible in `/proc/<pid>/environ`), causing `env` shebang lookup to skip the userspace dirs and fall through to `/usr/bin/node`. Only specifiers (`%h`) expand in unit directives. Source: observed during this session. Confidence: high.

### I3 — `bash -lc` is not a valid interactive-login PATH test on Ubuntu
`bash -lc 'which opencode'` reported "not found" because `~/.bashrc` early-returns for non-interactive shells (`case $-`), so the heypogi env block never ran. Real interactive shells (`bash -ic`) resolve everything. The `~/.env` + `~/.profile` pre-bashrc PATH is a different, reduced PATH. Source: observed during this session. Confidence: high.

## PATTERN

### P1 — Diagnose "wrong binary" via `/proc/<pid>/exe` + `/proc/<pid>/environ`
When a service runs an unexpected interpreter, don't trust the unit file display: `readlink /proc/<pid>/exe` shows the true binary and `tr '\0' '\n' < /proc/<pid>/environ | grep ^PATH=` shows the effective PATH. This two-command check exposed both the `$HOME` expansion bug and the `EnvironmentFile` precedence issue in minutes. Scope: local (Linux systemd services).

### P2 — Rootless migration sequence for a systemd system service
1. Install/provision the userspace replacement first (binaries, shims, PATH). 2. Write the user unit alongside (do not touch the system unit yet). 3. One-time `loginctl enable-linger`. 4. Stop + disable the system unit, then enable + start the user unit (accept brief downtime; check port is free between). 5. Verify via process exe + health endpoint, not just `is-active`. 6. Only then remove the system unit and root-owned packages. Scope: local (systemd Linux hosts).

## SOLUTION

### S1 — nvm prefix conflict
- **Broken**: Setting `prefix=~/.local` in `~/.npmrc` made every shell print "incompatible with nvm" and left `nvm` unusable (`nvm use/install` blocked).
- **Fix**: `npm config delete prefix` (removed `~/.npmrc`); globals now live in the nvm version dir; stable access via `~/.local/bin` shims + `tooling/bin/userspace-shims.sh`.
- **Why it works**: nvm owns the prefix concept per installed version; removing the override restores its invariant while the user-owned version dir still satisfies "no root".
- **Caveat**: globals are per-Node-version; migrate with `nvm reinstall-packages <oldver>` on upgrades.

### S2 — Paseo user unit ran on system node
- **Broken**: Daemon `exe` was `/usr/bin/node` despite unit PATH listing `~/.local/bin` first.
- **Fix**: (1) unit uses `%h` specifiers instead of `$HOME`; (2) `setup-env.sh` expands `$HOME` to absolute at generation time so `.env-common` is valid for both bash and `EnvironmentFile=`.
- **Why it works**: systemd expands neither `$VAR` nor `~`; the daemon's `#!/usr/bin/env node` shebang now resolves through a fully-absolute userspace-first PATH.
- **Caveat**: any future PATH-like value added to the heypogi env files must also avoid `$VAR` syntax or services will silently fall back to system binaries.

## OPEN_QUESTION

### O1 — Where should PASEO_PASSWORD live?
Currently embedded as `Environment=PASEO_PASSWORD=...` in the user unit (mode 600), copied from the old system unit. The cleaner home is `~/.config/heypogi/.env-secrets` (already referenced via `EnvironmentFile=`), but the secret was never moved. Blocks: nothing (works as-is); revisit when rotating the password.

### O2 — Drop apt nodejs 22 entirely?
`nodejs` 22 (nodesource deb) remains installed but unused. Removing it would eliminate the last root-owned runtime, but also removes the fallback if the nvm tree is ever damaged. No action taken; low stakes either way.

## NEXT_STEP

### N1 — Commit the repo changes (soon)
`dev-stack.sh`, `paseo.service`, `env-common.template`, `setup-env.sh` modified + new `tooling/bin/userspace-shims.sh`. Prompted by: session completed with all verification green. Urgency: soon (uncommitted work at risk).

### N2 — Move PASEO_PASSWORD to `.env-secrets` (someday)
Prompted by: O1. Rotate the password, put it in `.env-secrets` (chmod 600), drop the `Environment=` line from the user unit, restart. Urgency: someday.

## Connections
D1 —[led_to]→ A1
D1 —[led_to]→ S1
D2 —[led_to]→ A1
I1 —[informed_by]→ S2
I2 —[informed_by]→ S2
I2 —[led_to]→ A2
P1 —[instance_of]→ S2
P2 —[led_to]→ A1
O1 —[depends_on]→ D2
N1 —[depends_on]→ A2
I3 —[related_to]→ A1
