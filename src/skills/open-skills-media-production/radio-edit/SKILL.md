---
name: radio-edit
description: Produce a transcript-driven rough cut of talking-head footage -- fix the spoken flow first, before any visual work. Depends on media-transcription for word-level timestamps. Use when asking for a rough cut, paper edit, or cleaned-up edit.
---

# Radio Edit

Create a transcript-driven "radio edit" -- a rough cut where the spoken narrative is fixed before any visuals are touched. Going from raw recording to a cuts-placed timeline without scrubbing footage by hand.

## Trigger Conditions

- User asks for a rough cut, paper edit, or cleaned-up edit of a recording
- User provides talking-head footage and wants the narrative tightened
- User says "clean this up" or "make a radio edit"

## Prerequisites

- `media-transcription` skill (word-level timestamps are essential)
- NLE that imports FCXML or EDL (DaVinci Resolve, Premiere, Final Cut)

## Setup Interview

On first use, ask:
- Which editing software (determines timeline format: FCXML or EDL)
- How aggressive cuts should be by default (tight vs. conversational)
- Anything that must always be cut (profanity, specific phrases, names, filler words)

## Edit-Decision Rules

Detect and handle:

| Pattern | Action |
|---------|--------|
| **False starts** | Cut the fragment, keep the completed sentence |
| **Repeated takes** | Keep the best (clearest, most natural), note alternatives in paper edit |
| **Filler words** | Cut "um," "uh," "you know," "like," "I mean" unless they carry meaning |
| **Dead air** | Cut silence longer than 1.5 seconds unless it's a deliberate pause |
| **Tangents** | Cut digressions that don't advance the main thread; flag for user review |
| **Overlaps** | Note overlaps in paper edit; don't auto-cut unless clearly redundant |
| **Flubbed lines** | Cut clearly misread or stumbled lines; keep the intact take |

## Paper Edit (Deliver BEFORE Timeline)

Every cut listed with timecodes, what was removed, and why:

```markdown
# Paper Edit: <project-name>
**Source duration**: 45:32
**Estimated cut duration**: 28:15
**Cuts**: 47 total (23 filler, 8 false starts, 6 repeated takes, 5 dead air, 5 tangents)

## Keep Segments
| # | In | Out | Duration | Content |
|---|-----|-----|----------|---------|
| 1 | 00:00:00.000 | 00:01:23.500 | 1:23 | Introduction |
| 2 | 00:01:28.200 | 00:03:45.100 | 2:17 | Background context |

## Cuts
| # | In | Out | Duration | Type | Content | Reason |
|---|-----|-----|----------|------|---------|--------|
| 1 | 00:01:23.500 | 00:01:28.200 | 0:05 | dead_air | (silence) | 4.7s pause after intro |
| 2 | 00:03:45.100 | 00:04:02.300 | 0:17 | tangent | "Actually that reminds me..." | Digression about unrelated project |

## Flagged for Review
| # | Location | Issue | Recommendation |
|---|----------|-------|----------------|
| 1 | ~00:12:00 | Two competing explanations of same concept | Keep the second one (clearer); your call |
```

## Timeline Export

Generate timeline file in the user's NLE format:
- **FCXML** (Final Cut Pro / DaVinci Resolve)
- **EDL** (Premiere, general interchange)

Include a small handle (default: 3-5 frames) on each cut so the editor can finesse transitions.

## Revision Loop

1. User marks up the paper edit (keep this, cut that, move this)
2. Regenerate the timeline from the marked-up edit
3. Re-export until the user approves

## Verification

Test on a short recording (under 5 minutes). Import the timeline into the editor and confirm cuts match the paper edit.
