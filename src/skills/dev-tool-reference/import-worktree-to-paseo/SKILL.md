---
name: import-worktree-to-paseo
description: Use when discovering git worktrees in a repository and creating a Paseo workspace from one of them. Triggered by "import worktree", "create workspace from worktree", "adopt worktree", or when showing git worktree list and wanting to use one in Paseo.
---

# Import Worktree to Paseo

Discover all git worktrees in a repo and create a Paseo workspace from the one you choose.

## Workflow

```
User asks to import/adopt a worktree
  → Run git worktree list
  → Run paseo ls --json to get existing workspaces
  → Classify each: primary, Paseo-managed, already-workspace, or candidate
  → If no candidates: report and stop
  → Present numbered menu of candidates
  → User picks one
  → paseo run --detach --cwd <path> --title <branch> --provider opencode "ls"
  → Report workspace created with ID
```

## Steps

### 1. Discover worktrees

Run `git worktree list` to enumerate all worktrees.

### 2. Get existing workspaces

Run `paseo ls --json` and collect the `cwd` paths from all returned agents. Normalize paths (resolve symlinks, unify separators) for comparison.

### 3. Classify

For each entry, classify as:

- **Primary** — the entry whose path matches the repo root (contains `.git` as a directory, not a file). Skip.
- **Paseo-managed** — path contains `\.paseo\worktrees\`. Skip — already managed by Paseo as a worktree.
- **Already a workspace** — the worktree path matches any existing agent's `cwd` from step 2. Skip — a Paseo workspace already backs this directory.
- **Candidate** — everything else. These are worktrees created by other tools (OpenCode, manual) that can be imported.

If no candidates, report and stop.

### 4. Ask user to choose

Present candidates as a numbered list showing path and branch. Use the `question` tool with each candidate as an option:

```
1: <path> [branch]
2: <path> [branch]
```

### 5. Create Paseo workspace

```bash
paseo run --detach --cwd "<selected-path>" --title "<branch-name>" --provider opencode "ls"
```

The `--detach` flag runs it in background so it doesn't block. The trivial `ls` prompt creates the workspace immediately.

### 6. Report the workspace ID

The output shows `Created workspace <id> - <title>`. Report this to the user so they can reference it later with `--workspace <id>`.

## Common Mistakes

- **Including the primary repo** — the primary checkout (`.git` is a directory, not a file) should never be wrapped as a workspace this way; Paseo already manages it implicitly or you should use `paseo run` without `--cwd`.
- **Including already-Paseo worktrees** — Paseo-managed worktrees already have workspaces. Creating another would be redundant.
- **Missing existing workspace match** — a non-Paseo worktree (e.g. OpenCode-managed) may already have a Paseo workspace if one was created previously against that directory. Always check `paseo ls --json` against the worktree path before offering it as a candidate.
- **Path uses forward slashes** — Windows paths from `git worktree list` may use forward slashes. Paseo accepts them, but pass the path as-is.
- **Worktree path no longer exists** — the directory may have been deleted manually. Skip any entry where the path doesn't exist on disk.
