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

### tmux / psmux (Session Manager)

This skill uses **tmux** (or **psmux** on Windows) as the visible session manager. Delegate work runs in tmux panes side-by-side with your session — visible by design, no attachment step needed.

```bash
# Verify tmux is on PATH
tmux --version
```

If not installed:

**Windows (psmux — native tmux alternative, no WSL):**
```powershell
winget install psmux
```
The installer adds `tmux`, `pmux`, and `psmux` command aliases. Documentation: https://psmux.pages.dev/

**macOS:**
```bash
brew install tmux
```

**Linux:**
```bash
# Debian/Ubuntu
sudo apt install tmux

# Fedora
sudo dnf install tmux

# Arch
sudo pacman -S tmux
```

### tmux Context Requirement

The `tmux` commands work both inside and outside a tmux session, but split operations (`split-window`, `new-window`) only apply when currently inside tmux. If the current session is not running inside tmux, skip Path A and use Path B (launch a new terminal with tmux) or Path C (OpenCode task tool).

Detect the current terminal:

```bash
# Check if $TMUX is set (set automatically inside any tmux session)
if [ -n "$TMUX" ]; then
  echo "Running inside tmux — split commands available"
else
  echo "Not inside tmux — use Path B or C"
fi
```

On Windows (PowerShell):
```powershell
if ($env:TMUX) { "Inside tmux" } else { "Outside tmux" }
```

### Agent CLI

Confirm the agent CLI is on PATH:

```bash
opencode --version
```

The delegate session runs the same agent harness. `opencode run` is the non-interactive mode used for delegation.

## Launch Procedure

### Path A: Inside tmux — Primary

When the current session is inside tmux, splits are the most visible delegate mechanism. The delegate runs in a split pane directly next to your working session.

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
tmux split-window -v -c "$(pwd)" "opencode run --dir '$(pwd)' -f '.opencode/tmp/goal-<lane-name>.md'"

# Or horizontally (right) for wider output:
tmux split-window -h -c "$(pwd)" "opencode run --dir '$(pwd)' -f '.opencode/tmp/goal-<lane-name>.md'"
```

On Windows (PowerShell):
```powershell
tmux split-window -v -c "$pwd" "opencode run --dir '$pwd' -f '.opencode/tmp/goal-<lane-name>.md'"
```

To spawn in a new window instead of a split:
```bash
tmux new-window -n "<lane-name>" -c "$(pwd)" "opencode run --dir '$(pwd)' -f '.opencode/tmp/goal-<lane-name>.md'"
```

**Step 3 — Rename the window for identification**

```bash
tmux rename-window -t "{current-session}:{current-window}.{pane-id}" "<lane-name>"
```

Or simply rename the new window if created with `new-window` — it's already named.

**Step 4 — Tell the user what happened**

After launching, the delegate is already visible — no attach step needed:

```
Delegate started: <lane-name>
Location: Split pane below / window "<lane-name>" in this tmux session
To interrupt:  Ctrl+C in the delegate pane (or focus it and press Ctrl+C)
To kill:       tmux kill-pane -t <pane-target>
```

### Path B: New Terminal with tmux (Outside tmux)

When the current session is NOT inside tmux, launch a new terminal window running tmux with the delegate:

**Windows (Windows Terminal):**
```powershell
# Launch a new Windows Terminal tab running a tmux session
$lane = "<lane-name>"
wt -w 0 nt --title "delegate-$lane" powershell -NoExit "tmux new-session -A -s $lane -c '$pwd'"
Start-Sleep -Seconds 1
# Send the delegate command to the tmux session
tmux send-keys -t $lane "opencode run --dir '$pwd' -f '.opencode/tmp/goal-$lane.md'" Enter
Write-Host "Delegate started in new terminal tab (delegate-$lane)"
Write-Host "Attach via: tmux attach -t $lane"
```

**macOS/Linux (Terminal):**
```bash
# Open a new terminal window running tmux (macOS)
osascript -e 'tell app "Terminal" to do script "tmux new-session -A -s <lane-name> -c \"$(pwd)\""'
sleep 1
tmux send-keys -t <lane-name> "opencode run --dir '$(pwd)' -f '.opencode/tmp/goal-<lane-name>.md'" Enter
```

```bash
# Linux (x-terminal-emulator)
x-terminal-emulator -e "tmux new-session -A -s <lane-name> -c '$(pwd)'" &
sleep 1
tmux send-keys -t <lane-name> "opencode run --dir '$(pwd)' -f '.opencode/tmp/goal-<lane-name>.md'" Enter
```

### Path C: OpenCode Built-in Task Tool (In-Harness)

When neither tmux CLI is available (not inside tmux, `tmux` not installed), fall back to OpenCode's native `task` tool. Less visible but preserves the supervision protocols below.

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

**Inside tmux (Path A):** The delegate pane is visible — just look at it. No command needed.

**To programmatically capture output** from a specific pane:

```bash
# List panes/sessions to find the delegate's session name
tmux list-sessions

