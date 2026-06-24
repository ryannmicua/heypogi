# Event Type Reference

Every EventV2 event that the plugin listens to, mapped to the table it writes to.

| Event Type | Source | Table | Key Data Extracted |
|------------|--------|-------|-------------------|
| `session.next.prompt.promoted` | `SessionEvent.PromptLifecycle.Promoted` | `user_prompt` | `text`, `files`, `agents` from prompt |
| `session.next.text.ended` | `SessionEvent.Text.Ended` | `assistant_response` | Full response `text` |
| `session.next.compaction.ended` | `SessionEvent.Compaction.Ended` | `session_summary` | Compacted `text` with Goal, Decisions, Progress |
| `session.next.tool.called` | `SessionEvent.Tool.Called` | `tool_call`, `file_change` | `tool` name, `input`, file paths |
| `session.next.tool.success` | `SessionEvent.Tool.Success` | `tool_call` | Sets `success = 1` |
| `session.next.tool.failed` | `SessionEvent.Tool.Failed` | `tool_call` | Sets `success = 0`, stores `error_message` |
| `session.next.step.ended` | `SessionEvent.Step.Ended` | `step` | `agent`, `model`, `finish`, `cost`, `tokens` |
| `session.next.step.failed` | `SessionEvent.Step.Failed` | `step` | Sets `failed = 1`, stores `error_message` |
| `session.next.shell.started` | `SessionEvent.Shell.Started` | `shell_command` | `command` string |
| `session.next.agent.switched` | `SessionEvent.AgentSwitched` | `agent_switch` | `agent` name |
| `session.next.model.switched` | `SessionEvent.ModelSwitched` | `model_switch` | `model.id`, `model.providerID`, `variant` |
| `session.next.retried` | `SessionEvent.Retried` | `retry` | `attempt`, `error.message`, `error.statusCode` |
| `permission.asked` | `Permission.Event.Asked` | `permission` | `permission` type, `patterns`, `tool` |
| `permission.replied` | `Permission.Event.Replied` | `permission` | `reply` (once/always/reject) |

## Events NOT Captured

| Event Type | Reason |
|------------|--------|
| `session.next.prompt.admitted` | Redundant with `promoted` (same data, earlier stage) |
| `session.next.prompted` | Legacy v1 event |
| `session.next.interrupt.requested` | User interrupt — no meaningful data |
| `session.next.context.updated` | System context changes — internal OpenCode state |
| `session.next.synthetic` | Auto-generated messages, not user behavior |
| `session.next.shell.ended` | Redundant with `shell.started` (output not analyzed) |
| `session.next.tool.input.started/ended` | Raw tool input streaming — redundant with `tool.called` |
| `session.next.tool.progress` | Running tool state — not a terminal event |
| `session.next.text.started` | Streaming start — redundant with `text.ended` |
| `session.next.text.delta` | Ephemeral stream fragment — not persisted |
| `session.next.reasoning.*` | Model reasoning — not user behavior |
| `session.next.compaction.started/delta` | Redundant with `compaction.ended` |
| `plugin.added`, `catalog.updated`, etc. | Infrastructure events, not user behavior |

## Event Data Shape

All events include:
- `id`: Event ID
- `type`: Event type string (as listed above)
- `properties`: Event data object (columns in `Base` for session events: `timestamp`, `sessionID`)
- `location?`: Directory and workspace context

The plugin receives events already filtered to the current project directory by OpenCode's event bridge.
