# Getting Started with opencode-learn

In 15 minutes, you'll have opencode-learn installed and collecting data from your OpenCode sessions — without changing how you work.

## What You'll Build

A running plugin that silently captures your OpenCode sessions into a local database. Once installed, you'll never need to think about it again.

## Prerequisites

- OpenCode installed and working
- Node.js or Bun runtime
- A terminal

## Step 1: Install the Plugin

Add the plugin to your OpenCode configuration:

```bash
# Clone or copy the plugin to a permanent location
cp -r src/plugins/opencode-learn ~/.opencode/plugins/opencode-learn
```

Edit `~/.config/opencode/opencode.json`:

```json
{
  "plugins": ["~/.opencode/plugins/opencode-learn"]
}
```

## Step 2: Verify It's Running

Start a new OpenCode session and ask the agent to do something — anything.

```bash
opencode
```

> The plugin has no UI. No startup message. No buttons. If OpenCode started without errors, the plugin is running.

## Step 3: Confirm Data Is Being Collected

After a few prompts, check the database:

```bash
# Install sqlite3 if you don't have it
sqlite3 ~/.local/share/opencode-learn/learn.db

# Check if data is flowing
.tables
SELECT count(*) FROM tool_call;
SELECT count(*) FROM step;
```

You should see rows appearing. If you see zeros, run a few more prompts and check again.

## Step 4: Run Your First Report

```bash
cd ~/.opencode/plugins/opencode-learn
bun src/analyze.ts
```

This produces a markdown report of all corrections detected so far. If you've only just started, it will be empty — that's normal.

![Expected output: empty report](placeholder-report-output.png)

```
# Correction Analysis Report
Generated: 2026-06-24T12:00:00.000Z

**0** total corrections, **0** unique patterns, **0** graduate candidates
```

## What You've Learned

You now have:
- A working installation that collects session data
- A central database that grows with every OpenCode session
- The ability to run reports on your collected data

## Next Steps

- [How to install the plugin permanently →](../how-to/install.md)
- [How to analyze your collected data →](../how-to/analyze-data.md)
- [How to promote corrections to rules →](../how-to/promote-corrections.md)
- [Understanding the architecture →](../explanation/architecture.md)

