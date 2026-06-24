# Database Schema Reference

The central SQLite database at `~/.local/share/opencode-learn/learn.db` stores all collected data across projects.

## Tables

### project

Projects (directories) that have been observed.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-incrementing ID |
| `directory` | TEXT UNIQUE | Absolute path to the project root |
| `first_seen_at` | TEXT | ISO 8601 timestamp of first event |
| `last_seen_at` | TEXT | ISO 8601 timestamp of most recent event |

### user_prompt

Every user prompt sent to the agent.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `text` | TEXT | Full prompt text |
| `agent_refs` | TEXT | JSON array of @agent names used in the prompt |
| `has_files` | INTEGER | 1 if files were attached, 0 otherwise |
| `delivery` | TEXT | `"steer"` or `"queue"` |
| `created_at` | TEXT | ISO 8601 timestamp |

### assistant_response

Full text of each assistant response (one per text generation step).

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `assistant_message_id` | TEXT | Message ID within the session |
| `text` | TEXT | Full response text |
| `agent` | TEXT | Agent that generated the response (from step event) |
| `model` | TEXT | Model used (from step event) |
| `created_at` | TEXT | ISO 8601 timestamp |

### session_summary

Structured summaries produced by session compaction.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `text` | TEXT | Compacted summary (Goal, Progress, Decisions, Next Steps, etc.) |
| `recent` | TEXT | Recent verbatim conversation retained after compaction |
| `reason` | TEXT | `"auto"` or `"manual"` |
| `created_at` | TEXT | ISO 8601 timestamp |

### tool_call

Every tool invocation.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `tool_name` | TEXT | Tool name (e.g. `"bash"`, `"read"`, `"write"`) |
| `input` | TEXT | JSON-serialized tool input parameters |
| `success` | INTEGER | 0 while pending, 1 on success, 0 on failure |
| `error_message` | TEXT | Error message if tool failed |
| `created_at` | TEXT | ISO 8601 timestamp |

### file_change

File paths extracted from tool call inputs for read/write/edit/glob/grep tools.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `tool_name` | TEXT | Tool that touched this file |
| `file_path` | TEXT | File path extracted from tool input |
| `created_at` | TEXT | ISO 8601 timestamp |

### step

LLM step outcomes.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `agent` | TEXT | Agent used for this step |
| `model` | TEXT | JSON-serialized model reference `{id, providerID}` |
| `finish` | TEXT | Finish reason (e.g. `"stop"`, `"length"`, `"tool_use"`) |
| `failed` | INTEGER | 1 if step failed, 0 otherwise |
| `error_message` | TEXT | Error message if step failed |
| `cost` | REAL | Step cost in dollars |
| `tokens_input` | INTEGER | Input tokens |
| `tokens_output` | INTEGER | Output tokens |
| `tokens_reasoning` | INTEGER | Reasoning tokens |
| `created_at` | TEXT | ISO 8601 timestamp |

### shell_command

Commands executed via the shell tool.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `command` | TEXT | Full command string |
| `output_snippet` | TEXT | Truncated command output (not yet populated) |
| `created_at` | TEXT | ISO 8601 timestamp |

### agent_switch

Agent changes during sessions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `agent` | TEXT | Agent name switched to |
| `created_at` | TEXT | ISO 8601 timestamp |

### model_switch

Model changes during sessions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `model_id` | TEXT | Model identifier |
| `provider_id` | TEXT | Provider identifier |
| `variant` | TEXT | Model variant (e.g. `"high"`, `"max"`) |
| `created_at` | TEXT | ISO 8601 timestamp |

### retry

Provider retry events.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `attempt` | INTEGER | Retry attempt number |
| `error_message` | TEXT | Error description |
| `error_status_code` | INTEGER | HTTP status code if applicable |
| `created_at` | TEXT | ISO 8601 timestamp |

### permission

Permission requests and user responses.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `permission_type` | TEXT | Permission type (e.g. `"bash"`, `"write"`, `"read"`) |
| `patterns` | TEXT | JSON array of affected file patterns |
| `tool_name` | TEXT | Tool name that triggered the permission |
| `user_response` | TEXT | `"once"`, `"always"`, `"reject"`, or NULL if pending |
| `created_at` | TEXT | ISO 8601 timestamp of the request |
| `replied_at` | TEXT | ISO 8601 timestamp of the response |

### correction

User corrections detected by the passive classifier.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `classification` | TEXT | One of: `skill_misuse`, `memory_update`, `behavioral`, `rule`, `preference` |
| `user_text` | TEXT | The user's correction prompt |
| `assistant_context` | TEXT | The assistant's preceding response (first 2000 chars) |
| `tool_context` | TEXT | The last tool used before the correction |
| `created_at` | TEXT | ISO 8601 timestamp |
| `resolved` | INTEGER | 1 if processed by analysis tool, 0 otherwise |

### preference

User preferences stated unprompted (not as corrections).

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `session_id` | TEXT | OpenCode session ID |
| `category` | TEXT | Classification category (same kinds as corrections) |
| `user_text` | TEXT | The user's preference statement |
| `created_at` | TEXT | ISO 8601 timestamp |

### proposed_rule

Rule proposals generated by the analysis tool, pending human review.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | |
| `project_id` | INTEGER FK | References `project(id)` |
| `classification` | TEXT | Source classification |
| `instruction` | TEXT | Proposed rule instruction text |
| `evidence` | TEXT | JSON with example texts and tool contexts |
| `freq` | INTEGER | Number of times this pattern appeared |
| `status` | TEXT | `"pending"`, `"approved"`, `"rejected"`, or `"merged"` |
| `created_at` | TEXT | ISO 8601 timestamp |
| `reviewed_at` | TEXT | ISO 8601 timestamp of human review |

## Indexes

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_tool_call_project` | `project_id` | Filter tool calls by project |
| `idx_tool_call_name` | `tool_name` | Aggregate by tool |
| `idx_session_summary_project` | `project_id` | Filter summaries by project |
| `idx_step_project` | `project_id` | Filter steps by project |
| `idx_user_prompt_project` | `project_id` | Filter prompts by project |
| `idx_correction_project` | `project_id` | Filter corrections by project |
| `idx_correction_classification` | `classification` | Aggregate corrections by kind |
| `idx_correction_resolved` | `resolved` | Find unresolved corrections |
| `idx_proposed_rule_status` | `status` | Filter proposals by review status |
| `idx_permission_project` | `project_id` | Filter permissions by project |
| `idx_file_change_project` | `project_id` | Filter file changes by project |
| `idx_preference_project` | `project_id` | Filter preferences by project |
