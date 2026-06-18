---
lorespec: "0.1"
id: "2026061802"
date: "2026-06-18"
source: "opencode"
topic: "Refactor OpenCode agent folder naming to shorten @mention references"
tags: [heypogi, opencode, agent-configuration, naming-convention, repo-structure]
classification:
  type: technical
  secondary_type: strategy
  domains: [developer-tooling, agent-configuration]
  value: high
trails: [heypogi_repo_structure, heypogi_agent_structure]
---

## Session Arc

### Started
User observed that folder-based agents in `dotfiles/opencode/agents/` have long @mention paths (`@agent-ui-design-strategist/ui-design-strategist`) compared to flat-file agents (`@auditor`), but noted folder agents carry references and supporting files.

### Pivots
- Called two subagents (ui-design-strategist and auditor) to analyze the tradeoff. Both independently converged on the same root cause: `agent-` folder prefix redundancy + file-name duplication.
- User asked whether references should be moved out of the agents folder entirely. Investigated OpenCode source (`entry-name.ts`, `agent.ts`) to understand how agent names are resolved and whether `references/` receives any special treatment.
- Realized OpenCode provides no auto-loading magic for `references/` directories. The co-location benefit is purely organizational, not functional. This settled the tradeoff: keep references inside, shorten names instead.

### Ended
Renamed three folders (dropped `agent-` prefix) and renamed inner agent files to `agent.md`. No config changes needed. @mention lengths cut ~40–50%.

## ARTIFACTS

### A1 - Refactored agent directory structure
Final structure after renames:
```
dotfiles/opencode/agents/
  agentic-delivery-architect/    # was agent-agentic-delivery-architect/
    agent.md                      # was agentic-delivery-architect.md
    references/ (5 files)
    scripts/ (1 file)
  software-delivery-architect/   # was agent-software-delivery-architect/
    agent.md                      # was software-delivery-architect.md
    references/ (4 files)
    scripts/ (1 file)
  ui-design-strategist/          # was agent-ui-design-strategist/
    agent.md                      # was ui-design-strategist.md
    references/ (3 files)
  aix.md, auditor.md, builder.md, opencode.md, orchestrator.md, planner.md
```

@mention length impact:
| Before | After | Change |
|---|---|---|
| `@agent-ui-design-strategist/ui-design-strategist` (39) | `@ui-design-strategist/agent` (23) | -16 |
| `@agent-software-delivery-architect/software-delivery-architect` (50) | `@software-delivery-architect/agent` (31) | -19 |
| `@agent-agentic-delivery-architect/agentic-delivery-architect` (50) | `@agentic-delivery-architect/agent` (29) | -21 |

## DECISIONS

### D1 - Keep references/scripts inside agent folders
- **Decision**: Do not extract `references/` and `scripts/` directories out of agent folders
- **Issue**: Whether to move supporting files outside the `agents/` directory to allow flat `.md` agent files with short @mention names
- **Positions**: (a) Extract references to a separate directory tree for flat agent files and short names. (b) Keep references co-located and shorten names by renaming folders/files instead
- **Arguments**: Position (b) won because: OpenCode provides no auto-loading of `references/` — they are plain directories. Co-location provides clear ownership of supporting files. Moving out would require `external_directory` permissions and path management. The `agent-ui-design-strategist` could theoretically inline its 3 references (no scripts), but the other two agents have scripts that need the folder structure anyway
- **Warrant**: The folder pattern exists to bundle supporting files with an agent. If you extract those files, the folder has no reason to exist, but you lose the natural coupling. Since OpenCode doesn't reward you for flat files (no `index.md` shortcut), the co-location benefit outweighs the reference-length cost
- **Qualifier**: settled
- **Status**: settled

