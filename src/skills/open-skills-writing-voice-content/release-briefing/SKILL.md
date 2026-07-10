---
name: release-briefing
description: Turn gathered release data about a new model, tool, or platform change into a publish-ready briefing package with consistent format. Composes current-info-search, personal-voice, and image-gateway. Use when asking for a release briefing or handing off release research to package.
---

# New Release Briefing

Turn gathered release data into a publish-ready briefing package with a consistent format readers learn to expect. Speed stops costing correctness.

## Trigger Conditions

- User says "brief me on <release>" or "write up <release>"
- User hands off release research to package
- A significant release happens in the user's field

## Prerequisites

- `current-info-search` skill (for fresh research)
- `personal-voice` skill (for authentic writing)
- `image-gateway` skill (for thumbnail generation)

## Setup Interview

On first use, ask:
- Where the user publishes (newsletter, blog, internal doc)
- Audience sophistication level (beginner, practitioner, expert)
- Title/format conventions if they exist

## Fixed Package Structure

### 1. Title and Subtitle
```
<Standardized title pattern>
<One-line subtitle explaining significance>
```

### 2. What Actually Changed
Facts with dates and primary sources. No commentary yet.
```
- <change 1> (source: <link>, confirmed <date>)
- <change 2> (source: <link>, confirmed <date>)
```

### 3. Why It Matters (For This Audience)
Calibrated to audience sophistication:
- **Beginner audience**: "This means you can now..." with concrete examples
- **Practitioner audience**: "Compared to the previous approach..." with tradeoffs
- **Expert audience**: "The architectural implications are..." with technical depth

### 4. What to Do About It
Concrete actions, prioritized:
```
1. <immediate action if any> (urgency: <high/medium/low>)
2. <monitor-and-wait item>
3. <longer-term consideration>
```

### 5. Thumbnail Image Prompts
2-3 prompts for `image-gateway`, matched to the subject's brand colors:
```
Prompt 1 (clean hero): "..."
Prompt 2 (diagrammatic): "..."
Prompt 3 (conceptual): "..."
```

## Fact Rules

- Every factual claim carries a date and source
- Unverified claims are labeled: `[unverified]` or `[needs confirmation]`
- If research is missing or stale, stop and run `current-info-search` first
- This skill packages -- it doesn't research. Missing research is a gate, not a shortcut

## Voice Integration

If `personal-voice` skill is available, write the analysis and commentary sections through it. The facts section stays neutral.

## Verification

Brief the most recent significant release in the user's field. Confirm every claim has a date and source.
