# Skill Usage — Last 14 Days

Goal: keep only the agent skills actually used. This report ranks every installed skill by
real usage evidence from opencode session history.

## Method

- **Source:** `~/.local/share/opencode/opencode.db` (read-only)
- **Probe:** `opencode-session-history` skill's `probe.py` + direct SQL over the `part` table
- **Window:** sessions updated in the last 14 days (cutoff: 14 × 24 h before report generation, 2026-08-14)
- **Scope:** all 842 opencode sessions updated in the window, across every repo and Paseo worktree
- **Evidence:** `tool` parts with `tool: "skill"` — the only mechanism that loads a skill
- **Counts:** loads = skill invocations (200 total); sessions = distinct sessions that loaded it (analysis session excluded)

## Summary

| Metric | Value |
|---|---|
| Sessions in window | 842 |
| Total skill loads | 200 |
| Distinct skills used | 48 |
| Installed skills (global library) | 96 |
| Installed skills **not** used | 49 |

## Used skills — most to least used

| # | Skill | Loads | Sessions | Path |
|---|-------|-------|----------|------|
| 1 | `ce-doc-review` | 15 | 15 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-doc-review\SKILL.md` |
| 2 | `paseo-reference` | 15 | 15 | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\paseo-reference\SKILL.md` |
| 3 | `ce-compound` | 13 | 13 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-compound\SKILL.md` |
| 4 | `opencode-session-history` | 13 | 13 | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\opencode-session-history\SKILL.md` |
| 5 | `ce-plan` | 12 | 12 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-plan\SKILL.md` |
| 6 | `session-digest` | 11 | 11 | `C:\Users\rmicua\.agents\skills\heypogi\me\session-digest\SKILL.md` |
| 7 | `ce-proof` | 9 | 9 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-proof\SKILL.md` |
| 8 | `wrapup` | 9 | 9 | `C:\Users\rmicua\.agents\skills\heypogi\me\wrapup\SKILL.md` |
| 9 | `ce-code-review` | 7 | 7 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-code-review\SKILL.md` |
| 10 | `ce-brainstorm` | 6 | 6 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-brainstorm\SKILL.md` |
| 11 | `ce-pov` | 6 | 6 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-pov\SKILL.md` |
| 12 | `ce-babysit-pr` | 5 | 5 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-babysit-pr\SKILL.md` |
| 13 | `ce-work` | 5 | 5 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-work\SKILL.md` |
| 14 | `html-artifacts` | 5 | 5 | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-core-infrastructure\html-artifacts\SKILL.md` |
| 15 | `ce-simplify-code` | 4 | 4 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-simplify-code\SKILL.md` |
| 16 | `ce-strategy` | 4 | 4 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-strategy\SKILL.md` |
| 17 | `goal-prompt-generator` | 4 | 4 | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\goal-prompt-generator\SKILL.md` |
| 18 | `paseo` | 4 | 4 | `C:\Users\rmicua\.agents\skills\paseo\SKILL.md` |
| 19 | `write-docs-diataxis` | 4 | 4 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-writing\write-docs-diataxis\SKILL.md` |
| 20 | `agentic-harness-designer` | 3 | 3 | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\agentic-harness-designer\SKILL.md` |
| 21 | `browser-qa` | 3 | 3 | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-testing-quality\browser-qa\SKILL.md` |
| 22 | `ce-compound-refresh` | 3 | 3 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-compound-refresh\SKILL.md` |
| 23 | `customize-opencode` | 3 | 3 | `(built-in — ships with opencode)` |
| 24 | `my-writing-voice` | 3 | 2 | `C:\Users\rmicua\.agents\skills\heypogi\me\my-writing-voice\SKILL.md` |
| 25 | `vision-strategy-align` | 3 | 3 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-planning\vision-strategy-align\SKILL.md` |
| 26 | `anti-sycophancy` | 2 | 2 | `C:\Users\rmicua\.agents\skills\heypogi\joel-salinas\anti-sycophancy\SKILL.md` |
| 27 | `ce-commit-push-pr` | 2 | 2 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-commit-push-pr\SKILL.md` |
| 28 | `ce-ideate` | 2 | 2 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-ideate\SKILL.md` |
| 29 | `ce-resolve-pr-feedback` | 2 | 2 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-resolve-pr-feedback\SKILL.md` |
| 30 | `ce-test-browser` | 2 | 2 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-test-browser\SKILL.md` |
| 31 | `pr-merge-ready-loop` | 2 | 2 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\pr-merge-ready-loop\SKILL.md` |
| 32 | `presentation-builder` | 2 | 2 | `C:\Users\rmicua\.agents\skills\heypogi\joel-salinas\presentation-builder\SKILL.md` |
| 33 | `request-copilot-code-review` | 2 | 2 | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\request-copilot-code-review\SKILL.md` |
| 34 | `architecture-doc-set` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-planning\architecture-doc-set\SKILL.md` |
| 35 | `behavior-placement` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\behavior-placement\SKILL.md` |
| 36 | `ce-commit` | 1 | 1 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-commit\SKILL.md` |
| 37 | `ce-debug` | 1 | 1 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-debug\SKILL.md` |
| 38 | `ce-explain` | 1 | 1 | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-explain\SKILL.md` |
| 39 | `dispatch-setup` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\dispatch-setup\SKILL.md` |
| 40 | `gpt-5-6-prompt-auditor` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\gpt-5-6-prompt-auditor\SKILL.md` |
| 41 | `import-worktree-to-paseo` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\import-worktree-to-paseo\SKILL.md` |
| 42 | `kw:review` | 1 | 1 | `C:\Users\rmicua\.agents\skills\compound-knowledge\kw-review\SKILL.md` |
| 43 | `lfg` | 1 | 1 | `C:\Users\rmicua\.agents\skills\compound-engineering\lfg\SKILL.md` |
| 44 | `paseo-escalate` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\paseo-escalate\SKILL.md` |
| 45 | `paseo-loop` | 1 | 1 | `C:\Users\rmicua\.agents\skills\paseo-loop\SKILL.md` |
| 46 | `testing-runbook-creator` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-testing-quality\testing-runbook-creator\SKILL.md` |
| 47 | `work-brief-builder` | 1 | 1 | `C:\Users\rmicua\.agents\skills\work-brief-builder\SKILL.md` |
| 48 | `write-handoff` | 1 | 1 | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-writing\write-handoff\SKILL.md` |

## Not used in the last 14 days — removal candidates

49 installed skills had **zero** skill-tool loads in the window.

| Skill | Path |
|-------|------|
| `agent-spec-builder` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\agent-spec-builder\SKILL.md` |
| `atlas-lookup` | `C:\Users\rmicua\.agents\skills\heypogi\atlas-lookup\SKILL.md` |
| `audience-content-system` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-writing-voice-content\audience-content-system\SKILL.md` |
| `branded-image-prompting` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-writing-voice-content\branded-image-prompting\SKILL.md` |
| `ce-dogfood` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-dogfood\SKILL.md` |
| `ce-handoff` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-handoff\SKILL.md` |
| `ce-optimize` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-optimize\SKILL.md` |
| `ce-polish` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-polish\SKILL.md` |
| `ce-product-pulse` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-product-pulse\SKILL.md` |
| `ce-promote` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-promote\SKILL.md` |
| `ce-retune` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-retune\SKILL.md` |
| `ce-riffrec-feedback-analysis` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-riffrec-feedback-analysis\SKILL.md` |
| `ce-setup` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-setup\SKILL.md` |
| `ce-sweep` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-sweep\SKILL.md` |
| `ce-test-xcode` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-test-xcode\SKILL.md` |
| `ce-worktree` | `C:\Users\rmicua\.agents\skills\compound-engineering\ce-worktree\SKILL.md` |
| `clarity-without-drift` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-writing\clarity-without-drift\SKILL.md` |
| `create-opencode-agent` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\create-opencode-agent\SKILL.md` |
| `dashboard-builder` | `C:\Users\rmicua\.agents\skills\heypogi\joel-salinas\dashboard-builder\SKILL.md` |
| `financial-model-builder` | `C:\Users\rmicua\.agents\skills\heypogi\joel-salinas\financial-model-builder\SKILL.md` |
| `it-ops-ticket-assistant` | `C:\Users\rmicua\.agents\skills\heypogi\it-ops\it-ops-ticket-assistant\SKILL.md` |
| `kw:brainstorm` | `C:\Users\rmicua\.agents\skills\compound-knowledge\kw-brainstorm\SKILL.md` |
| `kw:compound` | `C:\Users\rmicua\.agents\skills\compound-knowledge\kw-compound\SKILL.md` |
| `kw:confidence` | `C:\Users\rmicua\.agents\skills\compound-knowledge\kw-confidence\SKILL.md` |
| `kw:plan` | `C:\Users\rmicua\.agents\skills\compound-knowledge\kw-plan\SKILL.md` |
| `kw:work` | `C:\Users\rmicua\.agents\skills\compound-knowledge\kw-work\SKILL.md` |
| `miah-operator` | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\miah-operator\SKILL.md` |
| `new-project-scaffold` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-planning\new-project-scaffold\SKILL.md` |
| `nle-assistant` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-media-production\nle-assistant\SKILL.md` |
| `page-testing-memory` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-testing-quality\page-testing-memory\SKILL.md` |
| `paseo-advisor` | `C:\Users\rmicua\.agents\skills\paseo-advisor\SKILL.md` |
| `paseo-committee` | `C:\Users\rmicua\.agents\skills\paseo-committee\SKILL.md` |
| `paseo-delegate` | `C:\Users\rmicua\.agents\skills\heypogi\dev-tool-reference\paseo-delegate\SKILL.md` |
| `paseo-handoff` | `C:\Users\rmicua\.agents\skills\paseo-handoff\SKILL.md` |
| `proposal-generator` | `C:\Users\rmicua\.agents\skills\heypogi\joel-salinas\proposal-generator\SKILL.md` |
| `radio-edit` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-media-production\radio-edit\SKILL.md` |
| `release-briefing` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-writing-voice-content\release-briefing\SKILL.md` |
| `save-this-to-open-brain` | `C:\Users\rmicua\.agents\skills\heypogi\me\save-this-to-open-brain\SKILL.md` |
| `self-pr-merge` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\self-pr-merge\SKILL.md` |
| `session-operating-map` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\session-operating-map\SKILL.md` |
| `session-to-skill-extractor` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\session-to-skill-extractor\SKILL.md` |
| `sme-agent-creator` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\sme-agent-creator\SKILL.md` |
| `software-delivery-architect` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-developer-kit\software-delivery-architect\SKILL.md` |
| `stakeholder-update-email` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\stakeholder-update-email\SKILL.md` |
| `supervisor-prompt-builder` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-agent-forge\supervisor-prompt-builder\SKILL.md` |
| `ui-ux-design-strategist` | `C:\Users\rmicua\.agents\skills\heypogi\heypogi-developer-kit\ui-design-strategist\SKILL.md` |
| `update-my-writing-voice` | `C:\Users\rmicua\.agents\skills\heypogi\me\update-my-writing-voice\SKILL.md` |
| `visible-delegation` | `C:\Users\rmicua\.agents\skills\heypogi\open-skills-agent-ops\visible-delegation\SKILL.md` |
| `workflow-visualizer` | `C:\Users\rmicua\.agents\skills\heypogi\joel-salinas\workflow-visualizer\SKILL.md` |

## Caveats

- Skills loaded only through agent-definition `skills` fields or bundled commands that inject
  content without a `skill` tool call are not visible in this data; `customize-opencode` is a
  built-in and appears only because it was explicitly loaded.
- A zero-use window does not mean the skill is useless — it may be seasonal or repo-specific.
- Load counts include loads by subagents (Task agents) as well as top-level sessions.
