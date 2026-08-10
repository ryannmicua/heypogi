---
name: atlas-lookup
description: Look up knowledge from the Atlas repository, the Director's personal knowledgebase and memory system. Use when answering questions about what the Director knows, has learned, read, decided, or captured — from any project, not just inside the Atlas repo. Covers AI/LLM concepts (ai_lab), IT operations (itops), ITS department work (work_its), IT director topics (it_director), personal HQ architecture (hq), documentation style (documentation_style_guide), general work (work_general), and repo-wide plans, specs, and backlogs (docs/). Triggers: "look up in atlas", "what do I know about", "check the knowledgebase", "atlas recall", "does the director know", "find in the wiki", "what have I learned/captured/read about X". Read-only. Do NOT use for adding, ingesting, or updating knowledgebase content (use wiki-ingest), AI-Lab-only stewarding (use aix), or repo coherence/maintenance (use clippy).
---

# Atlas Lookup

## Overview

Atlas is the Director's personal operating system: a git repository of learning, work, and leadership knowledge. This skill retrieves that knowledge from any working directory. It is read-only — it searches, reads, and cites; it never creates or edits Atlas files.

`{atlas-root}` resolves to the Atlas repository root: `C:\Users\rmicua\myrepo\atlas`.

This skill is deployed in two identical copies: the canonical source in the Atlas repo (`.agents/skills/atlas-lookup/`) and the global instance (`~/.agents/skills/heypogi/atlas-lookup/`) that makes it discoverable in every project. Keep them in sync.

## Space Map

Route the question to a space using the root `AGENTS.md` routing table:

| Space | Holds | Look here when the question is about ... |
| --- | --- | --- |
| `spaces/ai_lab` | AI/LLM learning knowledgebase (research-first) | AI concepts, agents, prompts, frameworks, LLM tools, experiments |
| `spaces/itops` | IT operations learning knowledgebase (technical) | Infrastructure, virtualization, networking, storage, security, sysadmin |
| `spaces/work_its` | ITS department operations (ops-first) | ITS projects, decisions, risks, services, vendors, people, team, leadership |
| `spaces/it_director` | IT Director role reference | IT governance, IT strategy, director-level playbooks |
| `spaces/hq` | Personal HQ architecture and operating model | The personal HQ system, its boundaries, assistant routines, design decisions |
| `spaces/documentation_style_guide` | Canonical documentation style system | Doc style guides, templates, doc governance |
| `spaces/work_general` | General work not tied to a domain | Work that fits no more specific space |

Other Atlas locations:

- `intake/` — new material not yet routed to a space (search when recent material may not be processed yet)
- `docs/` — repo-wide planning, specs, tasks, backlogs, how-tos, RAID, routing tables
- `system_instructions/` — operating guidance and governance
- `agent_registry/` — agent roles, charters, and logging conventions

## Lookup Workflow

1. **Classify.** Map the question to one or more spaces using the table above. Cross-domain questions search all relevant spaces. If unsure, check `intake/` too — the answer may be in unprocessed material.
2. **Find the space's index.** Locate the master catalog — usually `spaces/<space>/wiki/index.md` (or `wiki/README.md`, `wiki/toc.md`). Read the space's `purpose.md` / `schema.md` / `AGENTS.md` only as needed to find the index and understand page types. Each space has its own structure; do not assume a uniform layout beyond `raw/` and `wiki/`.
3. **Search wiki first (durable synthesis).** Grep `spaces/<space>/wiki/` for the topic's key terms; read the most relevant pages. The wiki is the trustworthy synthesis — answer from it whenever it has material.
4. **Fall back to raw (source recall).** When the wiki is thin, grep `spaces/<space>/raw/`. Raw holds immutable source material and source notes that may contain specifics not yet synthesized. Cite what the raw source says as a source claim, not settled knowledge.
5. **Check repo-wide locations.** For questions about plans, specs, backlogs, instructions, or routing, search `docs/` and `system_instructions/` directly (e.g., `docs/routing/sharepoint-locations.md`, `docs/routing/workspace-folders.md`, `docs/raid/ACTIVE.md`, `docs/backlog/`).
6. **Check glossary and overview.** For people, projects, vendors, systems, or terminology, check `spaces/<space>/wiki/glossary.md` (or the space's term file) and the space's overview/current-state page.
7. **Optional: Open Brain.** When the topic is recent, personal, or lightly covered in Atlas, also search Open Brain via the `openbrain_search_thoughts` MCP tool if available.

## Answer Format

Answer the question directly from what you found, then cite:

- **Found in wiki** — durable knowledge. Cite `spaces/<space>/wiki/<page>.md:line`.
- **Found only in raw** — source claim. Cite the raw file and note it is unsynthesized source material.
- **Not found** — say so plainly: "Not found in Atlas." Propose next steps: search `intake/`, suggest an external search, or offer to route the material via wiki-ingest.

Always list which pages/files you consulted, so the Director can verify or go deeper. Keep the answer concise; Atlas pages are dense.

## Rules

- **Read-only.** Never create, edit, or delete files in the Atlas repository. Writes belong to the wiki-ingest skill.
- **Respect space governance.** Follow each space's `purpose.md` / `schema.md` / `AGENTS.md` rules for how material is organized and named. Never invent structure.
- **Raw may be ahead of wiki.** Do not assume the wiki is complete; if the wiki has nothing recent, raw or `intake/` may hold the answer.
- **Prefer the most specific space.** When a topic fits several spaces, search the most specific one first, then widen.
- **Do not route into a space.** If material would be new to Atlas, flag it rather than deciding a space for it — leave that to wiki-ingest and the intake flow.
- **Treat uncommitted Atlas changes as intentional Director work** unless they directly block the lookup.
