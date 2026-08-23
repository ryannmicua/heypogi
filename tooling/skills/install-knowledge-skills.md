# Install Compound Knowledge Plugin Skills

Install the Compound Knowledge plugin skills by linking the repo's `external/compound-knowledge/plugins/compound-knowledge/skills` folder into `~/.agents/skills/compound-knowledge`.

## Safety / Approval Gate

If `~/.agents/skills` does not exist, ask the user for approval before creating it.

Explain why: Codex and OpenCode discover user skills from `~/.agents/skills`, so the folder is needed as the destination for the link that makes the CK plugin skills available without copying.

## Install

1. Compute paths:
   - CK skills root: `<repo_root>/external/compound-knowledge/plugins/compound-knowledge/skills`
   - Destination folder: `~/.agents/skills`
   - Link path: `~/.agents/skills/compound-knowledge`

2. If destination folder exists, run the installer script from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/skills/install-knowledge-skills.ps1
```

3. If destination folder does not exist:
   - Ask for approval to create it.
   - If approved, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/skills/install-knowledge-skills.ps1 -CreateDest
```

### Linux/macOS

If destination folder exists, run:

```bash
bash tooling/skills/install-knowledge-skills.sh
```

If destination folder does not exist:

- Ask for approval to create it.
- If approved, run:

```bash
bash tooling/skills/install-knowledge-skills.sh --create-dest
```

## Notes

- The installer uses one link for the whole CK skills folder, not one link per skill.
- The installer uses junctions on Windows and symlinks on Linux/macOS so the skills stay in sync with the repo working tree.
- If `~/.agents/skills/compound-knowledge` already exists, the scripts stop and show the existing target versus the intended target before asking whether to overwrite, skip, or quit.
- This workflow writes to `~/.agents/skills`. If your environment prompts for permission to write outside the repo/workspace, approve it so the link can be created.
- The Linux/macOS installer requires `bash`.
