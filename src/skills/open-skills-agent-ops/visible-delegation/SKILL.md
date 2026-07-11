---
name: visible-delegation
description: Delegate work to another agent session while keeping it visible and supervisable — shared terminal sessions, never hidden background runs. Use when delegating work, running tasks in parallel, or handing work to another agent.
---

# Visible Delegation

Delegate work to another agent session in a way you can watch, interrupt, and course-correct in real time. Never run delegates in hidden background processes — use shared terminal sessions so every action is visible and supervisable.

## Trigger Conditions

Load this skill when:

- User says "delegate", "hand this off", or "run this in parallel"
- User asks to split work across multiple agent sessions
- A task is identified as suitable for parallel execution (independent, no shared state)
- User wants to watch an agent work rather than receive a finished result
- The `dispatching-parallel-agents` superpower identifies independent workstreams

Do NOT load this skill for:
- Simple single-command execution (use Bash directly)
- Tasks the current agent can complete in under 30 seconds
- Non-agent automation (cron jobs, scheduled scripts — these are not visible delegation)

## Prerequisites

### WezTerm (Session Manager)

This skill uses **WezTerm** as the visible session manager. Delegate work runs in WezTerm panes side-by-side with your session — visible by design, no attachment step needed.

```bash
# Verify wezterm is on PATH
wezterm --version
```

If WezTerm is not installed:

**Windows:**
```powershell
winget install wezterm.wezterm
```
Or download from https://wezterm.org/install/windows.html

**macOS:**
```bash
brew install --cask wezterm
```

**Linux:**
```bash
# Follow instructions at https://wezterm.org/install/linux.html
```

### WezTerm Context Requirement

The `wezterm cli` commands ONLY work when invoked from inside a running WezTerm terminal. If the current session is not running inside WezTerm (e.g., Windows Terminal, VS Code terminal, standalone OpenCode TUI), skip Path A and use Path B (launch a new WezTerm window) or Path C (OpenCode task tool).

Detect the current terminal:

```bash
# Check if $TERM_PROGRAM indicates wezterm
if [ "$TERM_PROGRAM" = "WezTerm" ]; then
  echo "Running inside WezTerm — cli commands available"
else
  echo "Not inside WezTerm — use Path B or C"
fi
```

On Windows (PowerShell):
```powershell
if ($env:TERM_PROGRAM -eq "WezTerm") { "Inside WezTerm" } else { "Outside WezTerm" }
```

### Agent CLI

Confirm the agent CLI is on PATH:

```bash
opencode --version
```

The delegate session runs the same agent harness. `opencode run` is the non-interactive mode used for delegation.

## Launch Procedure

### Path A: WezTerm CLI (Inside WezTerm — Primary)

When the current session is inside WezTerm, splits are the most visible delegate mechanism. The delegate runs in a split pane directly next to your working session.

**Step 1 — Build the goal prompt**

Compose a self-contained goal prompt. If `goal-prompt-generator` is available, invoke it to produce the structured 5-section format (Objective, Definition of Done, Repo Constraints, Verification Gates, Stop Conditions). If the skill is not available, manually construct a prompt with the same 5 sections.

Save the prompt to a temp file the delegate can read:

```powershell
$goalPath = ".opencode\tmp\goal-<lane-name>.md"
# Write the goal prompt to this file
```

**Step 2 — Create a visible split pane**

```bash
# Split the current pane vertically (bottom) and run the delegate
wezterm cli split-pane --bottom --cwd "$(pwd)" -- opencode run --dir "$(pwd)" -f ".opencode/tmp/goal-<lane-name>.md"

# Or horizontally (right) for wider output:
wezterm cli split-pane --right --cwd "$(pwd)" -- opencode run --dir "$(pwd)" -f ".opencode/tmp/goal-<lane-name>.md"
```

On Windows (PowerShell):
```powershell
wezterm cli split-pane --bottom --cwd "$pwd" -- opencode run --dir "$pwd" -f ".opencode/tmp/goal-<lane-name>.md"
```

To spawn in a new tab instead of a split:
```bash
wezterm cli spawn --cwd "$(pwd)" -- opencode run --dir "$(pwd)" -f ".opencode/tmp/goal-<lane-name>.md"
```

**Step 3 — Set the tab/pane title for identification**

```bash
wezterm cli set-tab-title "<lane-name>"
```

