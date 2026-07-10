---
name: audience-content-system
description: Generate content for a specific publication calibrated precisely to the audience's level, in established formats. Use when planning or drafting anything for a defined publication with a known audience.
---

# Audience-Calibrated Content System

Generate content for a publication targeting a specific audience level. Every piece starts calibrated instead of needing a "make this simpler" revision pass.

## Trigger Conditions

- Planning or drafting anything for a defined publication
- User asks to "plan content" or "draft for <publication>"
- Weekly or batch content production

## Prerequisites

- `personal-voice` skill (if the publication has a named author voice)

## Setup Interview

On first use, ask:
- The publication and its audience: who they are, what they already know, what they definitely don't
- Content formats with length and structure for each
- Publishing cadence (weekly, biweekly, daily)
- 2-3 examples of pieces that landed well (what made them work)

## Audience Contract

Define once and reference for every piece:

```markdown
### Knowledge Floor (what every reader knows)
- <baseline 1>
- <baseline 2>

### Knowledge Ceiling (what readers don't know, don't assume)
- <gap 1> -- always explain this
- <gap 2> -- always explain this

### Banned Jargon (with plain-language substitutions)
| Instead of | Use |
|-----------|-----|
| <jargon 1> | <plain version> |
| <jargon 2> | <plain version> |
```

## Content Format Templates

Define a template per format:

### Format: Quick Tip / Snack
- **Length**: 200-300 words
- **Structure**: One concept, one example, one takeaway
- **Tone**: Direct, immediately useful

### Format: Concept Explainer
- **Length**: 800-1200 words
- **Structure**: What it is, why it matters, how it works, common pitfalls, one worked example
- **Tone**: Patient, builds from known to unknown

### Format: Step-by-Step Tutorial
- **Length**: 1200-2000 words
- **Structure**: Goal, prerequisites, numbered steps with code/output interspersed, troubleshooting
- **Tone**: Instructional, assumes nothing

### Format: Deep Dive / Analysis
- **Length**: 2000-4000 words
- **Structure**: Context, the problem, the approaches, tradeoffs, recommendation, implications
- **Tone**: Analytical, evidence-forward

## Batch Planning Mode

Given a theme, propose a full cycle of pieces across formats before drafting anything:

```markdown
# Content Batch: <theme>
**Week of**: YYYY-MM-DD

| Day | Format | Title | Hook |
|-----|--------|-------|------|
| Mon | Quick Tip | <title> | <one-line hook> |
| Wed | Explainer | <title> | <one-line hook> |
| Fri | Tutorial | <title> | <one-line hook> |
```

## Calibration Check

Before delivering any draft, run this check:
> "Would my least technical reader follow every step? Would my most technical reader feel patronized?"

Fix either failure before delivering.

## Verification

Plan one content batch on a user-provided theme. Draft the shortest piece from the plan. Run the calibration check.
