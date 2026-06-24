# Architecture

## Overview

opencode-learn is a passive observation plugin for OpenCode that captures session data, detects user corrections, and enables pattern analysis — without requiring any user action.

```
┌────────────────────────────────────────────────────────────────┐
│                     OpenCode Process                            │
│                                                                │
│  ┌─────────────────┐       ┌──────────────────────────────┐   │
│  │  EventV2 System  │──────▶│  opencode-learn Plugin       │   │
│  │  (event sourcing) │       │                              │   │
│  │                  │       │  events.listen(listener)      │   │
│  │  Tool.Called     │       │  ┌────────────────────────┐  │   │
│  │  Step.Ended      │       │  │  In-memory tracker     │  │   │
│  │  Prompt.Promoted │       │  │  (last assistant text, │  │   │
│  │  Permission.*    │       │  │   last tool per session)│  │   │
│  │  Compaction.Ended│       │  └───────────┬────────────┘  │   │
│  │  ...             │       │              │               │   │
│  └─────────────────┘       │              ▼               │   │
│                            │  ┌────────────────────────┐  │   │
│                            │  │  Classifier            │  │   │
│                            │  │  (regex, no LLM)       │  │   │
│                            │  │  - isLikelyCorrection  │  │   │
│                            │  │  - classify()          │  │   │
│                            │  │  - detectPreference()  │  │   │
│                            │  └───────────┬────────────┘  │   │
│                            │              │               │   │
│                            │              ▼               │   │
│                            │  ┌────────────────────────┐  │   │
│                            │  │  Batch Writer           │  │   │
│                            │  │  (2s interval,          │  │   │
│                            │  │   transaction batch)    │  │   │
│                            │  └───────────┬────────────┘  │   │
│                            └──────────────┼───────────────┘   │
└───────────────────────────────────────────┼───────────────────┘
                                            │
                                            ▼
                  ┌──────────────────────────────────────────┐
                  │  Central SQLite DB                        │
                  │  ~/.local/share/opencode-learn/learn.db   │
                  │                                           │
                  │  Tables: project, user_prompt,            │
                  │  assistant_response, session_summary,     │
                  │  tool_call, file_change, step,            │
                  │  shell_command, agent_switch,             │
                  │  model_switch, retry, permission,         │
                  │  correction, preference, proposed_rule    │
                  └──────────────────────────────────────────┘
                                            │
                                            ▼
                  ┌──────────────────────────────────────────┐
                  │  Analysis Tool (bun src/analyze.ts)      │
                  │                                           │
                  │  Clusters corrections → flags graduates   │
                  │  → writes proposed_rule → human reviews   │
                  └──────────────────────────────────────────┘
```

## Design Decisions

### Why a Plugin, Not a Fork

The plugin is an npm package loaded by OpenCode's built-in plugin system. No fork, no patching, no recompilation. It can be installed, updated, and removed independently.

### Why Passive Observation

The user's requirement was "minimal to no action from me." Passive observation — listening to events that OpenCode already fires — means the plugin collects data without any UI, CLI commands, or user workflow changes.

### Why Central SQLite, Not Per-Project

Each OpenCode instance stores session data in its own project-local SQLite database. A user-level database aggregates across projects, enabling cross-project pattern analysis — which tools you use across all projects, which preferences are consistent, and which corrections recur regardless of codebase.

### Why Deterministic Classification, Not LLM

Per the Jozefiak corrections-loop pattern and Nakajima's warning: using an LLM to classify corrections "gives you an agent that learns the wrong lessons confidently." The plugin uses regex patterns — cheap, deterministic, and auditable. Items that don't match any pattern are silently skipped rather than miscategorized.

### Why In-Memory Tracking for Corrections

The correction detector needs to know what the assistant last said in order to detect user pushback. This is stored in a per-session Map, which is process-local and resets on restart. This is acceptable because:
- Corrections are detected in real-time during the same session
- Persisting this state across restarts would add complexity for marginal gain
- The full conversation is already in `user_prompt` and `assistant_response` tables for later analysis

## Data Flow

### Collection Path

```
EventV2 event → EventV2Bridge → Plugin event hook → Classifier → Batch writer → SQLite
```

Each event takes this path. The batch writer collects writes for 2 seconds then flushes in a single transaction, keeping write overhead negligible.

### Correction Detection Path

```
Assistant response arrives → stored in memory map (trackAssistantResponse)
    ...
User prompt arrives → detectCorrection() checks:
  1. Is there a stored assistant response? (if not, skip)
  2. Does the prompt match SIGNAL_PATTERNS? (if not, skip)
  3. Does the prompt match CLASSIFICATION RULES? (if not, skip)
  4. If all pass → store correction, consume context (prevent double-fire)
    ...
If correction not detected → detectPreference() checks:
  1. Does the prompt match PREFERENCE_SIGNALS? (if not, skip)
  2. Does it match a classification? (if not, skip)
  3. If all pass → store preference
```

### Analysis Path

```
Corrections DB → loadClusters() → group by classification + normalized text
    → flag items with freq >= 2 as "graduate candidates"
    → produce markdown report (dry run)
    → or write to proposed_rule table (--apply)
    → human reviews and approves/rejects
```

## Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| No skill activation events | Can't detect which skills trigger | Analyze prompt text for skill keywords at query time |
| No session boundaries | Can't measure session duration | Session events are V1-only; not bridged |
| No undo/redo detection | Misses this correction signal | Could grep shell commands for git checkout/restore |
| In-memory tracker (process-local) | Corrections missed on restart | Acceptable — only matters for same-session detection |
| Regex classifier (not NLP) | False negatives for subtle corrections | Better than false positives; analysis phase catches patterns over time |
