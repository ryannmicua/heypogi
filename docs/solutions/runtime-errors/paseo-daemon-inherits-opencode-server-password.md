---
title: "Paseo daemon inherits OPENCODE_SERVER_PASSWORD and every spawned opencode server 401s"
date: 2026-08-05
category: runtime-errors
module: "install/scripts (Paseo daemon lifecycle)"
problem_type: runtime_error
component: authentication
symptoms:
  - "OpenCode provider unusable in Paseo: `Failed to fetch OpenCode providers: {}` (empty error object)"
  - "Claude and Codex providers work fine while only OpenCode fails"
  - "`mcp__paseo__list_providers` reports the opencode entry as status \"error\" with the same empty-object message"
  - "`GET /config/providers` on a Paseo-spawned opencode server returns 401 with no auth header"
root_cause: config_error
resolution_type: config_change
severity: medium
related_components: [tooling, development_workflow]
tags: [paseo, opencode, openchamber, environment-variables, process-environment, powershell, daemon, authentication]
---

# Paseo daemon inherits OPENCODE_SERVER_PASSWORD and every spawned opencode server 401s

## Problem

Paseo's OpenCode provider was permanently unusable — every provider fetch failed with an empty error object — because the long-lived Paseo daemon had inherited `OPENCODE_SERVER_PASSWORD` from the OpenChamber-managed opencode session it happened to be started from. Every opencode server the daemon spawned therefore demanded HTTP Basic auth that Paseo never sends.

## Symptoms

- Paseo's provider list reported the opencode provider as `status: "error"` with the message:

  ```
  Failed to fetch OpenCode providers: {}
  ```

  The `{}` is the whole payload — the error serialized to an empty object and named no cause at all. This is what made the bug expensive: the message carried zero signal.
- Claude and Codex providers on the same daemon were `available` and worked normally, so the failure looked provider-specific rather than environmental.
- The opencode CLI itself appeared completely healthy from the same machine: `opencode --version` reported 1.18.13 and `opencode models` returned a full model list.
- Once reproduced directly, the underlying symptom was an HTTP `401` from `GET /config/providers` on a freshly started `opencode serve` — not a crash, not a malformed body.

## What Didn't Work

The investigation ran through three wrong theories before the real one, and each dead end is instructive.

**Dead end 1 — "the opencode CLI is broken or misinstalled."** The natural first move was to check whether opencode worked at all. It did: `opencode --version` returned 1.18.13 and `opencode models` listed models without complaint. This is actively misleading, and the reason is in the source. `header()` in `external/opencode/packages/opencode/src/server/auth.ts:36-42` reads `Flag.OPENCODE_SERVER_PASSWORD` and, when a password is present, constructs `Basic <base64(username:password)>` itself. opencode's own client therefore sends the very credential that the environment variable implies. The CLI transparently papers over the exact condition that breaks any third-party client. A healthy CLI proves nothing about a third-party client's ability to reach the same server.

