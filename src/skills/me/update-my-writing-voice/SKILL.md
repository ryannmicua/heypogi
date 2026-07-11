---
name: update-my-writing-voice
description: Analyze a new writing sample from the user and incorporate discovered voice patterns into the my-writing-voice skill. Use when the user shares a piece of their writing and asks to update their voice skill.
---

# Update My Writing Voice

Take a new writing sample, analyze it for voice patterns, present findings for review, and apply approved updates to the `my-writing-voice` skill.

## Trigger Conditions

- User shares a piece of their own writing and says "add this to my voice" or "incorporate this into my writing voice"
- User says "analyze this message and update my-writing-voice"
- User provides a document they wrote and wants voice patterns extracted

## Step 1: Read the Sample

Read the sample carefully. Note:
- The context (when written, to whom, why)
- The format (email, report, proposal, cover letter, message, post)
- The relationship between writer and recipient

## Step 2: Analyze and Present for Review

Present these four categories to the user before making any changes:

### 1. Distinct Registers Observed

Identify any register not already covered by the existing `my-writing-voice` skill. Compare against the current audience calibrations:
- Senior leaders
- Formal applications and self-advocacy
- Staff and direct reports
- Close colleagues
- Vendors and external operational contacts

If the sample represents a new register, propose it with:
- A name (e.g. "Incident investigation reports")
- When it applies
- What distinguishes it from existing registers

If it overlaps an existing register, note where it extends or refines.

### 2. Sentence-Level Patterns

Extract concrete, reusable patterns from the sample:
- Opening phrases
- Transition phrases
- Closing patterns
- Structural conventions (metadata blocks, chronological ordering, numbered sequences)
- Formatting habits (bullet usage, tables, section headers)

Present each pattern as a quoted fragment from the user's actual writing, with the pattern generalized into a template.

### 3. Anti-Patterns

From the sample, identify what the user **does not** do:
- Words they never use
- Openers they never write
- Constructions absent from their writing
- Tone they avoid

Also flag any AI-prose tells that would read as inauthentic if inserted into this register.

### 4. Rules for When to Use This Register

Define the trigger conditions:
- What situation calls for this register
- What relationship or formality level is expected
- What the reader needs from this kind of writing
- How this register differs from the closest existing register

## Step 3: Get User Approval

Present the analysis as a review summary:

```markdown
## Voice Analysis: <sample description>

### New Register Proposed: <register name>
(Or "Extends existing register: <name>")

### Patterns Found
| # | Pattern | From Your Writing | Template |
|---|---------|-------------------|----------|
| 1 | <description> | "<exact quote>" | `<template>` |

### Anti-Patterns Confirmed
- <pattern> — not present in this sample

### Register Rules
- Use when: <situation>
- Don't use when: <situation>
```

Ask the user to confirm before making any changes to the skill.

## Step 4: Apply Updates

Once approved, update `src/skills/me/my-writing-voice/SKILL.md`:

1. **New register** → Add to the "Audience calibration" section with:
   - When to use it
   - Preferred patterns (from the analysis)
   - Transition phrases
   - Behavior rules

2. **New content pattern** → Add to "Common content patterns" with the full template

3. **New language preferences** → Add to "Language preferences" in the Prefer list

4. **Existing register refinements** → Update the relevant audience section with new patterns or behavior notes

Preserve all existing content. Add, don't replace. The voice skill should accumulate over time.

## Rules

- Always present analysis before editing. Never modify the voice skill without user review.
- Extract patterns from what the user actually wrote. Don't invent patterns the user didn't use.
- Generalize specifics into templates: names → `[Name]`, dates → `[YYYY-MM-DD]`, locations → `[location]`, identifiers → `[relevant identifier]`.
- If the sample contradicts an existing pattern, flag it and ask which should take precedence.
- If the sample is too short or homogeneous to extract reliable patterns, say so rather than overfitting.
