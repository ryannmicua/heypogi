---
name: release-briefing
description: Turn gathered release data about a new model, tool, or platform change into a publish-ready internal briefing package. Composes current-info-search, my-writing-voice, and image-gateway. Use when asking for a release briefing or handing off release research to package.
---

# Release Briefing

Turn gathered release data into a publish-ready briefing package. Speed stops costing correctness.

## Trigger Conditions

- User says "brief me on <release>" or "write up <release>"
- User hands off release research to package
- A significant release happens in the user's field

## Prerequisites

- `current-info-search` skill (for fresh research)
- `my-writing-voice` skill (for authentic writing)
- `image-gateway` skill (for thumbnail generation)

## Publishing Context

- **Venue**: Internal documentation
- **Audience**: Beginner — new to the field, concepts must be explained from scratch, no assumed prior knowledge
- **Title format**: `[Release Briefing] <Product> <Version> — <one-line significance>`

## Fixed Package Structure

### 1. Header Block
```markdown
# [Release Briefing] <Product> <Version> — <one-line significance>
**Released**: YYYY-MM-DD
**Researched**: YYYY-MM-DD
**Audience**: Internal — beginner level
**Status**: <draft / reviewed / final>
```

### 2. What Actually Changed
Facts only. No commentary. No opinion. Each line has a date and source.
```markdown
## What Changed

- <change 1> (source: <link>, confirmed <date>)
- <change 2> (source: <link>, confirmed <date>)
- <change 3> (source: <link>, confirmed <date>)
```

### 3. What This Means (In Plain Language)
Translate every change into language a beginner can follow. Assume zero prior knowledge. For each change:
```markdown
### <Change name, in plain language>

**Before this release**: <what the situation was, in simple terms>

**After this release**: <what changed, with a concrete example>

**Why it matters**: <one paragraph — what someone new to this field should understand>
```

Skip jargon. If a term is unavoidably technical, define it inline the first time.

### 4. What to Do About It
Concrete, prioritized actions. Keep it practical.
```markdown
## Action Items

| Priority | Action | Why |
|----------|--------|-----|
| 🔴 Now | <action> | <reason> |
| 🟡 This week | <action> | <reason> |
| 🟢 Later | <action> | <reason> |
```

### 5. Thumbnail Image Prompt
1-2 prompts for `image-gateway`, matched to the subject's brand colors:
```
Prompt 1 (clean header image): "..."
Prompt 2 (conceptual diagram): "..."
```

## Fact Rules

- Every factual claim carries a date and source
- Unverified claims are labeled: `[unverified]` or `[needs confirmation]`
- If research is missing or stale, stop and run `current-info-search` first
- This skill packages — it doesn't research. Missing research is a gate, not a shortcut

## Voice Integration

Write the "What This Means" section through `my-writing-voice` skill. The "What Changed" facts section stays neutral. The "Action Items" section uses the direct/instructional register.

## Verification

After writing, confirm:
1. Every factual claim has a date and source
2. The "What This Means" section contains zero unexplained jargon
3. A person with zero field knowledge could read and understand the briefing
4. Action items are concrete, not vague ("Read the changelog" is not concrete; "Test the new API endpoint at /v2/users against our auth flow" is)
