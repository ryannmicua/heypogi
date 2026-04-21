---
name: heypogi-install-skills
description: Install all skills from this repo by creating Windows junctions from each skill folder under src/skills (only folders with a valid SKILL.md) into ~/.agents/skills. Use when the user asks to install skills from this repository into their local Codex skills directory.
---

Install this repo's skills by junction-linking them into the user's `~/.agents/skills` folder.

## Safety / Approval Gate

If `~/.agents/skills` does not exist, ask the user for approval before creating it.

Explain why: Codex discovers user skills from `~/.agents/skills`, so the folder is needed as the destination for the junction links that make the repo skills available without copying.

## Install

1. Compute paths:
   - Repo skills root: `<repo_root>/src/skills`
   - Destination: `~/.agents/skills`

2. Discover skills:
   - Only consider first-level directories under `<repo_root>/src/skills`.
   - Treat a directory as a skill only if it contains a **valid** `SKILL.md`:
     - Starts with YAML frontmatter `---`
     - Has closing `---`
     - Contains `name:` and `description:` in the frontmatter block

3. If destination folder exists, run the installer script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File src/skills/heypogi-install-skills/scripts/install_skills.ps1
```

4. If destination folder does not exist:
   - Ask for approval to create it.
   - If approved, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File src/skills/heypogi-install-skills/scripts/install_skills.ps1 -CreateDest
```

### Linux/macOS

If destination folder exists, run:

```bash
bash src/skills/heypogi-install-skills/scripts/install_skills.sh
```

If destination folder does not exist:

- Ask for approval to create it.
- If approved, run:

```bash
bash src/skills/heypogi-install-skills/scripts/install_skills.sh --create-dest
```

## Notes

- The installer uses junctions on Windows and symlinks on Linux/macOS so the skills stay in sync with the repo working tree.
- If a destination entry already exists, the scripts prompt per-skill to overwrite or skip (use `-Force` / `--force` to replace non-interactively).
- This workflow writes to `~/.agents/skills`. If your environment prompts for permission to write outside the repo/workspace, approve it so the junctions can be created.
- The Linux/macOS installer requires `bash`.
