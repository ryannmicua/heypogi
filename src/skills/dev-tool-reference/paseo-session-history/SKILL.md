---
name: paseo-session-history
description: >-
  Read Paseo agent sessions via the paseo CLI. Use when a task needs to know
  what happened in earlier Paseo agent sessions: prior attempts, key decisions,
  or "what did we try before". Trigger keywords: paseo session, paseo agent
  history, previous paseo agents, paseo logs, what did the agent do, paseo
  agent transcript.
---

# paseo-session-history

A low-level data provider for Paseo agent session history. It uses the
`paseo` CLI to inspect agents and retrieve their activity timelines. It does
**not** interpret, rank, or summarize the data - the calling skill or agent
decides what the sessions mean and what to do with the information.

**Important:** This skill is for Paseo agent sessions only. For opencode
session history (the local SQLite database), use the `opencode-session-history`
skill instead.

## When to use

- Any task that needs to know what happened in earlier Paseo agent sessions:
  prior attempts, what didn't work, key decisions, related work.
- "What did we try before?" debugging or handoff preparation involving Paseo
  agents.
- Reviewing what a specific Paseo agent did during its run.

## Interface

### List recent agents

```bash
paseo ls --json
```

Returns JSON array of agents with: `Id`, `Name`, `Provider`, `Model`, `Status`,
`Cwd`, `CreatedAt`, `UpdatedAt`.

Filter by status:

```bash
paseo ls --status idle --json
paseo ls --status running --json
```

### Get agent details

```bash
paseo inspect <agent-id> --json
```

Returns detailed JSON including: `Id`, `Name`, `Provider`, `Model`, `Status`,
`Cwd`, `CreatedAt`, `UpdatedAt`, `LastUsage` (tokens, cost), `Capabilities`,
`PendingPermissions`.

### Get agent activity timeline

```bash
paseo logs <agent-id> --json
```

Returns the agent's timeline as a JSON array of events. Each event contains
the role (User, Thought, Shell, etc.) and the content.

For a specific number of recent events:

```bash
paseo logs <agent-id> --limit 20 --json
```

### Search for agents by name/keywords

There is no built-in search command. To find agents matching keywords, list
all agents and filter:

```bash
paseo ls --json | jq '.[] | select(.Name | test("keyword"; "i"))'
```

Or combine with `opencode-session-history` for cross-system searches:

```bash
# Search Paseo agents
paseo ls --json | jq '.[] | select(.Name | test("paseo|password"; "i"))'

# Search opencode sessions (different system)
python3 scripts/probe.py find --keywords paseo,password
```

### Attach to a running agent

```bash
paseo attach <agent-id>
```

Streams live output until Ctrl+C. Use for real-time monitoring.

## Common workflow

1. **Find the agent:** `paseo ls --json` or `paseo inspect <id> --json`
2. **Get the timeline:** `paseo logs <id> --json`
3. **Read specific events:** Filter the JSON output for relevant events
4. **Cross-reference:** Use `opencode-session-history` for opencode sessions

## Contract with callers

- **Raw data, not interpretation.** `inspect` / `logs` return JSON; they
  never write prose summaries of what the sessions mean.
- **Read-only.** These commands do not modify agent state.
- **Timestamps are ISO 8601** (e.g., `2026-09-05T21:46:55.447Z`), as
  returned by the Paseo CLI.
- **Agent IDs are UUIDs** (e.g., `17d9c3b8-7abb-4d41-bd73-e87259868491`).

## Key filesystem paths

| Path | Purpose |
|------|---------|
| `~/.paseo/agents/<id>.json` | Raw agent state file |
| `~/.paseo/daemon.log` | Daemon logs (for spawn failures, env issues) |
| `~/.paseo/config.json` | Paseo configuration |

## Common mistakes

- **Confusing Paseo sessions with opencode sessions.** Paseo agents are
  accessed via `paseo` CLI. Opencode sessions are in `opencode.db` accessed
  via the `opencode-session-history` skill's `probe.py` script.
- **Using `paseo attach` for historical review.** `attach` streams live output
  and blocks. Use `paseo logs` for reviewing past activity.
- **Assuming keyword search exists.** `paseo ls` has no `--keywords` flag.
  Filter with `jq` or use `opencode-session-history` for keyword-based
  searches across both systems.
