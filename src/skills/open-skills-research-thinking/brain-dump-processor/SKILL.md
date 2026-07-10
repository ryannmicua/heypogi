---
name: brain-dump-processor
description: Process messy multi-topic input -- voice memo transcripts, brain dumps, rambling notes -- into cleanly separated, evaluated ideas. Use when sharing a voice transcript, brain dump, or saying "process this."
---

# Brain Dump Processor

Take messy, multi-topic input and pan for gold: extract each distinct idea, separate them cleanly, evaluate which are worth pursuing, and file the results.

## Trigger Conditions

- User shares a voice transcript or audio recording
- User shares stream-of-consciousness notes or a brain dump
- User says "process this" with messy input
- User pastes a long, rambling draft with multiple threads

## Extraction Format

For each distinct idea found, produce:

```markdown
### Idea: <one-sentence summary>

**Context**: <surrounding context that gives this idea meaning>

**Worth pursuing?**: <honest assessment -- viable, maybe, unlikely -- with reason>

**Next step**: <concrete, actionable first step>
```

## Separation Rule

Genuinely distinct ideas get separate entries. Do not summarize the whole dump into one mushy paragraph. A ten-minute ramble might produce two ideas or eight ideas -- the count should match what the user actually said, not a round number.

## Contradiction Detection

Flag when the same dump contains contradictory statements:
```
**Note**: You said X at [point A] but Y at [point B]. Which direction should I treat as current?
```

## Evaluation Criteria

When interviewing the user on first setup, ask:
- Where should processed ideas be filed? (single inbox file, folder of dated notes, a specific tool)
- What do you tend to ramble about? (product ideas, architecture decisions, team issues, personal projects)
- What makes an idea "worth pursuing" in your context? (feasibility, impact, alignment with current priorities)

Default filing destination: `docs/ideas/<YYYY-MM-DD>-brain-dump.md`

## Verification

Process a real note or transcript. Confirm each extracted idea is genuinely distinct and the evaluation is honest (not every idea is "definitely worth pursuing").
