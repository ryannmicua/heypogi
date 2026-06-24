---
lorespec: "0.1"
id: "2026062401"
date: "2026-06-24"
source: "opencode"
topic: "Design and implementation of opencode-learn passive observation plugin for OpenCode"
tags: [opencode, plugin, learning, corrections, passive-observation, diataxis-docs, event-sourcing, sqlite]
classification:
  type: technical
  secondary_type: drafting
  domains: [opencode-architecture, plugin-development, documentation]
  value: high
trails: [opencode-extensibility, agent-learning, documentation-patterns]
---

## Session Arc

### Started
User asked whether OpenCode can observe and understand work patterns across sessions and projects.

### Pivots
- Realized OpenCode has no cross-session learning → shifted to building a passive collection plugin
- User clarified the goal is later analysis, not real-time injection → simplified to passive-only collection
- aix research surfaced Jozefiak corrections-loop pattern (Capture → Classify → Graduate) → adopted deterministic classification over LLM-based
- User expanded scope to capture communication style, preferences, skills, corrections → added 15 event types, 13 DB tables
- Decided to use Diataxis framework for documentation → structured docs into tutorials, how-to, reference, explanation
- User requested HTML with diagrams → created SVG architecture/flow/decision-tree diagrams

### Ended
Plugin designed, coded, documented with 4 Diataxis types + HTML diagrams, committed and pushed to main.

## ARTIFACT

### A1: opencode-learn plugin source
- **Location**: `src/plugins/opencode-learn/src/`
- **Files**: `index.ts`, `db.ts`, `corrections.ts`, `analyze.ts`
- **Summary**: Passive OpenCode plugin (V1 interface) that listens to EventV2 events via the `event` hook, classifies user corrections with deterministic regex, stores everything in a central SQLite DB, and provides a CLI analysis tool for promoting recurring corrections to rules.
- **Event types captured**: 14 EventV2 types spanning prompts, responses, compactions, tool calls, steps, shell commands, agent/model switches, permissions, retries
- **DB tables**: 13 (`project`, `user_prompt`, `assistant_response`, `session_summary`, `tool_call`, `file_change`, `step`, `shell_command`, `agent_switch`, `model_switch`, `retry`, `permission`, `correction`, `preference`, `proposed_rule`)

### A2: opencode-learn documentation (Diataxis)
- **Location**: `src/plugins/opencode-learn/docs/`
- **Structure**:
  - `tutorials/getting-started.md` — 15-minute first-run guide
  - `how-to/install.md` — permanent installation
  - `how-to/analyze-data.md` — SQL queries for pattern analysis
  - `how-to/promote-corrections.md` — correction-to-rule pipeline
  - `reference/db-schema.md` — all 13 tables, columns, indexes
  - `reference/event-reference.md` — 14 events → tables mapping
  - `explanation/architecture.md` — system design, data flow, limitations
  - `explanation/design-decisions.md` — why passive, why regex, why central DB
  - `index.html` — visual HTML with 4 SVG diagrams

### A3: Install scripts
- **Location**: `src/plugins/opencode-learn/install/`
- **Files**: `install.ps1` (auto-detects plugin directory, adds to global opencode.json), `README.md`
- Also: `install/install-opencode-learn.md` (repo root reference), `docs/plugins/opencode-learn.md` (pointer)

## DECISION

### D1: Passive observation over context injection
- **Decision**: The plugin collects data passively without injecting context back into agent prompts
- **Issue**: Should the plugin also inject learned patterns into the agent's system prompt?
- **Positions**: Inject for real-time benefit vs. keep purely observational
- **Arguments**: Injection wastes tokens on possibly irrelevant context, risks stale data, and the user confirmed "main purpose is later analysis"
- **Warrant**: Analysis is more valuable than real-time adaptation for this use case
- **Qualifier**: settled
- **Status**: settled

