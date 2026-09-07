## Superpowers location override

- Save specs to: `docs/specs/` (do not use `docs/superpowers/specs/`)
- Save plans to: `docs/plans/` (do not use `docs/superpowers/plans/`)

## Project management guidance

- Check `docs/AGENTS.md` for potential context when creating new specifications or implementation plans; performing reviews or gap analyses; reporting on project status or changes; working on multi-step tasks that need tracking; doing session digest work; summarizing conversations or extracting lore; checking for past decisions or conversations;.
- `docs/solutions/` holds documented solutions to past problems (bugs, best practices, workflow patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`); relevant when implementing or debugging in documented areas.
- `CONCEPTS.md` (repo root) holds the shared domain vocabulary — entities, named processes, and status concepts; relevant when orienting to the codebase or discussing domain concepts.

## Git workflow

- When user says **commit** or **push**, commit and push directly to the current branch (no branching, no PRs) unless the user explicitly says otherwise.
- This repo does not use a PR-based workflow by default.

## Script work

- For any request to write, update, review, explain, or advise on a script—or to codify commands, setup steps, provisioning, maintenance, or operational behavior into a script—use the `script-contract` skill and read `docs/standards/scripts.md` completely before proceeding.
- This applies even when the script does not exist yet or its implementation language has not been selected.
- If the script is Bash, a `.sh` file, a shell entrypoint, or Bash is being considered as the implementation language, also use the `bash-script-contract` skill and read `docs/standards/bash-scripts.md` completely.
- Apply the general standard first, followed by the language-specific standard. A language-specific standard may strengthen but must not weaken the general standard.
