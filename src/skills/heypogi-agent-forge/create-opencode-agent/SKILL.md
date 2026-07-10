---
name: create-opencode-agent
description: Create or modify OpenCode agent definitions. Use when the user asks to create an agent, add an agent, define an agent, make a new agent, or configure agent settings. Covers both JSON inline and Markdown file formats.
---

# Create OpenCode Agent

This skill describes how to define OpenCode agents — specialized AI assistants with custom prompts, models, and tool access.

## Two definition formats

### 1. Inline JSON (in `opencode.json`)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "my-agent": {
      "description": "What this agent does and when to use it",
      "mode": "subagent",
      "model": "provider/model-id",
      "temperature": 0.1,
      "top_p": 0.9,
      "color": "#ff6b6b",
      "steps": 10,
      "hidden": false,
      "permission": {
        "edit": "deny",
        "bash": { "git *": "allow", "*": "ask" }
      },
      "prompt": "You are a specialized agent..."
    }
  }
}
```

### 2. Markdown file (preferred for non-trivial agents)

Place in:
- **Project**: `.opencode/agents/<name>.md`
- **Global**: `~/.config/opencode/agents/<name>.md`

The filename (without `.md`) becomes the agent name.

```markdown
---
description: One sentence — what the agent does and when to use it.
mode: subagent
model: provider/model-id
temperature: 0.1
permission:
  edit: deny
  bash: deny
---

You are a specialized agent. Focus on...
Instructions go here in the body.
```

## Frontmatter fields

| Field | Required | Description |
|---|---|---|
| `description` | Yes | What the agent does and when to invoke it. Also used by other agents (via Task tool) to decide which subagent to call. |
| `mode` | No | `"primary"` (Tab-switchable), `"subagent"` (@-mention only), or `"all"`. Default: `"all"`. |
| `model` | No | Override the model: `"provider/model-id"`. Subagents inherit the calling agent's model if omitted. |
| `permission` | No | Tool access rules. Keys: `read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`, `external_directory`, `todowrite`, `webfetch`, `websearch`, `lsp`, `skill`, `question`, `doom_loop`. Value: `"allow"`, `"ask"`, `"deny"`, or a glob-pattern object for fine-grained control. |
| `temperature` | No | Randomness (0.0–1.0). Lower = more focused/deterministic. |
| `top_p` | No | Nucleus sampling alternative to temperature (0.0–1.0). |
| `steps` | No | Max agentic iterations before forced text-only response. |
| `hidden` | No | Hide from `@` autocomplete (only for `mode: subagent`). |
| `color` | No | Hex color (`#FF5733`) or theme color (`primary`, `secondary`, `accent`, `success`, `warning`, `error`, `info`). |
| `disable` | No | Set to `true` to remove the agent. |
| `variant` | No | Model variant override. |

Any unknown frontmatter field is passed through to the provider as a model option.

## Permission details

Permission keys that accept a flat action or a glob-pattern object: `read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`, `external_directory`, `lsp`, `skill`.

Flat action:
```yaml
permission:
  edit: deny
  bash: ask
```

Glob-pattern object (last match wins — put `"*"` first, then specific rules):
```yaml
permission:
  bash:
    "*": ask
    "git status *": allow
    "grep *": allow
```

Permission keys that only accept a flat action: `todowrite`, `webfetch`, `websearch`, `question`, `doom_loop`.

`permission.task` controls which subagents this agent can invoke via the Task tool:
```yaml
permission:
  task:
    "*": deny
    "docs-*": allow
    "code-reviewer": ask
```

## Prompt

- In JSON: the `prompt` field is the system prompt string.
- In Markdown: the file body (after frontmatter) is the system prompt.
- Use `"{file:./relative/path.txt}"` to load a prompt from an external file.

Keep prompts focused and specific. Avoid generic instructions.

## Built-in agents

OpenCode ships with these agents:

| Agent | Mode | Purpose |
|---|---|---|
| `build` | primary | Default agent, all tools enabled. |
| `plan` | primary | Planning/analysis, edit + bash default to `ask`. |
| `general` | subagent | Multi-step research and execution, all tools except todowrite. |
| `explore` | subagent | Fast read-only codebase exploration. |
| `scout` | subagent | Read-only external docs and dependency research. |

To override a built-in, define a key with the same name in `agent: { ... }`.

To disable a built-in: `"agent": { "explore": { "disable": true } }`.

## Best practices

### 1. Write a sharp `description`
This is the only signal the model gets when deciding whether to delegate to your agent. Front-load concrete trigger keywords. Bad: "Helps with code." Good: "Reviews PR diffs for security vulnerabilities using semgrep patterns."

### 2. Use Markdown files, not JSON inline
File-based agents keep `opencode.json` small and make agents independently editable, shareable, and version-controllable.

### 3. Lock down permissions by default
Start restrictive and open up as needed. A reviewer agent should have `edit: deny`. A docs agent probably doesn't need `bash`.

```yaml
permission:
  edit: deny
  bash:
    "*": ask
    "git status *": allow
    "grep *": allow
```

### 4. Use the right model for the job
Expensive models for code review; cheap/fast models for lint checks or formatting. Subagents inherit the caller's model unless overridden.

### 5. Set an appropriate `mode`
- `subagent` for focused task specialists (code review, docs, testing)
- `primary` for agents the user will Tab-switch between during a session

### 6. Keep prompts focused
One job per agent. If an agent has many responsibilities, it becomes harder for the model to delegate correctly. Split into multiple single-purpose agents.

### 7. Use `hidden: true` for internal agents
If an agent should only be invoked programmatically via the Task tool (not by user @-mention), mark it hidden.

### 8. Set `steps` for cost control
Limit agentic iterations on agents that tend to loop or run expensive models.

### 9. Prefer permission over deprecated `tools`
The `tools` field still works but `permission` is more expressive (supports glob patterns and per-action rules).

### 10. Remember to restart
Config is loaded once at startup. After creating or editing an agent, the user must quit and restart opencode for changes to take effect.

## Examples

### Simple code reviewer (file)
```markdown
---
description: Reviews code for best practices, bugs, and security issues.
mode: subagent
model: anthropic/claude-sonnet-4-20250514
permission:
  edit: deny
  bash:
    "*": ask
    "git diff*": allow
    "git log*": allow
---

You are a code reviewer. Focus on:
- Correctness and edge cases
- Security vulnerabilities
- Performance implications
- Code style and maintainability
```

### Docs writer (file)
```markdown
---
description: Writes and maintains project documentation.
mode: subagent
permission:
  edit: allow
  bash: deny
---

You are a technical writer. Create clear, comprehensive documentation.
Focus on clear explanations, proper structure, and user-friendly language.
```

### Security auditor with color (file)
```markdown
---
description: Performs security audits and identifies vulnerabilities.
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
color: error
permission:
  edit: deny
  bash: ask
---

You are a security expert. Look for:
- Input validation vulnerabilities
- Authentication and authorization flaws
- Data exposure risks
- Dependency vulnerabilities
- Configuration security issues
```
