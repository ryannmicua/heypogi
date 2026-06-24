# Design Decisions

## Why Not Inject Context Back Into the Agent Prompt?

The original design considered injecting learned patterns into the agent's system prompt at session start. This was discarded because:

- **Token waste**: Injected context competes with the actual task for context window
- **Relevance guessing**: Heuristics for "what context is relevant now" are unreliable
- **Stale data risk**: Old patterns might no longer apply
- **Jozefiak's rule**: Corrections graduate to rules only after recurring — injecting before graduation would amplify noise

Instead, the system is purely observational. Analysis is done offline, and rule promotion requires human review.

## Why the Jozefiak Pipeline?

Pawel Jozefiak's corrections-loop pattern (Capture → Classify → Graduate) was chosen over alternatives because:

**Alternative: LLM-based classification**
- Nakajima's NeurIPS 2025 synthesis: "The model hallucinating bad reflections and reinforcing them is the failure mode for any self-improving loop"
- LLM calls add cost and latency for what should be a deterministic operation
- Harder to audit and debug

**Alternative: Human-tagged corrections**
- Requires explicit user action — violates the "minimal to no action" requirement
- Scales poorly

**Alternative: Full conversation storage with no classification**
- Analysis phase would need to reprocess all text, which is expensive
- No structured data for quick queries

The Jozefiak pattern provides the right balance: cheap deterministic capture, structured storage for fast queries, and a graduation gate that prevents noise from becoming rules.

## Why Five Classification Kinds?

The classification kinds (skill_misuse, memory_update, behavioral, rule, preference) map to distinct outcomes:

| Kind | What happens when it graduates |
|------|-------------------------------|
| `skill_misuse` | Update tool preferences or command patterns |
| `memory_update` | Update project-specific context in AGENTS.md |
| `behavioral` | Add communication style instructions |
| `rule` | Add hard constraints to permissions or agent prompts |
| `preference` | Add softer guidance to agent instructions |

This mapping ensures that every correction has a clear promotion path. The `unknown` path (items that don't match any pattern) ensures we don't miscategorize — they're silently skipped rather than forced into a wrong bucket.

## Why Batch Writes?

Each event triggers a DB write. Without batching, a busy session (tool calls, steps, shell commands) could generate hundreds of individual SQLite writes per minute. The plugin:

1. Collects writes into an in-memory buffer
2. Flushes every 2 seconds
3. Wraps all buffered writes in a single `BEGIN/COMMIT` transaction

This reduces write overhead by orders of magnitude while maintaining durability. On plugin dispose (session end), the buffer is flushed immediately.

## Why a Central DB Instead of Per-Project?

OpenCode stores session data in project-local SQLite databases. Cross-project analysis would require:

- Opening and reading multiple databases
- Merging schema-aware results
- Handling database conflicts (different OpenCode versions, corrupted DBs)

A central DB at the user level avoids this complexity. Every project's events flow into the same database, tagged by `project_id`. Queries can filter by project or aggregate across them.

The trade-off: the central DB is a single point of data. If it's corrupted, all history is lost. For production use, add periodic backups:

```bash
cp ~/.local/share/opencode-learn/learn.db ~/backups/opencode-learn-$(date +%Y%m%d).db
```

## Why Not Capture Everything?

Not every EventV2 event is captured. Some are redundant (streaming deltas when the ended event has the full value), some are infrastructure (plugin lifecycle), and some are internal model state (reasoning tokens).

The guiding principle: capture what reveals user patterns. Internal LLM reasoning is not user behavior. System context updates are OpenCode internals, not user preferences. Keeping the schema focused on user-facing events makes analysis queries simpler and storage leaner.

## Why No Skills Tracking?

Skills are loaded as text injected into the system prompt, not as events. There is no `skill.activated` event in EventV2. Detecting skill usage would require:

- Analyzing the system context for skill trigger patterns
- Matching user prompt keywords against known skill triggers
- Maintaining a registry of installed skills and their triggers

This is feasible for a future enhancement but adds complexity that doesn't exist for event-based capture. Current workaround: analyze `user_prompt.text` for skill-triggering keywords at query time.

## Why a Separate Analysis Tool Instead of In-Plugin?

Analysis (clustering corrections, proposing rules) is intentionally a separate CLI tool, not part of the plugin itself:

- **Resource isolation**: Analysis doesn't compete with OpenCode for memory or CPU
- **On-demand**: Run when you want to review, not on every session start
- **Iterative**: Analysis logic evolves independently of collection
- **Auditable**: Each analysis run is a one-shot computation, not a background process

The plugin does one thing: collect. The analysis tool does one thing: analyze. This separation keeps both simple.
