---
name: visible-delegation
description: Delegate work to another agent session while keeping it visible and supervisable — shared terminal sessions, never hidden background runs. Use when delegating work, running tasks in parallel, or handing work to another agent.
---

# Visible Delegation

Delegate work to another agent session while keeping it visible and supervisable. Never run delegates in hidden background processes — use shared terminal sessions so you can watch, interrupt, and course-correct in real time.

## Trigger Conditions

- User asks to delegate work
- User asks to run something in parallel
- User asks to hand work to another agent
- A task is identified as suitable for parallel execution

## Prerequisites

Check whether tmux (or equivalent session manager) is installed. On Linux/macOS:
```
which tmux || (apt-get install tmux / brew install tmux)
```
On Windows: use PowerShell jobs, Windows Terminal split panes, or WSL with tmux.

Confirm which agent CLI(s) are available for delegate sessions (opencode, claude, codex, etc.).

## Launch Procedure

1. **Build the goal prompt** — use `goal-prompt-generator` skill if available; otherwise manually construct a bounded objective with definition of done, constraints, verification gates, and stop conditions
2. **Create a named tmux session** (or equivalent):
   ```
   tmux new-session -d -s <lane-name> "<agent-cli> --prompt '<goal-prompt>'"
   ```
3. **Tell the user how to attach and watch**:
   ```
   tmux attach -t <lane-name>
   ```

## Monitoring Rules

Check the session at sensible intervals (every few minutes for fast tasks, less often for long-running work). Intervene when:

| Signal | Action |
|--------|--------|
| Stuck loop repeating the same action | Pause, diagnose, redirect |
| Scope drift beyond constraints | Remind of boundaries, halt if continuing |
| Destructive commands (rm -rf, force push, db drops) | Interrupt immediately |
| Silent for too long | Check if blocked or crashed |

Patience is warranted for: reading large files, running test suites, waiting for builds — these take real wall-clock time.

## Results Protocol

When the delegate claims completion:
1. Run the verification gates from the original goal prompt yourself
2. Check that every item in the definition of done is satisfied
3. Only report success to the user after independent verification

## Cleanup

- Close tmux sessions: `tmux kill-session -t <lane-name>`
- Never abandon sessions — list active ones with `tmux ls` and clean up
- If using worktrees, use worktree-safe removal
