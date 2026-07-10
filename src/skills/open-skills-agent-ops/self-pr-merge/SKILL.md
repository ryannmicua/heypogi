---
name: self-pr-merge
description: Review and merge pull requests you authored yourself, with real review discipline despite GitHub not allowing self-approval. Use when merging your own PR or doing review-and-merge of self-authored work.
---

# Self-Authored PR Merge

Review and merge pull requests you authored yourself with genuine review discipline. GitHub's approval model doesn't accommodate self-review — this skill encodes the sequence so it happens correctly every time.

## Trigger Conditions

- User asks to merge their own PR
- User asks to review-and-merge something they wrote
- User says "ship this PR" or "merge my PR"

## Prerequisites

Confirm `gh` CLI is authenticated:
```
gh auth status
```

Ask the user for preferences (if not yet known):
- **Merge strategy**: squash, merge commit, or rebase
- **Branch cleanup**: delete remote branch after merge? (yes/no)

Default when unstated: squash merge, delete branch after merge.

## Step 1: Genuine Review Pass (FIRST)

Before any merge action, do a real review:

1. Run `gh pr view <pr-url-or-number> --json title,body,files,additions,deletions` to get PR metadata
2. Run `gh pr diff <pr-url-or-number>` and read the full diff with fresh eyes
3. Check for:
   - Bugs or logic errors
   - Debug leftovers (`console.log`, `debugger`, commented-out code)
   - Missing tests for new behavior
   - Scope creep (changes unrelated to the stated purpose)
   - Breaking changes not flagged
   - Secrets or keys accidentally committed
   - Style or convention violations
4. **Show findings to the user before proceeding** — finding nothing must be a conclusion reached by inspection, never a default assumption

## Step 2: Pre-Merge Checks

- Run `gh pr checks <pr-url-or-number>` — CI must be green
- Run `gh pr view <pr-url-or-number> --json mergeable` — must be mergeable
- Check for conflicts: `gh pr view <pr-url-or-number> --json mergeStateStatus`
- Note the self-approval limitation honestly: GitHub won't let you approve your own PR, but this review pass documents that the work was checked

## Step 3: Merge

Use the user's preferred strategy:
```
# Squash (default)
gh pr merge <pr-url-or-number> --squash --delete-branch

# Merge commit
gh pr merge <pr-url-or-number> --merge --delete-branch

# Rebase
gh pr merge <pr-url-or-number> --rebase --delete-branch
```

## Step 4: Cleanup

- Delete the remote branch (handled by `--delete-branch` flag above)
- If local worktrees are involved, use worktree-safe removal:
  ```
  git worktree remove <path>   # NOT plain `git branch -D`
  ```
- Never use `git branch -D` on a branch currently checked out in a worktree

## Stop Rule

Any failing check or unresolved review finding halts the merge. Return findings to the user with a clear explanation — do not bypass, skip, or override.
