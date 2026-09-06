---
title: "Distinguishing Paseo agent sessions from opencode sessions for history lookup"
date: 2026-09-06
category: setup
module: "tooling/agent-sessions"
problem_type: documentation_gap
component: tooling
severity: low
applies_when:
  - "Looking up history for a Paseo agent session"
  - "Agent gives 'no output' or loads wrong skill for session lookup"
tags: [paseo, opencode, session-history, skill-creation, agent-tooling]
---

# Distinguishing Paseo agent sessions from opencode sessions for history lookup

## Context

When asked to read a Paseo agent session by UUID, the agent loaded the `opencode-session-history` skill and tried `probe.py` against `opencode.db`. This returned no output because Paseo agents are not stored in the opencode SQLite database. The agent then discovered Paseo agents are accessed via the `paseo` CLI (`inspect`, `logs`, `ls`) and created a new skill to document this.

## Guidance

**Determine the session system before loading a skill.**

| Session format | System | Access method |
|----------------|--------|---------------|
| UUID (`17d9c3b8-...`) with "paseo" context | Paseo | `paseo inspect`, `paseo logs`, `paseo ls` |
| `ses_` prefix (`ses_f8c605371...`) | opencode | `probe.py extract`, `probe.py find`, `probe.py list` |

**Paseo CLI commands for session history:**

```bash
paseo ls --json                           # List all agents
paseo inspect <agent-id> --json           # Agent details (name, status, tokens, cost)
paseo logs <agent-id> --json              # Activity timeline (User/Thought/Shell events)
paseo attach <agent-id>                   # Live streaming output
```

**Cross-system keyword search:** Paseo has no built-in keyword search. Combine with `jq`:

```bash
paseo ls --json | jq '.[] | select(.Name | test("keyword"; "i"))'
```

Or use `opencode-session-history` for opencode sessions separately.

## Why This Matters

Confusing the two systems wastes investigation time. The `opencode-session-history` skill explicitly documents it only covers opencode sessions, but the error message (empty output from `probe.py`) gives no signal about why - it just silently returns nothing. A skill for Paseo session lookup makes the distinction discoverable.

## When to Apply

- Asked to read or look up a Paseo agent session
- Asked to find what a Paseo agent did during its run
- Debugging across both Paseo and opencode sessions

## Examples

**Wrong approach (what happened):**
1. User: "read paseo agent session 17d9c3b8-..."
2. Agent loads `opencode-session-history` skill
3. Runs `probe.py extract 17d9c3b8-...` against opencode.db
4. Gets no output (wrong database)

**Correct approach:**
1. User: "read paseo agent session 17d9c3b8-..."
2. Agent recognizes UUID + "paseo" context
3. Runs `paseo inspect 17d9c3b8-... --json` for details
4. Runs `paseo logs 17d9c3b8-... --json` for timeline

## Related

- `docs/solutions/runtime-errors/paseo-daemon-inherits-opencode-server-password.md` - adjacent Paseo environment issue
- `~/.agents/skills/heypogi/dev-tool-reference/paseo-session-history/SKILL.md` - the skill created from this learning (global, not in repo)
- `~/.agents/skills/heypogi/dev-tool-reference/opencode-session-history/SKILL.md` - the opencode counterpart (global, not in repo)