**Step 4 — Tell the user what happened**

After launching, the delegate is already visible — no attach step needed:

```
Delegate started: <lane-name>
Location: Split pane below / new tab "<lane-name>" in this WezTerm window
To interrupt:  Ctrl+C in the delegate pane (or focus it and press Ctrl+C)
To kill:       wezterm cli kill-pane --pane-id <pane-id>
```

### Path B: Launch a New WezTerm Window (Outside WezTerm)

When the current session is NOT inside WezTerm, launch a dedicated WezTerm window for the delegate:

```bash
wezterm start --class delegate --cwd /path/to/repo -- opencode run --dir /path/to/repo -f ".opencode/tmp/goal-<lane-name>.md"
```

On Windows:
```powershell
wezterm start --class delegate --cwd "C:\Users\rmicua\myrepo\heypogi" -- opencode run --dir "C:\Users\rmicua\myrepo\heypogi" -f ".opencode/tmp/goal-<lane-name>.md"
```

The `--class delegate` groups all delegate windows under one class, making them easy to find in the taskbar.

### Path C: OpenCode Built-in Task Tool (In-Harness)

When neither WezTerm CLI is available (not inside WezTerm, `wezterm` not installed), fall back to OpenCode's native `task` tool. Less visible but preserves the supervision protocols below.

### Lane Naming Convention

Use descriptive, unique lane names that identify the work:

```
<verb>-<noun>-<disambiguator>
```

Examples: `fix-auth-bug`, `add-export-endpoint`, `review-pr-142`, `migrate-user-table`

If a lane name is taken, append `-2`, `-3`, etc.

## Monitoring Rules

### Check Cadence

| Task duration | Check interval |
|--------------|----------------|
| < 5 minutes expected | Every 60 seconds |
| 5–30 minutes expected | Every 3 minutes |
| > 30 minutes expected | Every 5 minutes |

### Observing Delegate Output

**Inside WezTerm (Path A):** The delegate pane is visible — just look at it. No command needed.

**To programmatically capture output** from a specific pane:

```bash
# List panes to find the delegate's pane ID
wezterm cli list --format json

# Capture the text content of a pane
wezterm cli get-text --pane-id <pane-id>
```

**Outside WezTerm (Path B):** The delegate runs in its own window — the user watches it directly.

### Intervention Triggers

| Signal | Detection | Action |
|--------|-----------|--------|
| **Stuck loop** | Same action repeated 3+ times in visible output | Focus delegate pane, Ctrl+C, redirect via `send-text` |
| **Scope drift** | Agent modifies files outside `May modify` list, or works on unrelated features | Send a reminder of boundaries via `wezterm cli send-text --pane-id <id> "reminder message"`; if continuing, kill the pane |
| **Destructive commands** | `rm -rf`, `git push --force`, `DROP TABLE`, `format` / `clean` on entire disks, secrets in output | Interrupt **immediately** — `wezterm cli send-text --pane-id <id> $'\x03'` (sends Ctrl+C) |
| **Silent > 2x check interval** | No new output since last check | Check `wezterm cli get-text --pane-id <id>` for the last lines; if hung, send a wake prompt |
| **Test failure loop** | Agent repeatedly runs same failing test without changing approach | Interrupt, suggest a different diagnosis strategy, or escalate to user |
| **Permission denial** | Agent retries a command that the system rejects | Intervene — the agent may not know it lacks rights |
| **Token/context exhaustion** | Output shows truncation or context overflow warnings | Kill pane, chunk the goal prompt into smaller pieces, re-launch |

To send keystrokes to a delegate pane:
```bash
# Send Ctrl+C (interrupt)
wezterm cli send-text --pane-id <id> $'\x03'

# Send a text message (redirecting the agent)
wezterm cli send-text --pane-id <id> "Stop what you're doing. Check scope: you modified a file outside the approved list."
```

### Patience Thresholds

These are NOT intervention signals — let them run:

| Activity | Typical max wait |
|----------|-----------------|
| `npm install` / `pip install` | 5 minutes |
| Running a full test suite | 10 minutes |
| `git clone` of a large repo | 5 minutes |
| Reading a large file (>2000 lines) | 2 minutes |
| Build/compilation (webpack, tsc, cargo) | 5 minutes |
| LLM API latency (rate limits, queuing) | 2 minutes per turn |

## Results Protocol

