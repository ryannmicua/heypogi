---
name: opencode-session-history
description: "Reads opencode's local session history from opencode.db and returns raw JSON (list, find, extract). Use when a task needs to know what happened in earlier opencode sessions: prior attempts, key decisions, or 'what did we try before'. Trigger keywords: session history, previous sessions, prior work, what was tried, opencode sessions."
---

# opencode-session-history

A low-level data provider for opencode's own session history. It reads the
local `opencode.db` (SQLite) and returns raw session data as JSON lines. It
does **not** interpret, rank, or summarize the data — the calling skill or
agent decides what the sessions mean and what to do with the information.

## When to use

- Any task that needs to know what happened in earlier opencode sessions:
  prior attempts, what didn't work, key decisions, related work.
- Filling a session-history gap in a workflow that probes session stores
  (e.g., Compound Engineering's `ce-compound` — its bundled session-history
  probe covers Claude Code, Codex, Cursor, and Pi, but not opencode).
- "What did we try before?" debugging or handoff preparation.

## Interface

Run the bundled probe script with one subcommand:

```
python scripts/probe.py list
python scripts/probe.py find --keywords workstream,jsonschema,runtime
python scripts/probe.py extract <session-id>
```

Common options (apply to `list` and `find`):

| Option | Default | Meaning |
|---|---|---|
| `--repo ROOT` | current directory | Only sessions whose directory is under ROOT |
| `--days N` | 7 | Only sessions updated within the last N days |
| `--keywords K1,K2` | — | Comma-separated keywords for hit counting |
| `--exclude-session ID` | — | Skip a session id (e.g., the caller's own session) |
| `--db PATH` | platform data dir | Path to `opencode.db` |

### `list`

One JSON object per session (most recent first) in the repo + time window.
Each object contains: `id`, `title`, `agent`, `model`, `directory`,
`time_created`, `time_updated` (epoch ms), `message_count`, `files_touched`,
`summary`, and `keyword_matches` when `--keywords` is given.

The `summary` field is mechanical (title + files touched + keyword hits), not
a model-generated narrative.

### `find`

Like `list`, but returns **only sessions with at least one keyword hit**,
ranked by total hit count descending. This is a mechanical pre-filter:
keyword hits are counted over user + assistant conversation text only (tool
calls, reasoning, file attachments, and patches are excluded). Use
`--min-hits N` to require more. Relevance judgment beyond the filter belongs
to the caller — `find` narrows the field, it does not decide.

### `extract <session-id>`

The session's ordered user + assistant text parts as JSON lines
(`{"role", "time_created", "text"}`), excluding tool calls, reasoning, file
attachments, patches, and step markers. Use this for the full transcript of a
session shortlisted via `list` or `find`.

## Contract with callers

- **Raw data, not interpretation.** `list` / `find` / `extract` return JSON;
  they never write prose summaries of what the sessions mean.
- **Deterministic only.** The only judgment in this skill is mechanical:
  repo scope, time window, keyword hit counting, conversation-text-only
  extraction. Anything requiring model judgment — relevance, "what was tried
  before", narrative synthesis — is the caller's responsibility.
- **Keyword matching is a pre-filter, not relevance.** Synonyms and
  one-line mentions will be missed; the caller should use the summaries
  returned by `find` to make the final relevance call.
- **Timestamps are epoch milliseconds**, matching what opencode stores.
- **Read-only.** The script opens `opencode.db` in read-only mode and never
  writes to it.
