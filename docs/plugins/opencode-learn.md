# opencode-learn Plugin

**Location:** `src/plugins/opencode-learn/`

Passive observation system for OpenCode that captures session data, detects user corrections, and enables pattern analysis — without requiring any user action.

## Quick Reference

| Action | Command |
|--------|---------|
| **Install** | `./src/plugins/opencode-learn/install/install.ps1` |
| **Run analysis** | `cd src/plugins/opencode-learn && bun src/analyze.ts` |
| **Write proposals** | `bun src/analyze.ts --apply` |
| **Database** | `~/.local/share/opencode-learn/learn.db` |

## Documentation

Full plugin documentation is at `src/plugins/opencode-learn/docs/`:

- **Tutorial:** `docs/tutorials/getting-started.md` — first run in 15 minutes
- **How-to guides:** `docs/how-to/` — install, analyze, promote corrections to rules
- **Reference:** `docs/reference/` — database schema, event type mapping
- **Explanation:** `docs/explanation/` — architecture, design decisions
- **Visual HTML:** `docs/index.html` — SVG architecture diagrams

## Overview

The plugin listens to OpenCode's EventV2 events and writes structured data to a central SQLite database shared across all projects. A separate analysis tool clusters detected corrections, flags recurring patterns, and proposes rule instructions for human review.

### What it captures

| Signal | Event Source | Stored In |
|--------|-------------|-----------|
| What you ask | `session.next.prompt.promoted` | `user_prompt` |
| How the agent responds | `session.next.text.ended` | `assistant_response` |
| Decision summaries | `session.next.compaction.ended` | `session_summary` |
| Tools you use | `session.next.tool.called` | `tool_call`, `file_change` |
| Commands you run | `session.next.shell.started` | `shell_command` |
| Session costs | `session.next.step.ended` | `step` |
| Agents you switch to | `session.next.agent.switched` | `agent_switch` |
| Models you prefer | `session.next.model.switched` | `model_switch` |
| Permissions you allow/deny | `permission.asked/replied` | `permission` |
| Corrections you give | (detected from prompts) | `correction` |
| Unprompted preferences | (detected from prompts) | `preference` |

### Correction-to-rule pipeline

```
Assistant responds → User corrects → Regex classifier → correction table
                                                              ↓
Analysis clusters by pattern → freq≥2 graduates → proposed_rule → human review
```

Corrections graduate to proposed rules only after recurring (freq ≥ 2). Singles stay as data. Human review gates every promotion.

## Related

- [Installation guide →](../../install/install-opencode-learn.md)
- [Plugin source →](../../src/plugins/opencode-learn/)

