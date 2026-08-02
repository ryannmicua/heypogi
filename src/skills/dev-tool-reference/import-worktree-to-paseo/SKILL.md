---
name: import-worktree-to-paseo
description: Use when discovering git worktrees in a repository and creating a Paseo workspace from one of them. Triggered by "import worktree", "create workspace from worktree", "adopt worktree", or when showing git worktree list and wanting to use one in Paseo.
---

# Import Worktree to Paseo

Discover all git worktrees in a repo and create a Paseo workspace from the one you choose, attaching it to an existing Paseo project whenever possible.

## Workflow

```
User asks to import/adopt a worktree
  → Run git worktree list
  → Gather existing Paseo state: paseo workspace ls --json + ~/.paseo/projects/projects.json
  → Classify each: primary, Paseo-managed, already-workspace, or candidate
  → If no candidates: report and stop
  → Present numbered menu of candidates
  → User picks one
  → Resolve the existing project for the worktree (match repo root / remote)
  → If a project exists:
      paseo workspace create --project <projectId> --isolation local --path <worktree> --title <branch>
    Else (fallback, new repo):
      paseo run --detach --cwd <worktree> --title <branch> --provider opencode "ls"
  → Report workspace + project + worktree details (markdown by default, JSON on request)
```

## Steps

### 1. Discover worktrees

Run `git worktree list` to enumerate all worktrees. Note each entry's path, commit, and branch. The **primary checkout** is the entry whose `.git` is a *directory* (not a file) — it is also the repo root used for project resolution in step 5.

### 2. Gather existing Paseo state

Run both:

- `paseo workspace ls --json` — existing workspaces. Collect each `workspaceId`, `cwd`, `project`, `name`, `isolation`.
- Read `~/.paseo/projects/projects.json` (default Paseo home; override with `PASEO_HOME`) — the source of truth for projects. Collect each `projectId`, `rootPath`, `displayName`, `projectKey`, `kind`, `customName`.

**The `projectId` in this file is the opaque ID to pass to `--project`. Display names shown by `paseo workspace ls` are NOT valid project IDs.**

Normalize paths (resolve symlinks, unify separators) for comparison.

### 3. Classify

For each worktree entry, classify as:

- **Primary** — the entry whose path matches the repo root (`.git` is a directory, not a file). Skip.
- **Paseo-managed** — path contains `\.paseo\worktrees\`. Skip — already managed by Paseo as a worktree.
- **Already a workspace** — the worktree path matches any existing workspace's `cwd` from step 2. Skip — a Paseo workspace already backs this directory.
- **Candidate** — everything else. These are worktrees created by other tools (OpenCode, manual) that can be imported.

If no candidates, report and stop.

### 4. Ask user to choose

Present candidates as a numbered list showing path and branch. Use the `question` tool with each candidate as an option:

```
1: <path> [branch]
2: <path> [branch]
```

### 5. Resolve the existing project

Find the project to attach the new workspace to:

1. Determine the repo root — the primary checkout path from step 1.
2. Find the project in `projects.json` whose `rootPath` equals that repo root. (For git repos the project is keyed by remote; for non-git directories by the local path — matching the primary root covers both.)
3. Use its `projectId`. If no project matches, there is no existing project — use the fallback in step 6.

### 6. Create the workspace

**Preferred — attach to an existing project:**

```bash
paseo workspace create --project "<projectId>" --isolation local --path "<worktree-path>" --title "<branch-name>" --json
```

- Use `--isolation local` even though the target is a git worktree. This *adopts the existing directory*; the server detects the worktree placement and reports isolation `worktree` with `cwd` = the existing worktree path.
- **Do NOT use `--isolation worktree` when adopting an existing directory** — it branches off and creates a brand-new Paseo-managed worktree under `~/.paseo/worktrees/` instead of wrapping the chosen one.
- Pass `--project` the opaque `projectId` (e.g. `remote:github.com/owner/repo` or `prj_...`), never the display name (`owner/repo`).

**Fallback — no existing project (unindexed/new repo):**

```bash
paseo run --detach --cwd "<worktree-path>" --title "<branch-name>" --provider opencode "ls"
```

`--detach` runs it in the background. The trivial `ls` prompt creates the workspace immediately. Note this auto-derives a project from the worktree root; if the repo's main checkout is already known, prefer creating the workspace against the repo root first so the project lands under the right directory.

### 7. Report the details

Return workspace, project, and worktree details per the Output section below.

## Output

Return **markdown text by default**; return **JSON** when the caller requests it (e.g. "as json", "machine-readable", or piping to another tool).

### Markdown (default)

```markdown
**Workspace created:** <name>
- Workspace ID: <workspaceId>
- Project: <project displayName> (<projectId>)
- Isolation: <isolation>
- CWD: <cwd>

