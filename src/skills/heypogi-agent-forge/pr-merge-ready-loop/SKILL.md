---
name: pr-merge-ready-loop
description: Drive a pull request to a verified merge-ready conclusion using a three-role loop — a merge readiness agent (judge) that decides verdicts and fix-lists, a ce-babysit-pr babysitter that watches and executes fixes, and Copilot as the primary reviewer (via request-copilot-code-review). Use when the user wants to "open a PR and get it ready to merge", "have it reviewed and merge-ready", "babysit until it can merge", or wants an explicit review-driven merge-readiness gate before merging. Readiness requires at least one Copilot review on the current head AND a judge assessment concluding ready, with CI green as required evidence. The skill never merges — it returns a ready verdict and the operator merges. Not for reviewing code yourself (use ce-code-review), not for implementing without a PR (use ce-work), and not for a one-shot review request (use request-copilot-code-review).
---

# PR Merge-Ready Loop

Drive a pull request from "opened" to a **verified merge-ready verdict** through a three-role loop: a **merge readiness agent** (the judge) that decides, a **babysitter** (ce-babysit-pr) that watches and executes, and **Copilot** as the primary reviewer.

The core architectural principle: **decision authority and mutation authority are separated.** The judge never touches the PR; the babysitter never judges its own fixes. A fixer that also decides its own fixes are good enough is a rubber stamp — this loop exists to prevent that.

The skill **never merges**. Its terminal output is a verdict: *ready to merge* (with evidence) or *needs human* (with residuals). The operator makes the merge call.

## Roles

| Role | Agent | Authority | Never |
|---|---|---|---|
| **Caller** | Operator / orchestrator | Opens the PR; receives the verdict; merges | — |
| **Merge readiness agent (judge)** | A different model family than the fixer (cross-family contrast) | Read-only decisions: verdict, fix-list, review-round request | Mutates the PR (no edits, commits, pushes, reviewer requests, thread ops) |
| **Babysitter** | ce-babysit-pr (the executor) | All mutations: fix commits, push, resolve threads, CI reruns, executing Copilot review requests | Deciding merge-readiness or fix-worthiness on its own judgment |
| **Copilot** | copilot-pull-request-reviewer[bot] | The primary reviewer; its review is the raw material the judge assesses | — |

## Readiness conditions (the judge's gate)

The PR is merge-ready **only when all of the following hold**:

1. **At least one Copilot review exists** — and the latest review is **on the current head SHA** (a review of an older head does not satisfy this; re-review must be requested if code changed since the last review).
2. **The judge's assessment of the review findings concludes ready** — every finding is either fixed-and-verified, explicitly declined with reason, or parked as a non-blocking follow-up.
3. **CI is green on the current head** (required evidence input, even though it is not a formal condition): no failing checks on the current head's rollup. An empty rollup is *not* green — CI must have run and passed.

## The loop

```
Trigger: caller wants a PR merge-ready
  → Step 1: Open the PR (or adopt an existing one)
  → Step 2: Spawn the judge with an empty verdict log
  → Step 3: Spawn the babysitter (ce-babysit-pr) wired to the judge contract
  → Step 4: Run the review-fix-verify loop (below)
  → Terminal: ready verdict → return to caller; needs-human → surface residuals
```

### Step 1 — Open the PR

If no PR exists for the branch: `gh pr create` with a complete body (summary, verification evidence, test recipe, checklist). If a PR already exists, adopt it as-is. Record the head SHA.

### Step 2 — Spawn the judge

The judge is a **read-only decision agent** with exactly three outputs per round:

- **Verdict**: `ready` | `not-ready` | `needs-human`
- **Fix-list**: findings to fix, each with `{id, location, severity, action}` where action ∈ `fix | decline | park`
- **Review-round decision**: `request_copilot_round: true|false` (request another Copilot review of the new head)

Give the judge the **verdict log** (see contract below) — it reads prior rounds before deciding, so findings already declined or fixed are not re-litigated. The judge's model family must differ from the babysitter/fixer family (cross-family contrast is what makes the verdict independent).

### Step 3 — Spawn the babysitter

The babysitter runs **ce-babysit-pr** on the PR, with the judge contract in its brief:

- When a new review lands, the babysitter **asks the judge** (passing the verdict log + snapshot) whether any findings warrant fixes and which ones.
- **No fixes needed + judge verdict ready** → the babysitter returns the ready verdict to the caller (Step 4b).
- **Fixes needed** → the babysitter implements exactly the judge's fix-list (its own judgment extends only to *how*, never *whether*), runs the repo's verification gates, commits, pushes, resolves the threads, and **informs the judge** of the new fixes (Step 4c).
- The judge decides whether the fixes are sufficient to assert readiness, or whether to request **another Copilot round** — which the babysitter *executes* via `request-copilot-code-review` (the judge decides; the executor performs; the judge never mutates).

