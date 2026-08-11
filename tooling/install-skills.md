# Install Skills

Install this repo's skills by linking the repo `src/skills` folder into `~/.agents/skills/heypogi`.

## Safety / Approval Gate

If `~/.agents/skills` does not exist, ask the user for approval before creating it.

Explain why: Codex discovers user skills from `~/.agents/skills`, so the folder is needed as the destination for the link that makes the repo skills available without copying.

## Install

1. Compute paths:
   - Repo skills root: `<repo_root>/src/skills`
   - Destination folder: `~/.agents/skills`
   - Link path: `~/.agents/skills/heypogi`

2. If destination folder exists, run the installer script from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/install-skills.ps1
```

3. If destination folder does not exist:
   - Ask for approval to create it.
   - If approved, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/install-skills.ps1 -CreateDest
```

### Linux/macOS

If destination folder exists, run:

```bash
bash tooling/scripts/install-skills.sh
```

If destination folder does not exist:

- Ask for approval to create it.
- If approved, run:

```bash
bash tooling/scripts/install-skills.sh --create-dest
```

## Notes

- The installer uses one link for the whole repo skills folder, not one link per skill.
- The installer uses junctions on Windows and symlinks on Linux/macOS so the skills stay in sync with the repo working tree.
- If `~/.agents/skills/heypogi` already exists, the scripts stop and show the existing target versus the intended target before asking whether to overwrite, skip, or quit.
- This workflow writes to `~/.agents/skills`. If your environment prompts for permission to write outside the repo/workspace, approve it so the link can be created.
- The Linux/macOS installer requires `bash`.