# Capture the text content of a pane (last 100 lines)
tmux capture-pane -t <lane-name> -p -S -100
```

**Outside tmux (Path B):** The delegate runs in its own terminal window — the user watches it directly.

### Intervention Triggers

| Signal | Detection | Action |
|--------|-----------|--------|
| **Stuck loop** | Same action repeated 3+ times in visible output | Focus delegate pane, Ctrl+C, redirect via `send-keys` |
| **Scope drift** | Agent modifies files outside `May modify` list, or works on unrelated features | Send a reminder of boundaries via `tmux send-keys -t <lane-name> "reminder message" Enter`; if continuing, kill the pane |
| **Destructive commands** | `rm -rf`, `git push --force`, `DROP TABLE`, `format` / `clean` on entire disks, secrets in output | Interrupt **immediately** — `tmux send-keys -t <lane-name> C-c` |
| **Silent > 2x check interval** | No new output since last check | Check `tmux capture-pane -t <lane-name> -p -S -100` for the last lines; if hung, send a wake prompt |
| **Test failure loop** | Agent repeatedly runs same failing test without changing approach | Interrupt, suggest a different diagnosis strategy, or escalate to user |
| **Permission denial** | Agent retries a command that the system rejects | Intervene — the agent may not know it lacks rights |
| **Token/context exhaustion** | Output shows truncation or context overflow warnings | Kill pane, chunk the goal prompt into smaller pieces, re-launch |

To send keystrokes to a delegate pane:
```bash
# Send Ctrl+C (interrupt)
tmux send-keys -t <lane-name> C-c

# Send a text message (redirecting the agent)
tmux send-keys -t <lane-name> "Stop what you're doing. Check scope: you modified a file outside the approved list." Enter
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
# Kill a delegate pane by target (session name)
tmux kill-pane -t <lane-name>

# List remaining sessions to verify cleanup
tmux list-sessions
```

**Path B (separate terminal):** Close the terminal window — the user can close it directly since it's visible. Also kill the tmux session:
```bash
tmux kill-session -t <lane-name>
```

### tmux CLI Reference

| CLI Command | Purpose |
|-------------|---------|
| `tmux split-window -v -c <cwd> <cmd>` | Create a vertical split (bottom) running a command |
| `tmux split-window -h -c <cwd> <cmd>` | Create a horizontal split (right) |
| `tmux new-window -n <name> -c <cwd> <cmd>` | Open a new window running a command |
| `tmux send-keys -t <target> <text> Enter` | Send input to a pane (omit `Enter` for control chars) |
| `tmux send-keys -t <target> C-c` | Send Ctrl+C to interrupt |
| `tmux capture-pane -t <target> -p -S -100` | Read pane text content (last 100 lines) |
| `tmux list-sessions` | List all active tmux sessions |
| `tmux list-panes -a` | List all panes across all sessions |
| `tmux kill-pane -t <target>` | Close a pane |
| `tmux kill-session -t <target>` | Kill an entire session |
| `tmux rename-window -t <target> <title>` | Rename the current window |
| `tmux select-pane -t <target>` | Focus a specific pane |
| `tmux new-session -d -s <name> -c <cwd> <cmd>` | Create a detached session |

**Target syntax:** tmux targets follow the pattern `session:window.pane` — e.g., `fix-auth-bug:0.1`. When using `-t <lane-name>`, tmux resolves to the session with that name.

Cleanup checklist before reporting completion:
- [ ] Delegate pane killed (`tmux kill-pane` or `tmux kill-session` or window closed)
- [ ] No orphaned sessions (verify via `tmux list-sessions`)
- [ ] Temp goal prompt file removed (`.opencode/tmp/goal-<lane-name>.md`)
- [ ] If the delegate used a git worktree, it has been removed
- [ ] Any delegate-created temp files under system temp directories have been cleaned

If a delegate session is abandoned, locate and kill it on next invocation:

```bash
# List all sessions
tmux list-sessions

# Identify orphaned sessions by name and kill them
tmux kill-session -t <orphaned-session-name>
```

## Integration with Other Skills

### goal-prompt-generator

Compose with `goal-prompt-generator` to produce structured delegation prompts. The generator's 5-section format (Objective, Definition of Done, Repo Constraints, Verification Gates, Stop Conditions) feeds directly into the delegate launch. Every goal prompt saved for delegation must follow this format.

### dispatching-parallel-agents

When the `dispatching-parallel-agents` superpower identifies mutually independent tasks, launch one visible delegate pane per task. All panes share the same tmux session — the user sees every one.

### session-operating-map

If a `session-operating-map` exists for the repo, record each delegate session in the map with lane name, goal, and status. Update status when the session completes or is killed.

## Verification

Test the full delegation loop:

1. Verify tmux is on PATH: `tmux --version`
2. Build a goal prompt for a small, self-contained task (e.g., "add a comment to function X in file Y")
3. Launch a delegate — split pane (Path A) or new terminal (Path B)
4. Watch the delegate work in the visible pane/window
5. After the delegate claims completion, run the verification gates
6. Report results to the user
7. Clean up the pane/session and temp files