### D2 - Drop `agent-` prefix from folder names
- **Decision**: Rename folders from `agent-XYZ` to `XYZ`
- **Issue**: The `agent-` prefix is redundant since the files are already inside an `agents/` directory
- **Positions**: Keep prefix (consistency within the directory) vs drop it (shorten references)
- **Arguments**: No functional impact. Saves 6 characters per reference. No discoverability loss — the directory context already signals these are agents
- **Qualifier**: always
- **Status**: settled

### D3 - Name inner agent file `agent.md` instead of duplicating folder name
- **Decision**: Use `agent.md` as the standard inner file name for folder-based agents
- **Issue**: Folder agents had the folder name repeated as the file name (e.g., `software-delivery-architect/software-delivery-architect.md`), doubling the role name in the @mention
- **Positions**: Use `agent.md`, `index.md`, or keep the duplicated name
- **Arguments**: `agent.md` is descriptive, creates self-documenting mentions like `@ui-design-strategist/agent`, and eliminates the redundant second copy. `index.md` is ambiguous (could be confused with directory index). Keeping the duplicated name is wasteful
- **Warrant**: The folder name already identifies the agent. The file name only needs to say "this is the agent definition file"
- **Qualifier**: always (for any new folder-based agents)
- **Status**: settled

## INSIGHTS

### I1 - OpenCode agent name resolution
OpenCode derives @mention names by taking the path relative to `agents/` and stripping the `.md` extension. No special handling for `index.md` or any other reserved filename. Source: `packages/opencode/src/config/entry-name.ts` (19 lines) — `configEntryNameFromPath` strips prefixes then trims extension.

### I2 - `references/` directory has no special status in OpenCode
The `references/` folder inside agent directories is a plain directory. OpenCode's agent loading (`agent.ts:13`) scans `{agent,agents}/**/*.md` to find agent definitions, but does not auto-load, index, or serve any other files. The agent accesses reference files on its own via `read` permission. This means there is zero functional penalty to moving references out, but also zero functional benefit to keeping them in — it's purely organizational.

### I3 - Two independent sources of reference bloat
Long agent @mention paths come from two additive sources: (a) the `agent-` folder prefix adds 6 redundant characters, and (b) the file name duplicates the folder name (e.g., `agent-XYZ/XYZ`). Fixing either alone leaves significant bloat. Fixing both cuts reference length roughly in half.

### I4 - Structural inconsistencies across agent definitions
Audit found 6 inconsistencies between flat and folder agents: permission granularity, `model:` field presence, description format (quoted vs folded YAML blocks), `agent-` prefix convention, `scripts/` presence, and ad hoc fields (e.g., `temperature`, `color`). Only `aix.md` has `temperature: 0.2`. Only `opencode.md` has `color: primary`. This is technical debt for when the team adds more agents.

## PATTERNS

### P1 - Agent folder naming convention for OpenCode
- Scope: **local** (this repo's agent definitions)
- Components:
  1. Folder name: role-description without `agent-` prefix (e.g., `ui-design-strategist`)
  2. Inner file: always named `agent.md`
  3. Supporting files go in `references/` (documentation) or `scripts/` (executables)
- Result: @mention is `@<folder-name>/agent` — predictable, readable, and short enough

## CONNECTIONS
- D1 —[informed_by]→ I2 ("references/ has no special status")
- D2 —[informed_by]→ I3 ("two sources of bloat")
- D3 —[informed_by]→ I3 ("two sources of bloat")
- A1 —[instance_of]→ P1 ("agent folder naming convention")
- D2 —[led_to]→ A1 (folder rename implemented)
- D3 —[led_to]→ A1 (file rename implemented)
- I4 —[related_to]→ 2026061801 (prior digest noted repo structure conventions)

## Trail Updates

- **heypogi_agent_structure** — New trail. Covers agent definition conventions, folder structure, naming, permissions, and consistency standards for agents in `dotfiles/opencode/agents/`.
- **heypogi_repo_structure** — Extended. Agent directory naming convention documented alongside other repo structure decisions.
