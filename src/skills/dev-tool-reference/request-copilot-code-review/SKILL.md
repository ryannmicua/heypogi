---
name: request-copilot-code-review
description: Request a GitHub Copilot code review on an existing pull request (or when creating one), and verify the request landed. Use when the user asks to "ask copilot to review", "request a copilot review", "have copilot look at this PR", or wants Copilot's code review on a pull request. Covers the gh CLI mechanism, verification that copilot-pull-request-reviewer[bot] is an active requested reviewer, and known dead ends (gh copilot CLI is NOT PR review; the REST copilot-code-review endpoint 404s). GitHub only; does not wait for or resolve the review itself (pair with ce-babysit-pr for the watch loop).
---

# Request Copilot Code Review

Request a review from GitHub Copilot on a pull request and confirm the request actually landed. GitHub Copilot code review runs as the `copilot-pull-request-reviewer[bot]` agent; requesting it is a standard reviewer-request operation, not a special API.

Requires: `gh` CLI v2.88.0+ (the `@copilot` reviewer alias landed March 2026), an account with Copilot code review, GitHub (github.com or GHE via `gh` config). If `gh` is older or Copilot code review is not enabled for the plan, the command fails or silently no-ops — verify after requesting.

## Workflow

```
User asks to have Copilot review a PR
  → Resolve the PR (number/URL/branch)
  → gh pr edit <N> --add-reviewer "@copilot"   (quote it!)
  → Verify: GraphQL reviewRequests contains copilot-pull-request-reviewer
  → Report requested; note the review will arrive asynchronously
```

## Steps

### 1. Resolve the pull request

Use the number, URL, or branch name. If the PR is not from the current checkout's branch, pass the number explicitly.

### 2. Request the review

Existing PR:

```powershell
gh pr edit <N> --add-reviewer "@copilot"
```

Creating a new PR (equivalent):

```powershell
gh pr create --reviewer @copilot
```

**The quotes are load-bearing on PowerShell.** A bare `@copilot` is parsed as a splatting operator and the command fails with `flag needs an argument: --add-reviewer`. Quote the value: `"@copilot"`. On bash/zsh, `gh pr edit <N> --add-reviewer @copilot` works unquoted.

### 3. Verify the request landed

Copilot is a **Bot**, not a user — a silent no-op is possible if the plan/CLI is wrong. Confirm via GraphQL that `copilot-pull-request-reviewer` is in the PR's review requests:

```powershell
$q = 'query { repository(owner:"OWNER", name:"REPO") { pullRequest(number:N) { reviewRequests(first:10) { nodes { requestedReviewer { __typename ... on Bot { login } ... on User { login } } } } } } }'
gh api graphql -f query=$q
```

Expected: `{"__typename":"Bot","login":"copilot-pull-request-reviewer"}`. If the list is empty or lacks the bot, the request did not land — do not claim success.

### 4. Report

State: review requested against which head SHA, and that the review arrives asynchronously (Copilot posts a `COMMENTED` review with inline comments; low-confidence findings may be posted suppressed). Do not fabricate a review that has not arrived.

## Known dead ends (do not retry)

- **`gh copilot` CLI is NOT PR review.** It is the Copilot terminal assistant. Running `gh copilot ...` does not review the PR.
- **`POST /repos/{owner}/{repo}/pulls/{N}/copilot-code-review/requests` → 404.** The Copilot review is requested through the standard review-requests surface, not a dedicated endpoint.
- **`gh pr edit --add-reviewer Copilot` (no `@`)** fails on PowerShell quoting as above; with the bot name it may not resolve. Use `"@copilot"`.
- **GraphQL `requestReviewsByLogin` with `botLogins`** is an alternative trigger but requires the bot's node ID and is not needed when `gh pr edit --add-reviewer "@copilot"` works.

## What happens next (optional integration)

- The review posts asynchronously; poll `gh pr view <N> --json reviews` or the review threads to see it.
- To keep driving the PR (resolve feedback, watch CI, currency), pair with **ce-babysit-pr** — its watch loop picks up Copilot review threads automatically and delegates resolution to ce-resolve-pr-feedback. Convergence for "fully reviewed": latest Copilot review on the current head SHA + no open threads.