**Dead end 2 — "the config is malformed or missing."** `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` pointed at `dotfiles/opencode/opencode.json`, which is exactly the kind of thing that looks suspicious when a provider list comes back empty. The file existed and was valid JSON. The `OPENCODE_CONFIG_CONTENT` plugin path (an OpenChamber plugin under the user's `~/.config/openchamber/` — outside this repo) was also checked and was present on disk. Both were fine. Config was never involved.

**Dead end 3 — implicitly, "it's a token problem."** After the mechanism was suspected, an `Authorization: Bearer <password>` request was tried and returned 401, as did `curl -u :<password>` with an empty username. Neither shape is what opencode wants.

The turn came from reproducing the failure outside Paseo: starting `opencode serve` by hand and curling `/config/providers` returned **401**. That reframed the problem from "opencode is broken" to "opencode is refusing us," which is a completely different search.

From there, grepping the shipped binary for env-var names surfaced the mechanism:

```bash
grep -aoE "OPENCODE_[A-Z_]+" <opencode-binary> | sort -u
```

`OPENCODE_SERVER_PASSWORD` and `OPENCODE_SERVER_USERNAME` appearing as a pair implies HTTP Basic, not a bearer token. Confirmed against the source: `external/opencode/packages/opencode/src/server/auth.ts:17-20` binds `password` to `OPENCODE_SERVER_PASSWORD` and `username` to `OPENCODE_SERVER_USERNAME` (defaulting to `opencode`), and `required()` at lines 24-26 returns true whenever the password is present **and non-empty**. Every authorization middleware short-circuits on that check — `external/opencode/packages/opencode/src/server/routes/instance/httpapi/middleware/authorization.ts` reads `if (!ServerAuth.required(config))` and returns an unauthenticated passthrough — so a single non-empty env var flips the whole HTTP API from open to Basic-auth-required. Failing the check yields `HttpApiError.Unauthorized`, which is the 401.

Two experiments closed it:

```bash
curl.exe -s -u opencode:<password> http://127.0.0.1:<port>/config/providers   # 200, full provider list
env -u OPENCODE_SERVER_PASSWORD opencode serve                                # then curl -> 200, unauthenticated
```

Finally, provenance. The variable was present in the live process environment but in **neither** the User nor the Machine registry scope, so it was pure process inheritance, not a persisted setting. The process tree showed opencode PID 8408 under `@openchamber/web` PID 18636 (port 7777), and the paseo daemon-worker PID 15088 under supervisor 18696 under PID 28280 — which had already exited, so the launcher could not be identified directly. Timestamps settled it: last boot/logon was Jul 27 16:19, when the `PaseoDaemon` scheduled task ran with result 0; OpenChamber started Aug 5 15:29; the running Paseo supervisor started Aug 5 17:43:42. Nine days after logon and two hours after OpenChamber — so the live daemon did not come from the clean-env scheduled task. `install/scripts/dev-stack.ps1` had been modified at 17:32, eleven minutes earlier, and that script starts the daemon in-process with `& paseo daemon start`.

## Solution

The fix shipped in commit `ee86c9c` (*fix: strip session env vars when starting Paseo daemon*). It adds an `Invoke-PaseoDaemon` helper to `install/scripts/dev-stack.ps1` and routes every daemon-spawning call site through it.

Before — each of the four spawn sites invoked the daemon directly, inheriting whatever environment the script happened to be running under:

```powershell
Safe-Invoke -What "Starting Paseo daemon"   -Body { & paseo daemon start }
Safe-Invoke -What "Restarting Paseo daemon" -Body { & paseo daemon restart }
```

After — the helper in `install/scripts/dev-stack.ps1`:

```powershell
function Invoke-PaseoDaemon {
  param([ValidateSet("start", "restart")][string]$Action)
  $saved = @{}
  foreach ($v in 'OPENCODE_SERVER_PASSWORD','OPENCODE_SERVER_USERNAME','OPENCODE_CONFIG_CONTENT','OPENCODE_PID','OPENCODE','AGENT') {
    if (Test-Path "Env:$v") {
      $saved[$v] = (Get-Item "Env:$v").Value
      Remove-Item "Env:$v"
    }
  }
  try {
    & paseo daemon $Action
  } finally {
    foreach ($k in $saved.Keys) { Set-Item "Env:$k" $saved[$k] }
  }
}
```

The four spawn sites now read `Invoke-PaseoDaemon start` / `Invoke-PaseoDaemon restart`: the ensure-path start, the config-changed restart, the post-update site (whose host message says "Restarting" while the action is in fact `start` — pre-existing behavior, preserved), and the supervisor's `start` command path. The `fix` command reaches the daemon only indirectly, by delegating to the ensure path. The `stop` path is deliberately left as a bare `& paseo daemon stop`: stopping spawns nothing, so there is no environment to leak.

Two design points are load-bearing:

- **Save/restore, not plain removal.** A helper invoked mid-script must not leave side effects on its caller's environment: the script continues running after the daemon call, and silently mutating the ambient environment for everything downstream trades one inheritance bug for another. The `finally` block guarantees restoration even if the daemon command throws.
- **The stripped set is broader than the one culprit.** `OPENCODE_PID`, `OPENCODE`, and `AGENT` are stripped too, because opencode's CLI middleware stamps all three into the process environment on every invocation (`external/opencode/packages/opencode/src/index.ts:75-77` sets `AGENT = "1"`, `OPENCODE = "1"`, and `OPENCODE_PID` to the current pid). A daemon that believes it is running inside an agent session is a second class of confusion worth pre-empting.

Verification performed: the script parses clean, and the strip/restore round trip was exercised directly — the variables read empty inside the call, were restored afterward, and an invalid action was rejected by `ValidateSet`.

## Why This Works

The root cause is a three-link chain, and the fix breaks the middle link.

1. OpenChamber sets `OPENCODE_SERVER_PASSWORD` into its **own process environment** when it establishes opencode auth state. In the globally installed `@openchamber/web` package (outside this repo, under the npm global `node_modules`), the opencode auth-state runtime module does `process.env.OPENCODE_SERVER_PASSWORD = normalized;`, with a corresponding `delete` on the invalid-password branch. Anything launched from inside that process tree inherits it.
2. opencode's server turns Basic auth on unconditionally whenever that variable is non-empty — `required()` in `auth.ts`, consumed by every authorization middleware as shown above. There is no separate "enable auth" switch; presence of the password *is* the switch.
3. Paseo spawns opencode servers as child processes, passing its own environment down, and its provider client does not send an `Authorization: Basic` header. Every fetch gets a 401, and whatever Paseo does to serialize that response produces `{}`.

The Paseo daemon is long-lived, so the capture is permanent: the environment it held at spawn time is the environment every child it ever spawns will receive. Starting it in-process from a shell nested inside the OpenChamber-managed opencode session is what injected the variable in the first place. Stripping the variables for the duration of the `paseo daemon start`/`restart` call means the daemon starts with a clean slate and its children see no password, so `required()` returns false and the API serves unauthenticated — which is what Paseo expects on loopback.

Note that this also explains why the scheduled-task path never showed the bug: a task launched by the service host at logon gets a clean environment for free.

**Rejected alternative, worth recording.** The obvious cleaner fix is to route all starts through the existing `PaseoDaemon` scheduled task via `Start-ScheduledTask`, inheriting the service host's clean environment rather than hand-maintaining a strip list. It was rejected for two concrete reasons: the ensure-path start runs *before* the task-registration block in the same function, so it would need reordering to handle the not-yet-registered case; and the task is registered `-RunLevel Highest`, so triggering it requires elevation the script may not have. The env-strip is a blacklist and that is a genuine weakness — a newly injected variable is not covered — but it is ordering-independent and needs no privileges. If the strip list starts growing, that is the signal to revisit the scheduled-task approach.

**Still outstanding at time of writing:** the currently running daemon retains the bad environment. The script change affects future starts only; clearing the live symptom requires restarting the daemon from a shell that does not have `OPENCODE_SERVER_PASSWORD` set.

## Prevention

**Before starting the daemon by hand, check the shell.** In any candidate shell:

```powershell
$env:OPENCODE_SERVER_PASSWORD
```

This must print nothing. If it prints a value, that shell is inside an OpenChamber/opencode session and must not be used to start a long-lived daemon. `$env:OPENCODE`, `$env:AGENT`, and `$env:OPENCODE_PID` are the same tell.

**Verify the daemon's children directly.** Against an opencode server that Paseo spawned:

```powershell
curl.exe -s http://127.0.0.1:<port>/config/providers
```

JSON means healthy. A 401 means the bug is back. This is the one check that tests the actual failing path rather than a proxy for it — and note that `opencode --version` or `opencode models` succeeding does **not** count as verification, for the `header()` reason above.

**Prefer the clean-environment launch path.** Start the daemon from the `PaseoDaemon` scheduled task or a fresh top-level shell, not from a nested tool session. If a script must start it in-process, route the call through `Invoke-PaseoDaemon` rather than calling `paseo daemon start` directly.

**Recognize the general shape.** A long-lived daemon started by hand from a nested tool session captures that session's environment permanently, and every process it ever spawns inherits it. The blast radius is unbounded in time and invisible in the symptom: nothing in `Failed to fetch OpenCode providers: {}` points at an environment variable. Whenever a background service behaves differently depending on who started it, compare the live process environment against both the User and Machine registry scopes — a variable present in the process but absent from both scopes is proof of inheritance, and the process tree plus start timestamps will identify the launcher.

## Related Issues

- [`install/paseo-headless-setup.md`](../../../install/paseo-headless-setup.md) — documents starting the daemon directly and registering the `PaseoDaemon` scheduled task, with no mention that the invoking shell's environment is captured permanently. Refresh candidate.
- [`install/dev-stack.md`](../../../install/dev-stack.md) — reference for the supervisor's `start` / `install` / `fix` commands, which are the code paths patched here. Does not yet document the env-stripping behavior. Refresh candidate.
- [`docs/plans/2026-07-28-001-feat-paseo-plan-execution-supervisor-plan.md`](../../plans/2026-07-28-001-feat-paseo-plan-execution-supervisor-plan.md) — adjacent concern: scrubbing supervisor/operator secrets from a Paseo-delegated worker's environment. Same theme of env hygiene around Paseo-spawned processes, different mechanism and direction.
- `docs/open_items_register.md` — OIR-001 tracks Paseo worker sandboxing/env scrubbing risk.
