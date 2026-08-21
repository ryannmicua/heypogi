---
name: lfg-ship
description: "Ship an idea or issue all the way to a verified merge-ready PR — plan, implement, review, commit, open PR, then drive it through Copilot review with a cross-family judge until merge-ready. Use when the user wants to 'ship this', 'build and get it ready to merge', 'full send on this issue', or wants end-to-end autonomous delivery from concept to a PR that's been verified as merge-ready. Combines the lfg pipeline (plan → implement → commit → PR) with the pr-merge-ready-loop (Copilot review → judge assessment → fix cycle → ready verdict). The skill never merges — it returns a ready-to-merge verdict and the operator merges."
argument-hint: "[feature description, issue number, or idea — e.g. 'issue 11', 'add dark mode', 'fix the login timeout']"
---

CRITICAL: You MUST execute every phase below IN ORDER. Do NOT skip any required phase. Do NOT jump ahead to coding or implementation. Phase 1 (plan) MUST be completed and verified BEFORE implementation begins. Phase 2 (merge-ready loop) MUST NOT start until Phase 1 has produced an open PR with CI passing. Violating this order produces bad output.

## Architecture

This skill chains two independent pipelines into one autonomous flow:

```
Phase 1: LFG Pipeline (idea → PR)
  ce-plan → ce-work → ce-simplify-code → ce-code-review → apply fixes →
  residual handoff → ce-test-browser → ce-commit-push-pr → ce-babysit-pr (CI watch)

Phase 2: Merge-Ready Loop (PR → verified merge-ready)
  Request Copilot review → Judge assessment → Fix cycle → Ready verdict
```

**Key separation of concerns:**
- Phase 1's ce-babysit-pr watches CI and resolves convergent failures — it does NOT run the merge-ready loop
- Phase 2's merge-ready loop drives Copilot review through judge/babysitter — it does NOT re-implement features
- The two phases share a PR but have distinct goals: Phase 1 = "PR exists with green CI"; Phase 2 = "PR is verified merge-ready"

## Input

The skill accepts one of:
- A **GitHub issue number** (e.g., "issue 11") — reads the issue body as the feature request
- A **feature description** (e.g., "add dark mode to the dashboard")
- An **idea** (e.g., "users should be able to export reports as PDF")

When an issue number is provided, read it via `gh issue view <N> --json title,body,labels` and use the body as the feature request.

## Step 0: Isolation Decision

Before any work begins, ask the operator **one question**:

> Run this on a worktree (isolated from main) or on the current branch?

**Options:**
- **Worktree (recommended)** — creates an isolated git worktree on a new branch. Main checkout stays clean. Safest for parallel work or when the operator might interrupt.
- **Current branch** — runs directly on the checked-out branch. Faster, but the pipeline will modify files and push from this checkout.

Default to **worktree** when the operator does not express a preference (e.g., when invoked headlessly from a scheduler or loop).

### If worktree: create isolation

Detect the runtime first, then use the appropriate worktree mechanism:

**Runtime detection (check in order):**

1. **Paseo** — `PASEO_AGENT_ID` env var is set, or `paseo_create_workspace` tool is available
2. **Plain OpenCode** — `OPENCODE=1` env var is set, no Paseo signals
3. **OpenChamber** — `OPENCHAMBER_*` env var is set

Detect via environment variables:

```powershell
# PowerShell — check which runtime is active
$paseo = $env:PASEO_AGENT_ID
$opencode = $env:OPENCODE
$openchamber = $env:OPENCHAMBER_SKIP_LOCAL_SERVER
```

Or check tool availability: if you can call `paseo_create_workspace`, you are in Paseo.

**If Paseo:**

```bash
paseo create_workspace \
  --isolation worktree \
  --mode branch-off \
  --new-branch "feat/<short-description>" \
  --base main
```

- Record the **workspace ID** and **branch name** from the response
- All agent dispatches use `--workspace <id>` to target the worktree

**If Plain OpenCode or OpenChamber (no Paseo tools):**

```bash
# Create worktree directly via git
git worktree add ".worktrees/<short-description>" -b "feat/<short-description>" main
```

- Worktree path: `<repo>/.worktrees/<short-description>`
- Record the **worktree path** and **branch name**
- All agent dispatches set `cwd` to the worktree path
- No workspace ID (Paseo concept) — use the filesystem path instead

### If current branch: confirm

- Confirm the branch name and that uncommitted changes (if any) are understood
- Record the branch name for the PR
- Proceed without creating a worktree

### Isolation record

Write the isolation decision to `<repo>/tmp/lfg-ship-context.json`:

```json
{
  "runtime": "paseo|opencode|openchamber",
  "isolation": "worktree|current-branch",
  "workspace_id": "<id or null (Paseo only)>",
  "branch": "<branch-name>",
  "worktree_path": "<path or null>",
  "base_branch": "main"
}
```

