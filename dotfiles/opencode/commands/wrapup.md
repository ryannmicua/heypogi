---
description: End-of-session wrap-up — digest learnings, check git, capture next steps, compound solutions, stop dev servers
agent: opencode
---

# End-of-Session Wrap-Up

Run these steps in order. Before starting, check the current working directory and any running processes.

## Step 1: Session Digest

Load the **session-digest** skill and follow it to produce a structured markdown digest of this entire conversation. Extract key decisions, insights, artifacts, patterns, open questions, and next steps. Save the digest to `docs/session-digests/`.

## Step 2: Check Git Status

Run `!`git status`` and `!`git diff --stat``. Share a summary of what's changed and whether anything is uncommitted. Do not stage or commit anything — just report.

## Step 3: Compound Solved Problems

If any non-trivial problems were solved during this session, load the **ce-compound** skill and run it in headless mode (`/ce-compound mode:headless`) to document the solutions to `docs/solutions/`. If the session was purely exploratory or no concrete problems were solved, skip this step.

## Step 4: Check for Running Dev Servers (if applicable)

Only run this step if the project has dev server infrastructure (e.g., a `package.json` with dev scripts, `Cargo.toml` with a watch command, `Gemfile` with a Rails server, or config files for Vite/Next/Webpack). As a rule of thumb: if the project doesn't have a manifest file that declares a dev server, skip this step.

If applicable, check for any lingering dev servers or node processes started during this session. Run `!`Get-Process -Name "node","vite","next","webpack","tsc" -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, StartTime``. If any are found, list them and suggest stopping them with `Stop-Process -Id <id>` — do not kill them automatically.

## Step 5: Report

Present a clean summary:

```
## End-of-Session Summary

Date: <date>
Duration: <approximate session length>

### Changes
- Files modified: <count>
- Uncommitted: <yes/no>

### Session Digest
- Saved to: docs/session-digests/<filename>.md
- Key topics: <list>

### Solutions Documented
- <list of docs/solutions/ files created or updated, or "none">

### Next Steps
- <captured from conversation>

### Running Processes
- <dev servers if any, or "none">

### Notes
- <anything worth flagging for next session>
```
