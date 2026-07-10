---
name: meeting-synthesis
description: Turn a meeting transcript or recording into a structured synthesis -- takeaways, decisions, action items, open questions, and durable context. Use when given a meeting transcript, recording, or asked "what happened in this meeting?"
---

# Meeting Synthesis

Turn meeting recordings or transcripts into a structured synthesis you can act on. The fixed format plugs directly into your task system instead of becoming another unread document.

## Trigger Conditions

- User provides a meeting transcript or recording
- User asks "what happened in this meeting?"
- User needs notes synthesized from a conversation

## Output Structure

Every synthesis follows this fixed format:

```markdown
# Meeting Synthesis: <topic/date>

## Key Takeaways
- <takeaway 1>
- <takeaway 2>

## Decisions Made
| Decision | Made By | Rationale |
|----------|---------|-----------|
| <what was decided> | <who> | <why, if stated> |

## Action Items
| Action | Owner | Deadline |
|--------|-------|----------|
| <concrete action> | <name/role> | <date if stated, otherwise "not set"> |

## Open Questions
- <question 1>
- <question 2>

## Durable Context
- <anything worth keeping beyond this meeting -- background, constraints, references>
```

## Said vs. Inferred

A hard rule: separate what was actually said from what the agent inferred.

- **Said**: "We'll launch on March 15th" -- Decision to launch March 15th
- **Inferred**: The timeline seems tight given the remaining work -- mark as `[Inferred]`

Inferences get marked with `[Inferred]` or placed in a separate section. The synthesis must stay trustworthy -- the reader must know which statements came from the room and which came from the model.

## Exact Quotes

Preserve exact quotes for anything contentious or commitment-shaped:
```
> "I will personally handle the client escalation by Friday." -- Jane
```

## Multi-Topic Meetings

Synthesize per topic, not chronologically. If a meeting covers three topics, produce three mini-syntheses or clearly sectioned topics within one document. Do not produce a timeline transcript disguised as synthesis.

## Setup Interview

On first use, ask:
- Where syntheses should be saved
- Whether action items should also go somewhere specific (task tool, file, email)

Default destination: `docs/meetings/<YYYY-MM-DD>-<topic>.md`

## Verification

Run on a real transcript. Confirm:
- Decisions have decision-makers named
- Action items have owners where stated
- Inferences are marked
- The synthesis is shorter than the transcript
