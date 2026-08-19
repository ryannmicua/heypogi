---
name: paseo-reference
description: >-
  Use when the user asks about paseo.sh — how it works, how to use it, how to
  configure it, how to troubleshoot it, or how to find answers in the source.
  Triggers include "paseo", "paseo.sh", "paseo daemon", "paseo config", "paseo
  broke", "paseo won't start", "paseo can't find", "how do I paseo", "paseo
  help", "paseo CLI", "paseo providers", "paseo troubleshooting", or any paseo
  error or setup question. Also use when another paseo skill needs a factual
  reference on providers, configuration, CLI commands, the daemon, or the repo
  layout.
---

# Paseo Reference

Comprehensive reference for Paseo — architecture, usage, configuration, and
troubleshooting. This skill resolves questions by reading the live docs at
[paseo.sh/docs](https://paseo.sh/docs), browsing the
[GitHub repo](https://github.com/getpaseo/paseo), or cloning the repo locally
to inspect source.

## When to Use

```
Q: "Is this a paseo question?"
  ├─ Setup / install / config / CLI? → Use this skill
  ├─ Something is broken / can't find provider / won't start? → Use this skill
  ├─ "How do I..." with paseo? → Use this skill
  ├─ Need to understand paseo internals? → Use this skill
  └─ Orchestrating agents / handoff / loop / committee? → Use the specific
     paseo skill (paseo-handoff, paseo-loop, paseo-committee, paseo-advisor)
```

**Don't use for:** orchestrating agents with paseo skills — those skills
self-reference the `paseo` skill for their foundational knowledge. This
skill is for understanding paseo itself, not for driving agent workflows.

## Information Sources

Three sources, in order of freshness. Always cite which source you used.

### 1. Live docs (preferred for most questions)

Fetch pages from [https://paseo.sh/docs](https://paseo.sh/docs) with the
`webfetch` tool. Key pages:

| Page | URL | When to fetch |
|------|-----|---------------|
| Getting started | `https://paseo.sh/docs` | Install, setup, prerequisites |
| CLI reference | `https://paseo.sh/docs/cli` | Any CLI command or flag |
| Configuration | `https://paseo.sh/docs/configuration` | config.json, env vars, worktrees |
| Troubleshooting | `https://paseo.sh/docs/troubleshooting` | Provider not found, PATH, logs |
| Supported providers | `https://paseo.sh/docs/supported-providers` | Provider list, native vs ACP |
| Custom providers | `https://paseo.sh/docs/custom-providers` | Endpoints, profiles, custom binaries |
| Security | `https://paseo.sh/docs/security` | Auth, password, relay encryption |
| Docker | `https://paseo.sh/docs/docker` | Container deployment |
| Workspaces | `https://paseo.sh/docs/workspaces` | Workspace model |
| Worktrees | `https://paseo.sh/docs/worktrees` | Git worktree isolation |
| Web UI | `https://paseo.sh/docs/web-ui` | Self-hosting the web UI |

Append `.md` to the URL for raw markdown, e.g.
`https://paseo.sh/docs/troubleshooting.md`.

### 2. GitHub repo (for source code, issues, internals)

Repo: [https://github.com/getpaseo/paseo](https://github.com/getpaseo/paseo)

Use the `webfetch` tool to browse files, issues, and PRs. Monorepo layout:

| Directory | Purpose |
|-----------|---------|
| `packages/server` | Daemon (agent orchestration, WebSocket API, MCP server) |
| `packages/app` | Expo client (iOS, Android, web) |
| `packages/cli` | `paseo` CLI |
| `packages/desktop` | Electron desktop app |
| `packages/relay` | Remote connectivity relay |
| `packages/website` | Marketing site and docs (`paseo.sh`) |
| `public-docs/` | Source for the public docs site |
| `docs/` | Internal development docs |
| `skills/` | Bundled orchestrator skills |
| `.agents/skills/` | Agent skill definitions for the repo itself |

Key files for troubleshooting:
- `packages/desktop/src/login-shell-env.ts` — how Paseo resolves your login shell environment
- `packages/server/src/` — daemon internals
- `public-docs/troubleshooting.md` — canonical troubleshooting source

To clone the repo locally for deeper inspection:

```bash
git clone https://github.com/getpaseo/paseo.git ~/tmp/paseo-source
```

Then use `grep`, `glob`, and `read` tools on the cloned directory. When done,
clean up:

```bash
rm -rf ~/tmp/paseo-source
```

### 3. Existing paseo skill (for orchestrator-tool reference)

The existing `paseo` skill at `~/.agents/skills/paseo/SKILL.md` contains the
tool/API reference for Paseo's MCP surface — exactly the functions available
to an agent for creating agents, managing worktrees, discovering providers,
etc. Read it when you need the exact tool signatures.

## Architecture

```
┌──────────┐  ┌────────┐  ┌───────┐  ┌──────────┐
│  Desktop │  │ Mobile │  │  CLI  │  │  Web UI  │  ← clients
└────┬─────┘  └───┬────┘  └───┬───┘  └────┬─────┘
     │            │          │            │
     └────────────┴──────────┴────────────┘
                      │  HTTP/WS (port 6767)
               ┌──────┴──────┐
               │   Daemon    │  ← agent lifecycle, state, MCP
               └──────┬──────┘
                      │  spawns & supervises
        ┌─────────────┼─────────────┐
   ┌────┴────┐  ┌─────┴─────┐  ┌───┴────┐
   │ Claude  │  │   Codex   │  │ OpenCode│  ← agent processes
   └─────────┘  └───────────┘  └────────┘
```

Paseo is a daemon that supervises AI coding agent processes. All clients
(desktop, mobile, CLI, web) talk to the daemon through HTTP and WebSocket on
`127.0.0.1:6767`. The daemon handles agent lifecycle (spawn, supervise, kill),
persists state to `~/.paseo/`, and exposes an MCP server for agent
orchestration.

## Quick Reference

### Installation

| Platform | Command |
|----------|---------|
| Desktop app | [paseo.sh/download](https://paseo.sh/download) |
| CLI (npm) | `npm install -g @getpaseo/cli` |
| Docker | `ghcr.io/getpaseo/paseo:latest` |

Prerequisites: install at least one provider CLI (Claude Code, Codex, OpenCode,
Copilot) and `gh` (GitHub CLI). Paseo does not bundle agents.

### Essential CLI

```bash
paseo                                  # Start daemon
paseo run "fix the tests"              # Start an agent
paseo ls                               # List running agents
paseo attach <id>                      # Stream agent output
paseo send <id> "also fix linting"     # Follow-up task
paseo logs <id>                        # View agent timeline
```

### Daemon management

```bash
paseo daemon start                     # Start daemon
paseo daemon start --web-ui            # Start + serve web UI
paseo daemon status                    # Check status
paseo daemon restart                   # Restart (agents survive)
paseo daemon stop                      # Stop daemon
paseo daemon set-password              # Set auth password
paseo daemon pair --json               # Get pairing URL
```

### Agent management

```bash
paseo run --provider codex "build the API"
paseo run --background "run tests"      # Don't wait
paseo run --isolation worktree "implement feature X"
paseo run --workspace <id> "review diff"
paseo agent mode <id> plan
paseo agent mode <id> bypass
paseo agent detach <id>                 # Subagent → top-level
paseo stop <id>                         # Stop agent
paseo wait <id> --timeout 60
```

### Schedules

```bash
paseo schedule create --every 30m "Continue the refactor"
paseo schedule ls
paseo schedule pause <id>
```

### Connecting remotely

```bash
# Get a pairing URL from the daemon machine
paseo daemon pair --json

# Use it from any machine
paseo ls --host 'https://app.paseo.sh/#offer=eyJ2IjoyLC...'
paseo run --host "$OFFER_URL" "fix the tests"

# Direct connection
paseo --host 192.168.1.10:6767 ls
```

### Key filesystem paths

| Path | Purpose |
|------|---------|
| `~/.paseo/` | Paseo home (override `PASEO_HOME`) |
| `~/.paseo/config.json` | Configuration |
| `~/.paseo/daemon.log` | Daemon logs |
| `~/.paseo/agents/<id>.json` | Agent state |
| `~/.paseo/worktrees/` | Managed worktrees (override `worktrees.root`) |
| `~/.paseo/paseo.pid` | Daemon PID file |
| `~/.paseo/orchestration-preferences.json` | Provider preferences for skills |

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PASEO_HOME` | Override paseo home directory |
| `PASEO_LISTEN` | Override listen address |
| `PASEO_PASSWORD` | Daemon password (plaintext on daemon; auth token for clients) |
| `PASEO_HOST` | Default daemon host for CLI |
| `PASEO_WEB_UI_ENABLED` | Enable bundled web UI |
| `PASEO_HOSTNAMES` | Allowed hostnames for CORS/routing |

## Troubleshooting

Follow this order for any "paseo broke" scenario.

### 0. Is Paseo running?

```bash
paseo daemon status
# or
curl -s localhost:6767/api/health
```

If not: start it. If `paseo` itself is missing from PATH, see the
bundled CLI paths in the existing `paseo` skill (ops section).

### 1. Check the daemon log

```bash
tail -n 200 ~/.paseo/daemon.log
```

For the desktop app, also check:
- macOS: `~/Library/Logs/Paseo/main.log`
- Linux: `~/.config/Paseo/logs/main.log`
- Windows: `%APPDATA%\Paseo\logs\main.log`

Look for `[login-shell-env]` entries: `applied` = env loaded correctly;
`failed; keeping inherited env` = shell env didn't load, check for slow or
erroring `.zshrc`/`.zprofile`.

### 2. Provider not found / "Not installed"

This is the single most common problem. Paseo claims a provider is not
installed even though it works in your terminal.

**Diagnose:** Open Settings → your host → Providers → tap the provider →
**Diagnostic**. Look at:
- **Resolved path** — `not found` means Paseo can't find the binary
- **Daemon PATH** — compare with `echo $PATH` in a fresh terminal
- **Version** — whether the binary is runnable

**Root cause:** Paseo's PATH differs from your terminal's. Version managers
(asdf, mise, nvm) are the usual culprits — they initialize in interactive
shells but not necessarily in login shells.

**Fix:**
1. Make the command available in a clean login shell — open a fresh terminal
   and verify: `which claude` (or whichever provider). If it fails there,
   Paseo will fail too.
2. Fix your shell config (`.zshrc`, `.zprofile`, `.bashrc`) so the command
   works in a login shell.
3. Restart Paseo: `paseo daemon restart`

**Quick workaround** — pin the binary path in `~/.paseo/config.json`:
```json
{
  "agents": {
    "providers": {
      "claude": {
        "command": ["/absolute/path/to/claude"]
      }
    }
  }
}
```

Find the real path with `which -a claude`. Restart the daemon after editing.

### 3. Config changes not taking effect

`config.json` is read at daemon startup. Restart the daemon:
```bash
paseo daemon restart
```

### 4. Agent stuck / not responding

```bash
paseo ls                    # Check agent status
paseo logs <id> --tail 20   # Last activity
paseo attach <id>           # Live stream (Ctrl+C to detach)
paseo stop <id>             # Force-stop
```

Check `~/.paseo/agents/<id>.json` for the raw state file.

### 5. Permission loop / agent needs approval

```bash
paseo permit ls               # List pending
paseo permit allow <id>       # Allow all for that agent
paseo permit deny <id> --all  # Deny all
```

### 6. Connection issues (mobile/web can't connect)

- Daemon must be listening on an address reachable by the client.
- If using a password: `paseo daemon set-password`
- If using relay: get a fresh pairing URL with `paseo daemon pair --json`
- Check firewall allows port 6767
- For direct connection: `paseo --host "tcp://192.168.1.10:6767?password=yourpass" ls`

### 7. "command not found" inside agent terminals

Same root cause as provider not found — the agent inherits the daemon's
environment. Fix your login shell config so the tool is on PATH for a clean
login shell, then restart the daemon.

### 8. Still stuck

- Search [GitHub Issues](https://github.com/getpaseo/paseo/issues) for the
  error message
- Check the [Discord](https://discord.gg/jz8T2uahpH) — fastest path to the
  maintainer
- Clone the repo and grep the source for relevant error strings

## Common Mistakes

- **Restarting the daemon without asking the user.** It kills all running
  agents. Always get explicit approval first.
- **Looking at agent logs instead of daemon logs.** Agent logs show what the
  agent did; daemon logs show what Paseo itself did (spawn failures, env
  issues, provider resolution).
- **Not checking PATH in a fresh terminal.** The test is: open a brand-new
  terminal and run the command. If it fails there, it will fail in Paseo.
- **Editing config.json without restarting the daemon.** Changes are only
  picked up at startup.
- **Using shell aliases/functions as provider commands.** Paseo runs binaries
  directly — `type -a <cmd>` to check if it's an alias.
- **Confusing paseo skills (orchestrator tools) with paseo itself.** The
  `paseo` skill teaches agents how to use paseo tools. This skill answers
  questions about paseo itself.
- **Using `opencode-go` as a provider name.** `opencode-go` is a model ID
  prefix within the `opencode` provider, not a provider itself. The correct
  format for `paseo_create_agent` is `provider/model` where model can contain
  slashes (e.g. `opencode/opencode-go/mimo-v2.5`). See
  `~/.paseo/orchestration-preferences.json` → `role_models` for exact strings.

## Provider/Model Format for Agent Creation

When using `paseo_create_agent`, the `provider` parameter must be in
`provider/model` format. The model ID can contain slashes.

**Correct examples:**
- `opencode/opencode-go/mimo-v2.5` (MiMo via OpenCode)
- `opencode/opencode-go/minimax-m3` (MiniMax via OpenCode)
- `codex/gpt-5.6-sol` (Codex native)
- `claude/claude-opus-5` (Claude native)

**Incorrect:**
- `opencode-go/minimax-m3` — `opencode-go` is not a configured provider
- `minimax-m3` — missing provider prefix

**Source of truth:** `~/.paseo/orchestration-preferences.json` → `role_models`
section maps roles (impl, audit, planning, etc.) to exact provider/model
strings. Always read this file before creating agents.