This file is read by Phase 2 and the terminal output for cleanup and reporting. The `runtime` field determines which cleanup commands are valid.

## Phase 1: LFG Pipeline

Execute the full `lfg` skill from step 1 through step 9. Refer to the `lfg` skill for complete step definitions, gating rules, and artifact root resolution.

**Working directory:** If a worktree was created in Step 0, all agent dispatches in Phase 1 use the worktree path as their working directory. If running on the current branch, use the repo root as normal.

### Phase 1 summary (user-facing progress)

| Stage | What happens | Gate |
|---|---|---|
| **Plan** | ce-plan produces implementation-ready plan | Plan file exists in `<root>/plans/` |
| **Implement** | ce-work executes the plan | All U-IDs complete, tests pass |
| **Simplify** | ce-simplify-code tidies the diff | Behavior preserved, tests pass |
| **Review** | ce-code-review finds issues (report-only) | Findings classified |
| **Fix** | Review fixes applied and committed | Clean working tree |
| **Residuals** | Non-fixable findings filed as tracker tickets | Durable record committed |
| **Browser test** | ce-test-browser verifies UI changes | No regressions |
| **Ship** | ce-commit-push-pr opens the PR | PR URL known |
| **CI watch** | ce-babysit-pr watches CI to green | CI 3/3 green on current head |

### Phase 1 exit gate

Phase 1 completes when:
1. A PR exists on GitHub for the current branch
2. CI is green on the current head SHA
3. The PR is open and mergeable

Record the **PR number**, **head SHA**, and **PR URL** — these are Phase 2 inputs.

If Phase 1 fails (CI red after babysit budget exhausted, or PR cannot be created), stop and report to the operator. Do NOT proceed to Phase 2.

## Phase 2: Merge-Ready Loop

Drive the PR from "opened" to a **verified merge-ready verdict** through a three-role loop: a **merge readiness agent** (judge) that decides, a **babysitter** that watches and executes, and **Copilot** as the primary reviewer.

### Roles

| Role | Agent | Authority | Never |
|---|---|---|---|
| **Orchestrator** (you) | Session agent | Spawns judge/babysitter, relays verdicts, requests Copilot reviews | Implements fixes directly |
| **Judge** | minimax-m3 (cross-family from fixer) | Read-only decisions: verdict, fix-list, review-round request | Mutates the PR |
| **Babysitter** | mimo-v2.5 (impl role) | All mutations: fix commits, push, resolve threads, CI reruns | Deciding merge-readiness |
| **Copilot** | copilot-pull-request-reviewer[bot] | Primary reviewer; review is the raw material the judge assesses | — |

### Readiness conditions (ALL must hold)

1. **At least one Copilot review on the current head SHA** — a review of an older head does not satisfy this
2. **Judge's assessment concludes ready** — every finding is fixed-and-verified, declined with reason, or parked as non-blocking
3. **CI is green on the current head** — all checks passing; empty rollup is NOT green

### Verdict log

Maintain a verdict log at `<repo>/tmp/merge-ready-verdicts.json` (gitignored scratch):

```json
{
  "pr": "https://github.com/OWNER/REPO/pull/N",
  "rounds": [
    {
      "round": 1,
      "head_sha": "...",
      "review_sha": "...",
      "findings": [
        {"id": "C1", "location": "file:line", "severity": "P1|P2|P3",
         "action": "fix|decline|park", "reason": "..."}
      ],
      "fixes_ordered": ["C1"],
      "fixes_verified": [],
      "copilot_round_requested": true,
      "verdict": "not-ready"
    }
  ],
  "state": "in-progress|ready|needs-human",
  "final_verdict": null
}
```

### Step P2.1 — Request initial Copilot review

```bash
gh pr edit <N> --add-reviewer "@copilot"
```

Verify via GraphQL that `copilot-pull-request-reviewer` is in `reviewRequests`:

```powershell
$q = 'query { repository(owner:"OWNER", name:"REPO") { pullRequest(number:N) { reviewRequests(first:10) { nodes { requestedReviewer { __typename ... on Bot { login } ... on User { login } } } } } } }'
gh api graphql -f query=$q
```

If the request does not land (bot not in reviewRequests), retry once. If it still fails, report to operator and stop Phase 2.

### Step P2.2 — Spawn the babysitter

Create a background agent (mimo-v2.5, build mode, auto-accept) with this brief:

