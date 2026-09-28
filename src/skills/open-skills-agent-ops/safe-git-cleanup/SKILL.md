---
name: safe-git-cleanup
description: Audit and prune local or remote Git branches and linked worktrees within one repository. Use for stale-branch or worktree cleanup; show the exact eligible deletions and get operator confirmation by default.
---

# Safe Git Cleanup

Use this skill when an operator asks to prune branches, linked worktrees, or stale worktree metadata. Keep the operation scoped to one repository and its Git common directory.

## Authorization and scope

- Start with read-only inspection. Resolve the repository root and common Git directory, then inventory only refs and worktrees belonging to that repository.
- A linked worktree can live outside the repository directory. Treat its path as an owned worktree path; do not search or clean neighboring repositories.
- By default, prepare an exact deletion proposal and stop for the operator's confirmation before deleting anything. A general request such as “clean up” or “delete stale branches” is not a waiver. Skip the confirmation only when the operator explicitly says to proceed without asking or confirmation.
- A waiver skips the prompt only. It does not make an unsafe or unverified item eligible, authorize force deletion, or expand the operation to other repositories.
- Honor the requested object types and locations. A request to prune branches does not authorize worktree removal, and a request to remove worktrees does not authorize branch deletion. For a general repository cleanup request with no narrower scope, inspect local branches, each configured remote's server branches, linked worktrees, and stale worktree metadata as separate categories.

## Inspect and classify

1. Resolve the repository root and common Git directory. Record the current worktree and branch. Inspect `git status`, `git branch -vv`, `git branch -r -vv`, and `git worktree list --porcelain`.
2. Identify the repository's default branch from the remote's symbolic `HEAD` or another clear repository setting. If the base branch is ambiguous, do not label branches safe to delete.
3. Before judging remote refs, refresh the relevant remote with `git fetch <remote>` without `--prune`. This refreshes local tracking data but does not delete server branches. If fetching or checking the live remote fails, exclude its branches from the safe-to-delete list.
4. Check provider state for branches under consideration: open pull/merge requests for local branches with upstreams and remote branches, plus protected-branch settings for remote branches. If open-request state cannot be verified for a branch, mark it **unverified** and do not propose deleting it. If remote protection cannot be verified, do not propose deleting that remote ref.
5. Determine merge safety conservatively:
   - A branch is merged when its tip is an ancestor of the chosen default branch.
   - For squash or rebase merges, provider evidence may substitute only when it confirms that the exact current branch tip SHA was merged. A branch that advanced after the merged PR is not covered by that evidence.
   - Do not infer merge safety from branch age, naming, lack of activity, or a matching PR title.

### Local branch eligibility

A local branch can be proposed for deletion only when all of these are true:

- It is not the repository's default branch or another known protected branch, and it will not remain checked out in any worktree after the proposed cleanup.
- Its tip is proven merged by the rules above.
- No open pull/merge request depends on it.
- Any worktree currently checking it out is itself in the deletion proposal and can be safely removed first.

Use `git branch -d <branch>` for deletion. Never use `git branch -D` as a cleanup fallback.

### Remote branch eligibility

A server-side remote branch can be proposed only when all of these are true:

- It is not the remote's default branch or a protected branch.
- Its current server SHA is known and its tip is proven merged by the rules above.
- The provider confirms there is no open pull/merge request for it.
- The relevant remote and branch name are reported separately; same-named branches on different remotes are distinct refs.

Before deletion, re-read the live remote SHA. If it differs from the SHA in the proposal, stop and prepare a new proposal. Delete only the exact reviewed ref and SHA, using an expected-SHA lease where supported. Never use an unguarded force push.

### Linked worktree eligibility

A linked worktree can be proposed for removal only when all of these are true:

- It is not the current worktree for this session and is not locked.
- Its Git status is clean, including untracked and ignored files. Check with `git status --porcelain=v1 --untracked-files=all --ignored` from that worktree. Any output makes it ineligible until reviewed; this protects local files such as ignored credentials and configuration.
- Its `HEAD` commit remains reachable from a ref that will survive cleanup. A branch may be unmerged and still be retained; in that case, state clearly that the worktree directory will be removed but its branch will remain.
- If a workspace manager owns the worktree (for example, Paseo), verify its workspace/session state and use its documented removal flow. If ownership or activity cannot be checked, mark it for review rather than removing it directly.

Removing a worktree deletes its directory. Do not use `git worktree remove --force`, `git clean`, or manual recursive deletion. If Git refuses removal, stop and report why.

### Stale worktree metadata

Use `git worktree prune --dry-run --verbose` to inspect metadata for worktree directories that are already absent. Propose only the exact stale entries shown. Do not prune metadata for an existing but inaccessible path, or for a locked worktree. Before execution, repeat the dry run and stop if the candidate set changed.

Do not confuse pruning remote-tracking refs (`git fetch --prune` or `git remote prune`) with deleting branches on the remote server. Do not run either automatically as part of this skill.

## Present the proposal

Show the exact items that qualify, grouped by:

- Local branches: name, tip SHA, and proof of merge.
- Remote branches: remote/name, current server SHA, merge proof, and provider checks.
- Worktrees: full path, checked-out branch or detached SHA, clean-state result, and whether the branch will be kept or also deleted.
- Stale worktree metadata: exact missing path/entry.

Also list notable exclusions with a short reason, such as current branch, unmerged commits, dirty or ignored files, open PR, protected ref, unknown provider state, or active workspace. Do not present an unverified item as safe.

By default, stop after showing the proposal and ask the operator to confirm that exact list. Confirmation applies only to the displayed repository, refs, SHAs, and paths. If the operator changes the scope or items, refresh the proposal. If the operator explicitly waived confirmation, proceed only with the verified eligible list and report the plan before or as execution begins without waiting for approval.

## Execute and verify

Immediately before each deletion, recheck that the branch SHA, remote SHA, worktree status, and path still match the approved proposal. If any relevant state changed, stop and ask again with an updated list.

Remove approved worktrees first with `git worktree remove <path>` (or their verified manager's removal flow), then delete their approved local branches with `git branch -d`. Delete approved remote branches only at the reviewed SHA using the expected-SHA lease. Prune approved stale metadata only after the second dry run matches the proposal.

Afterward, verify each requested local ref, remote ref, and worktree is absent, and report what was deleted, what was retained, and any operation that stopped or failed. Do not retry with force or broaden the cleanup to additional refs.