### D2: Deterministic regex classifier over LLM-based classification
- **Decision**: User corrections are classified with regex patterns, not LLM calls
- **Issue**: How to classify detected corrections into meaningful categories?
- **Positions**: LLM-based classification (flexible) vs. regex-based (deterministic)
- **Arguments**: Nakajima: "LLM giving you confident wrong lessons." Jozefiak: "deterministic first, unknown path for unclassifiable." Regex is cheap, auditable, zero-cost.
- **Warrant**: False positives are more harmful than false negatives in a learning system
- **Qualifier**: always
- **Status**: settled

### D3: Corrections graduate to rules only after recurring (freq ≥ 2)
- **Decision**: Corrections become proposed rules only when the same pattern appears 2+ times
- **Issue**: When does a single correction become a rule?
- **Positions**: Every correction is a rule vs. only recurring patterns
- **Arguments**: One-off corrections are noise. Recurring patterns indicate genuine preference/constraint. Jozefiak pattern: "a correction never expires unaddressed" but graduation requires repetition.
- **Warrant**: Prevents noise from becoming persistent behavior changes
- **Qualifier**: always
- **Status**: settled

### D4: Central SQLite DB over per-project storage
- **Decision**: All projects share one SQLite DB at `~/.local/share/opencode-learn/learn.db`
- **Issue**: Should each project store its own data?
- **Positions**: Per-project (matches OpenCode's own pattern) vs. central (cross-project analysis)
- **Arguments**: Central enables cross-project pattern recognition. Single point of failure but simpler than merging per-project DBs. User wanted cross-project understanding.
- **Warrant**: Cross-project analysis is the primary value
- **Qualifier**: in this case
- **Status**: settled

### D5: Batch writes with 2-second interval
- **Decision**: Events are buffered and flushed every 2 seconds in a single SQLite transaction
- **Issue**: How to handle high-frequency event writes?
- **Positions**: Write-through (each event writes immediately) vs. batch
- **Arguments**: A busy session could generate hundreds of events per minute. Batching reduces SQLite write overhead by orders of magnitude. On dispose, buffer is flushed immediately.
- **Warrant**: Performance matters even for a background collector
- **Qualifier**: always
- **Status**: settled

### D6: Diataxis framework for documentation
- **Decision**: Plugin documentation follows the Diataxis four-type framework
- **Issue**: How to structure plugin docs for both humans and agents?
- **Positions**: Single README vs. structured docs vs. Diataxis
- **Arguments**: Diataxis separates concerns by user need (study/do, action/cognition). Tutorials for beginners, how-to for task-doers, reference for lookups, explanation for understanding.
- **Warrant**: Different readers need different documentation types
- **Qualifier**: always
- **Status**: settled

## INSIGHT

### I1: OpenCode has no cross-session learning capability
- **Source**: Source code analysis of OpenCode's EventV2, session store, plugin system
- **Insight**: OpenCode is purely session-scoped. No cross-session memory, user profiling, or behavior observation exists. The only persistent state is the model reasoning-effort preference.
- **Confidence**: high

### I2: EventV2 events that can be used for observation
- **Source**: Analysis of `packages/core/src/session/event.ts` and `packages/opencode/src/permission/index.ts`
- **Insight**: 14 EventV2 event types (prompts, compactions, tool calls, steps, shells, agent/model switches, permissions, retries) flow through `EventV2Bridge` and reach the plugin `event` hook, enabling passive observation of nearly all user-agent interactions.
- **Confidence**: high

### I3: Skills are not observable via events
- **Source**: Analysis of OpenCode skill loading (skills are injected as system prompt text)
- **Insight**: There is no `skill.activated` event. Skills are loaded as text into the system prompt when their trigger conditions match. Detecting skill usage requires analyzing prompt text for trigger keywords at query time.
- **Confidence**: high

### I4: Jozefiak corrections-loop pattern
- **Source**: aix research of AI Lab wiki
- **Insight**: The Capture → Classify → Graduate pipeline provides a proven pattern: cheap deterministic capture, regex classification (not LLM), memory sinks for different kinds, repetition detection before graduation, human review surface. This was the direct inspiration for the correction detector design.
- **Confidence**: high

### I5: Nakajima's warning against self-grading
- **Source**: aix research of AI Lab wiki, Nakajima's NeurIPS 2025 synthesis
- **Insight**: Using an LLM to classify corrections or reflect on its own behavior creates a "failure mode" where the model "hallucinates bad reflections and reinforces them confidently." This directly motivated the decision to use deterministic regex-only classification.
- **Confidence**: high

## PATTERN

### P1: Passive correction detection with state machine
- **Scope**: local (opencode-learn plugin)
- **Steps**:
  1. Track last assistant response per session (in-memory Map)
  2. On user prompt: check if prior assistant response exists
  3. If yes: test SIGNAL_PATTERNS (negation words)
  4. If match: test CLASSIFICATION RULES (deterministic regex)
  5. If match: store as correction, consume context (prevent double-fire)
  6. If no correction: test PREFERENCE_SIGNALS (unprompted preference)
- **Why it works**: Three-gate design (prior response → signal → classification) eliminates false positives. Context consumption prevents double-counting. Preference fallback captures non-correction preferences.

### P2: Correction-to-rule graduation pipeline
- **Scope**: local (opencode-learn analyzer)
- **Steps**:
  1. Load unresolved corrections from DB
  2. Cluster by classification kind + normalized text
  3. Count frequency per cluster
  4. Gate: freq ≥ 2 → graduate candidate; freq < 2 → log as single
  5. Write graduates to `proposed_rule` table with evidence JSON
  6. Human reviews: approve, reject, or modify
  7. Approved rules: manually apply to AGENTS.md or opencode.json
- **Why it works**: Frequency gate prevents noise from becoming rules. Human review ensures no automatic behavior changes. Evidence trail enables auditing.

## OPEN_QUESTION

### Q1: How to detect skill usage?
- **Context**: Skills are injected as system prompt text, not events. No event fires when a skill activates.
- **Partial progress**: Could analyze prompt text for skill trigger keywords, or read system context snapshots from `Step.Started.snapshot` field.
- **Blocks**: Comprehensive understanding of which skills the user activates most.

### Q2: How to capture session boundaries?
- **Context**: `session.created`/`session.deleted` are V1 events not bridged to EventV2.
- **Partial progress**: Could poll OpenCode's own SQLite DB for the `session` table.
- **Blocks**: Session duration and frequency analysis.

### Q3: How to detect undo/redo usage?
- **Context**: No event fires for `/undo` or `/redo` commands.
- **Partial progress**: Could detect `git checkout`/`git restore` in shell commands as a weak signal.
- **Blocks**: Understanding when the user is dissatisfied with changes.

## NEXT_STEP

### N1: Install opencode-learn on local machine
- **Urgency**: now
- **What**: Run `./src/plugins/opencode-learn/install/install.ps1` to register the plugin in global opencode.json
- **Prompted by**: Session goal to build and deploy the plugin

### N2: Verify data collection after install
- **Urgency**: soon
- **What**: After restarting OpenCode and running several prompts, check `~/.local/share/opencode-learn/learn.db` for populated tables
- **Prompted by**: Need to confirm the plugin works end-to-end

### N3: Run initial analysis after sufficient data
- **Urgency**: someday
- **What**: Run `bun src/analyze.ts` from the plugin directory to see correction patterns
- **Prompted by**: Analysis tool is built but needs data to process

## Connections
- D1 —[informed_by]→ I1 (no cross-session memory → passive approach)
- D2 —[informed_by]→ I4, I5 (Jozefiak + Nakajima → deterministic regex)
- D3 —[instance_of]→ P2 (graduation pipeline pattern)
- D4 —[depends_on]→ I1 (central DB addresses no cross-session memory)
- D5 —[instance_of]→ P1 (batch writes part of collection pattern)
- D6 —[led_to]→ A2 (Diataxis decision → structured docs)
- I2 —[informed_by]→ A1 (event analysis → plugin code)
- Q1 —[related_to]→ I3 (skills not observable)
- N1 —[depends_on]→ A1, A3 (need plugin + install script)