```
You are the babysitter in a PR Merge-Ready Loop for PR <N> on <OWNER/REPO>.

Your role: Execute all mutations (fix commits, push, resolve threads, CI reruns, Copilot review requests). You NEVER decide merge-readiness — that is the judge's job.

PR: <pr-url>
Head SHA: <current-head-sha>
Verdict log: <repo>/tmp/merge-ready-verdicts.json

Workflow:
1. Load ce-babysit-pr skill and execute its pipeline on PR <N>.
2. When a Copilot review arrives, read the findings. Write a snapshot to <repo>/tmp/review-snapshot.json:
   {"round": N, "head_sha": "...", "review_sha": "...", "findings": [{"id": "C1", "file": "...", "line": N, "severity": "P1|P2|P3", "comment": "..."}]}
3. After writing the snapshot, output: [NEEDS_JUDGE_ASSESSMENT round=N]
4. When you receive a judge verdict:
   - ready → output [READY_TO_MERGE] with evidence summary
   - not-ready with fixes → implement exactly the ordered fixes, verify (pytest, ruff check), commit, push, resolve threads, then request another Copilot round: gh pr edit <N> --add-reviewer "@copilot"
   - needs-human → output [NEEDS_HUMAN] with residuals
5. Cap Copilot review rounds at 3. If no convergence, output [NON_CONVERGENCE].

Hard rules:
- You NEVER judge your own fixes. The judge decides.
- You fix EXACTLY what the judge orders.
- The loop never merges. Terminal states: ready-to-merge, needs-human, non-convergence.
```

### Step P2.3 — Monitor and relay

After spawning the babysitter, monitor for its output signals. When a signal arrives:

**`[NEEDS_JUDGE_ASSESSMENT round=N]`** — Spawn the judge:

1. Read the verdict log and review snapshot
2. Create a one-shot agent (minimax-m3, plan mode, high thinking) with the judge brief (see Appendix A)
3. Wait for the judge's verdict
4. Feed the verdict back to the babysitter via `paseo_send_agent_prompt`

**`[READY_TO_MERGE]`** — Phase 2 complete. Record the verdict and evidence.

**`[NEEDS_HUMAN]`** — Stop. Report residuals to the operator.

**`[NON_CONVERGENCE]`** — Stop. Report the trajectory (rounds, findings, fixes) to the operator.

### Step P2.4 — Final verdict

When the judge returns `ready`:

1. Verify all three readiness conditions hold (Copilot review on current head, judge ready, CI green)
2. Update the verdict log: `state: "ready"`, `final_verdict: "ready-to-merge"`
3. Output the terminal verdict

## Terminal Output

```
DONE — PR #<N> is merge-ready.

PR: <pr-url>
Head: <sha>
CI: <checks> green
Copilot review: on current head ✓
Judge verdict: ready (round <M>)
Fixes applied: <list or "none">
Isolation: worktree <branch> at <path> | current branch <branch>

Merge when ready: gh pr merge <N> --squash
```

If a worktree was used:
- The worktree remains checked out (it may be needed for review or further work)
- Cleanup depends on the runtime:
  - **Paseo:** `paseo archive_workspace <workspace-id>` or `git worktree remove <path>`
  - **Plain OpenCode / OpenChamber:** `git worktree remove <path>`
- The operator can also manually remove `.worktrees/<name>` and delete the branch after merge

The skill never merges. The operator makes the merge call.

## Failure Modes

| Failure | Action |
|---|---|
| Worktree creation fails | Report to operator with the runtime detected. Offer to run on current branch instead, or stop. |
| ce-plan returns non-software | Stop Phase 1. Report to operator. |
| CI red after babysit budget exhausted | Stop Phase 1. Report residuals. |
| PR cannot be created | Stop. Report to operator. |
| Copilot review request fails twice | Stop Phase 2. Report to operator. |
| Judge requests >3 Copilot rounds | Stop as non-convergence. Report trajectory. |
| Judge/fixer disagreement on contract | Stop. Report competing options to operator. |
| Fix would change frozen contract | Stop. Escalate to operator (never fix silently). |

## Appendix A: Judge Brief Template

When spawning the judge, use this template:

```
You are the merge readiness judge for PR <N> on <OWNER/REPO>.
You are READ-ONLY. You NEVER mutate the PR.

Current state:
- PR: <pr-url>
- Head SHA: <sha>
- CI: <status>
- Copilot review status: <pending|landed>
- Verdict log: <path>

Read the verdict log. Assess all findings from the latest Copilot review.
Check readiness conditions 1-3.

Output format:
VERDICT: ready | not-ready | needs-human
FIXES: [finding IDs to fix, empty if ready]
REQUEST_COPILOT_ROUND: true | false
REASON: [one-line explanation]
```

## Appendix B: Provider Routing

Per orchestration-preferences.json:

| Role | Provider | Model | Thinking |
|---|---|---|---|
| LFG worker (Phase 1) | opencode | opencode-go/mimo-v2.5 | max |
| Judge (Phase 2) | opencode | opencode-go/minimax-m3 | high |
| Babysitter (Phase 2) | opencode | opencode-go/mimo-v2.5 | max |

Cross-family judge is mandatory — minimax-m3 (audit role) provides genuine contrast from the mimo-v2.5 fixer.