When the delegate claims completion (exit code 0, or explicit "done" message), do NOT immediately report success to the user. Run the verification gates yourself first:

### Verification Sequence

1. **Read the goal prompt** — confirm which verification gates were specified
2. **Run each gate command** — execute them in the current session (not the delegate's), with the same working directory
3. **Check Definition of Done** — every pass/fail item must pass independently
4. **Diff check** — review `git diff` to confirm only intended files changed and no unintended side effects
5. **Lint/typecheck** — if the project has `npm run lint` or equivalent, run it

### Reporting to the User

After verification, produce a concise report:

```
Delegate: <lane-name>
Status:   PASS (all gates) / PARTIAL (see gaps) / FAIL (see issues)

Definition of Done:
  ✓ <item 1>
  ✓ <item 2>
  ✗ <item 3> — <what's missing>

Changes:
  <file1> — <what changed>
  <file2> — <what changed>

Verdict: <one sentence>
```

When verification fails, report the gaps and ask the user whether to:
- Give the delegate corrective instructions and re-run
- Abandon the delegate's work and fix manually
- Accept the partial output as-is

### Success Reporting Gate

Only report "task complete" to the user when:
- All verification gates pass
- All Definition of Done items are satisfied
- `git diff` shows only intended changes
- Lint/typecheck passes (if applicable)
- The delegate pane/session has been cleaned up

## Cleanup

Every delegate pane must be explicitly closed. Never leave abandoned panes running.

```bash
# Kill a delegate pane by ID
wezterm cli kill-pane --pane-id <pane-id>

# List remaining panes to verify cleanup
wezterm cli list
```

**Path B (separate window):** Close the window — the user can close it directly since it's visible.

### WezTerm CLI Reference

| CLI Command | Purpose |
|-------------|---------|
| `wezterm cli split-pane --bottom -- <cmd>` | Create a vertical split running a command |
| `wezterm cli split-pane --right -- <cmd>` | Create a horizontal split |
| `wezterm cli spawn -- <cmd>` | Open a new tab running a command |
| `wezterm cli send-text --pane-id <id> <text>` | Send input to a pane |
| `wezterm cli get-text --pane-id <id>` | Read pane text content |
| `wezterm cli list --format json` | List all windows, tabs, panes as JSON |
| `wezterm cli kill-pane --pane-id <id>` | Close a pane |
| `wezterm cli set-tab-title <title>` | Set the current tab title |
| `wezterm cli activate-pane --pane-id <id>` | Focus a specific pane |
| `wezterm start -- <cmd>` | Launch a new WezTerm window |

Cleanup checklist before reporting completion:
- [ ] Delegate pane killed (`wezterm cli kill-pane` or window closed)
- [ ] No orphaned panes (verify via `wezterm cli list`)
- [ ] Temp goal prompt file removed (`.opencode/tmp/goal-<lane-name>.md`)
- [ ] If the delegate used a git worktree, it has been removed
- [ ] Any delegate-created temp files under system temp directories have been cleaned

If a delegate pane is abandoned (e.g., the wezterm mux persisted it), locate and kill it on next invocation:

```bash
# List all panes across all windows and tabs
wezterm cli list --format json | python -m json.tool

# Identify orphaned panes by their title/content and kill them
wezterm cli kill-pane --pane-id <orphaned-pane-id>
```

## Integration with Other Skills

### goal-prompt-generator

Compose with `goal-prompt-generator` to produce structured delegation prompts. The generator's 5-section format (Objective, Definition of Done, Repo Constraints, Verification Gates, Stop Conditions) feeds directly into the delegate launch. Every goal prompt saved for delegation must follow this format.

### dispatching-parallel-agents

When the `dispatching-parallel-agents` superpower identifies mutually independent tasks, launch one visible delegate pane per task. All panes share the same WezTerm window — the user sees every one.

### session-operating-map

If a `session-operating-map` exists for the repo, record each delegate session in the map with lane name, goal, and status. Update status when the session completes or is killed.

## Verification

Test the full delegation loop:

1. Verify wezterm is on PATH: `wezterm --version`
2. Build a goal prompt for a small, self-contained task (e.g., "add a comment to function X in file Y")
3. Launch a delegate — split pane (Path A) or new window (Path B)
4. Watch the delegate work in the visible pane/window
5. After the delegate claims completion, run the verification gates
6. Report results to the user
7. Clean up the pane/session and temp files
