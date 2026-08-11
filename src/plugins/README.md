# Plugins

OpenCode plugins developed in this repo.

## opencode-learn

**`opencode-learn/`** — Passive observation system that captures session data, detects user corrections, and enables cross-project pattern analysis.

Collects OpenCode EventV2 events (prompts, tool calls, steps, shell commands, agent/model switches, permissions, compactions) into a central SQLite database at `~/.local/share/opencode-learn/learn.db`. A separate analysis tool clusters detected corrections and proposes rule instructions for human review.

### Quick start

```powershell
# Install the plugin globally
./src/plugins/opencode-learn/tooling/install.ps1

# After a few sessions, run analysis
cd src/plugins/opencode-learn && bun src/analyze.ts
```

### Docs

Full documentation at `src/plugins/opencode-learn/docs/` — tutorials, how-to guides, reference, explanation, and visual HTML with SVG architecture diagrams.

