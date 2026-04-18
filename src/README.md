# `src/` taxonomy

This folder is the "usable kit" portion of `heypogi`: reusable assets you'll actively pull from when working.

## Layout

- `agents/` - agent configs (e.g., Codex agent profiles/instructions).
- `skills/` - Codex skills (`SKILL.md` + any supporting files).
- `prompts/` - copy/paste prompts grouped by purpose.
- `templates/` - reusable file templates (docs, checklists, scaffolds).
- `plugins/` - Codex plugin scaffolds and manifests.
- `tools/` - small scripts/CLIs/utilities that support your workflow.

## Conventions

- Prefer small, composable items over monoliths.
- Use clear names and add a short README in each folder.
- Put project-management artifacts in `docs/` (not here).