### Step 4 — The review-fix-verify loop

**a. Review arrives.** Babysitter wakes (ce-babysit-pr's watch), snapshots, passes the verdict log + snapshot to the judge. Judge returns verdict + fix-list.

**b. Ready.** If fix-list is empty and verdict is `ready` (and readiness condition 3 holds — CI green on current head): babysitter returns to the caller: `{status: ready-to-merge, head_sha, reviews, fixes, verdict_log}`. **The caller merges; the loop never does.**

**c. Fixes.** Babysitter implements the fix-list, verifies (repo gates + CI), pushes, informs the judge with `{round, fixes_applied, head_sha}`. Judge re-assesses: either asserts `ready` (→ b), requests another Copilot round (→ a, executed via request-copilot-code-review), or returns `needs-human` (→ d).

**d. Needs-human.** Park the residual on the thread, surface to the caller with the verdict log and competing options. The loop keeps watching other streams (per ce-babysit-pr) but the blocked item never gets forced.

## Verdict log contract

A durable file the judge reads and writes each round (path chosen by the caller; e.g. `<worktree>/tmp/merge-ready-verdicts.json` — gitignored scratch). The babysitter passes it in every assessment request; the judge appends one entry per round.

```json
{
  "pr": "https://github.com/OWNER/REPO/pull/N",
  "rounds": [
    {
      "round": 1,
      "head_sha": "…",
      "review_sha": "…",
      "findings": [
        {"id": "C1", "location": "src/x.py:42", "severity": "P1|P2|P3",
         "action": "fix|decline|park", "reason": "…"}
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

Rules: the judge writes exactly one round entry per assessment; `fixes_verified` is filled only after the judge has seen the fix commits; a finding once `decline`d is never re-opened unless new evidence appears; `state` becomes `ready` only when all three readiness conditions hold.

## Hard rules

1. **The judge never mutates.** No edits, commits, pushes, reviewer requests, thread operations, CI reruns. It decides; the babysitter executes. (This includes Copilot review requests: judge decides `request_copilot_round`, babysitter runs `gh pr edit <N> --add-reviewer "@copilot"`.)
2. **The loop never merges.** Terminal states are `ready-to-merge` (returned to caller) and `needs-human` (surfaced). Merge is the operator's call.
3. **Cross-family judge.** The judge must be a different model family from the fixer. Same-family judges reproduce the fixer's blind spots — the entire point is independent assessment.
4. **Current-head reviews only.** A review of an old head does not count toward readiness condition 1. Code changed since the last review ⇒ request a new Copilot round before any ready verdict.
5. **Empty rollup is not green.** Readiness condition 3 requires CI to have *run and passed* on the current head.
6. **Bound the loop.** Cap Copilot review rounds (default 3) before surfacing non-convergence to the caller. If the judge keeps requesting rounds without convergence, hand the trajectory to the caller as `needs-human` — a reviewer that always finds something is a human decision, not a loop condition. ce-babysit-pr's trajectory machinery (recurring checks, stream alternations) informs this call.
7. **Fix-list discipline.** The babysitter fixes exactly what the judge orders. If the babysitter's ce-resolve-pr-feedback pass discovers a *new* finding (a thread the judge did not see), it routes it to the judge rather than self-deciding.

## Realization notes (Paseo / Windows)

- **Provider mapping (default, per orchestration-preferences):** judge = audit role (e.g. minimax-m3, thinking on); babysitter = impl role (e.g. deepseek-v4-flash, max). Never the same family.
- The judge does not need to be a parked long-lived agent: a re-spawned judge with the verdict log achieves memory at lower cost. A parked judge is only warranted when rounds are frequent enough to justify it.
- The babysitter runs `ce-babysit-pr`'s watch loop (Windows adaptations apply: state dir under the pre-approved temp path, `python`-invoked helper, blocking-watch pattern).
- Copilot review requests: `gh pr edit <N> --add-reviewer "@copilot"` — quote the value on PowerShell (bare `@` is a splatting operator), then verify via GraphQL that `copilot-pull-request-reviewer` is in `reviewRequests` (see request-copilot-code-review).

## Failure modes to surface to the caller

- **Non-convergence** — judge requests round after round without progress (cap hit).
- **Judge/fixer disagreement** — the judge orders a fix the fixer's verification cannot satisfy, or the fixer's implementation contradicts the judge's assessment.
- **Reviewer inactivity** — Copilot review requested but not landing; babysitter watch idle for an extended period.
- **Blocked items** — findings the judge parks as `needs-human` (approach-level choices, contract changes, trade-offs).

In every case: return `{status, head_sha, rounds, residuals, verdict_log_path}` — the verdict log is the audit trail the caller uses to make the merge call.
