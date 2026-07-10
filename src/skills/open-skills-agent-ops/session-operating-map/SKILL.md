---
name: session-operating-map
description: Set up and maintain a repo-local operating map for projects with multiple parallel agent sessions — which lane owns what, current state, blockers, and decisions. Use when starting parallel workstreams, asking "what's in flight?", or setting up coordination for a repo.
---

# Session Operating Map

Set up and maintain a repo-local operating map for projects where multiple agent sessions run in parallel. Externalize coordination so any session (or any future you) can read what's in flight, what's blocked, and what's been decided.

## Trigger Conditions

- User starts parallel workstreams in a project
- User asks "what's in flight?"
- User asks to set up coordination for a repo
- More than two concurrent sessions are active on the same project

## Map File

Create or maintain a single repo-local document at `docs/operating-map.md`. Structure:

```markdown
# Operating Map

## Active Lanes

| Lane | Objective | Session | State | Blockers |
|------|-----------|---------|-------|----------|
| add-auth | Implement OAuth2 login flow | Claude tab 3 | in_progress | Waiting on API key from team |
| fix-nav | Fix mobile nav overflow bug | Claude tab 5 | blocked | Needs design mockup |
| refactor-db | Extract DB layer to its own module | OpenCode session | in_progress | — |

## Done

| Lane | Outcome |
|------|---------|
| upgrade-deps | All deps updated to latest, tests pass |

## Promoted Learnings

- Pattern "error handling wrapper" → extracted to `docs/solutions/error-handling.md`
- Decision "chose SQLite over Postgres for local dev" → recorded in `docs/decisions/`
```

## Lane Discipline

- One lane per concern — if a lane starts covering two unrelated things, split it
- Name lanes so purpose is obvious at a glance: verb-noun format (`add-auth`, `fix-nav`, `refactor-db`)
- Each lane has an owning session identifier (tab name, CLI instance, or thread ID)

## Update Rules

A lane's entry gets updated when its state meaningfully changes:
- **Start**: lane added, state set to `in_progress`
- **Block**: state set to `blocked`, blocker described
- **Handoff**: ownership transferred, new session noted
- **Done**: lane moved to Done section

Updates are state changes, not journals. Do not record incremental progress — just the current status.

## Archive Rules

- Finished lanes move to the Done section with a one-line outcome
- Lessons worth keeping beyond this lane get promoted into the project's docs or skills:
  - Reusable patterns → `docs/solutions/` or new/updated skills
  - Architectural decisions → `docs/decisions/`
  - Domain knowledge → `docs/glossary.md` or CONCEPTS.md
- Do not let valuable knowledge die with a closed lane

## Read-First Rule

Any session joining the project must read the operating map before starting work. Announce this when opening a project with an active map.