**Project:** <displayName>
- Project ID: <projectId>
- Root path: <rootPath>
- Kind: <kind>

**Worktree:** <branch>
- Path: <path>
- Commit: <commit>
- Remote: <remote-url>

Use later with: --workspace <workspaceId>
```

### JSON

An object with `workspace`, `project`, and `worktree` keys, mirroring Paseo's own fields:

```json
{
  "workspace": {
    "workspaceId": "wks_...",
    "project": "owner/repo",
    "name": "feature-branch",
    "isolation": "worktree",
    "cwd": "C:\\...\\worktree"
  },
  "project": {
    "projectId": "remote:github.com/owner/repo",
    "displayName": "owner/repo",
    "rootPath": "C:\\...\\repo",
    "kind": "git",
    "projectKey": "remote:github.com/owner/repo",
    "customName": null
  },
  "worktree": {
    "path": "C:\\...\\worktree",
    "commit": "04a1efe",
    "branch": "feature-branch",
    "remoteUrl": "https://github.com/owner/repo.git",
    "mainRepoRoot": "C:\\...\\repo"
  }
}
```

Include every field Paseo returns (projectKey, customName, etc.) and every field from `git worktree list`; omit only null/empty values if desired.

## Important details for the caller

- **Running agents in the workspace:** `paseo run --workspace <workspaceId> "<task>"` (or `paseo run --agent` on the workspace) places sessions inside it.
- **Workspace is a stable container:** multiple agent sessions, terminals, and browsers can live in one workspace; sessions are separate from the workspace.
- **Directory ownership stays with the creator:** because this imports an existing (non-Paseo-managed) worktree directory, archiving the workspace will NOT delete the directory — Paseo only removes worktrees it created itself under `~/.paseo/worktrees/`.
- **Project persists independently:** attaching a workspace to a project works even if the project currently has no active workspaces; the project survives regardless.
- **IDs ≠ display names:** always resolve project IDs from `~/.paseo/projects/projects.json`, never from `paseo workspace ls` output.
- **An existing `paseo run --cwd`-style workspace is scoped to a derived project:** if a workspace already exists for the directory but under a different project, the "Already a workspace" classification skips it — flag this to the user rather than silently creating a duplicate.

## Common Mistakes

- **Including the primary repo** — the primary checkout (`.git` is a directory, not a file) should never be wrapped as a workspace this way; Paseo already manages it implicitly or you should use `paseo run` without `--cwd`.
- **Using `--isolation worktree` when adopting an existing directory** — this creates a brand-new Paseo-managed worktree and points the workspace at it, leaving the chosen directory untouched. Use `--isolation local` with the existing path.
- **Passing the display name as `--project`** — `paseo workspace create --project owner/repo` fails with "Unknown project". Pass the opaque `projectId` from `projects.json`.
- **Checking only `paseo ls --json` (agents) for existing workspaces** — an existing workspace may have no agents. Use `paseo workspace ls --json` to detect "Already a workspace".
- **Including already-Paseo worktrees** — Paseo-managed worktrees already have workspaces. Creating another would be redundant.
- **Missing existing workspace match** — a non-Paseo worktree (e.g. OpenCode-managed) may already have a Paseo workspace if one was created previously against that directory. Always check `paseo workspace ls --json` against the worktree path before offering it as a candidate.
- **Path uses forward slashes** — Windows paths from `git worktree list` may use forward slashes. Paseo accepts them, but pass the path as-is.
- **Worktree path no longer exists** — the directory may have been deleted manually. Skip any entry where the path doesn't exist on disk.
