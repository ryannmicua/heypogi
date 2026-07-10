---
name: session-to-skill-extractor
description: At the end of substantial work sessions, evaluate whether anything done is worth preserving as a new skill or update to an existing one. Use when wrapping up, or when asked "anything worth keeping?".
---

# Session-to-Skill Extractor

A continuous-learning loop for the skill library: at the end of substantial work sessions, review what happened and evaluate whether any pattern is worth preserving as a new skill or an update to an existing one.

## Trigger Conditions

- User says "wrap up"
- User asks "anything worth keeping?"
- Natural end of a session where something non-trivial was solved
- A workflow was repeated that could be codified

## Extraction Bar

The pattern must clear all three criteria. Most sessions yield nothing — "nothing worth extracting" is a good and honest answer.

| Criterion | Meaning |
|-----------|---------|
| **RECURRING** | I'll plausibly need this again. One-off debugging of a specific API quirk doesn't count; a pattern for debugging API quirks generally might. |
| **NON-OBVIOUS** | A fresh session wouldn't just derive this. "Run the tests before committing" is obvious. "This library's error codes are in the response body, not headers, and the retry pattern is..." is not. |
| **CODIFIABLE** | It can be written as a procedure with trigger conditions, steps, and output. Vague principles ("be more careful with types") don't qualify. |

## Check Existing Library First

Before proposing a new skill, scan the existing skill library. If an existing skill covers 80% or more of the pattern, propose an **update** to that skill, not a new one. Avoid fragmentation.

## Draft Format

Drafts must follow the project's standard skill format:
- YAML frontmatter with `name` and `description`
- Trigger conditions (when to use it)
- Step-by-step procedure
- Output format if applicable

## Delivery

- Drafts land in a review location, never silently into the live library
- Suggested location: `src/skills/_proposals/<skill-name>.md` or similar review queue
- The user must explicitly approve before a draft becomes a live skill

## Sanitize Rule

Extracted skills generalize the pattern and strip project/client specifics:
- Replace "the Acme Corp auth service" with "the authentication service"
- Replace "Jane's Slack channel" with "the team communication channel"
- Keep project-specific details in repo-local runbooks, not skills

## Final Check

After evaluating a session, always state the reasoning explicitly:
- Which patterns were considered
- How they scored against the three criteria
- Which (if any) were proposed and why
