---
name: broll-pipeline
description: End-to-end pipeline that turns a talking-head video into one with animated motion graphics. Scout selects moments, builder generates Remotion components, orchestrator composites onto source. Use when adding motion graphics to video at scale.
---

# B-Roll Pipeline

An end-to-end pipeline that takes a finished talking-head video plus its timestamped transcript and produces animated motion-graphic overlays composited onto the video at the right moments. Motion graphics work that costs an editor days happens in a supervised pipeline run.

## Trigger Conditions

- User has a finished talking-head video and wants motion graphics added
- User asks to "add graphics" or "animate" or "add overlays" to a video
- User wants to scale motion graphics production across long-form content

## Prerequisites

- `media-transcription` skill (chapters + word-level timestamps)
- Node.js with Remotion installed
- ffmpeg for compositing
- Significant initial build investment -- this is a project

## Architecture

Three pieces working together:

### 1. Scout Subagent
Reads the chaptered transcript and selects which moments deserve a graphic:
- **Density rule**: target 1-3 graphics per minute, never exceed 4/min
- **Spacing rule**: minimum 15-20 seconds between graphics
- **Selection criteria**: key statistics, named concepts, process steps, comparisons, quotes, definitions
- **Output**: a manifest file

```json
{
  "manifest": [
    {
      "id": "gfx-001",
      "time_in": "00:01:23.500",
      "time_out": "00:01:30.000",
      "duration_seconds": 6.5,
      "concept": "Revenue growth chart Q1-Q4",
      "data": { "type": "bar_chart", "values": [10, 23, 45, 67], "labels": ["Q1", "Q2", "Q3", "Q4"] },
      "text": "Revenue grew 67% in 2024"
    }
  ]
}
```

### 2. Builder Subagent
Takes 2-3 manifest entries at a time and generates Remotion components:
- All components built against a **shared visual contract** -- one TypeScript file defining palette, typography, animation primitives, and layout components
- Each component is a self-contained Remotion `<Composition>`
- Builder validates output against the contract before returning

#### Visual Contract (TypeScript)
```typescript
// visual-contract.ts -- the single source of truth for all graphics
export const PALETTE = {
  background: '#0a0a0f',
  surface: '#1a1a2e',
  text: '#f0f0f5',
  accent: '#6c5ce7',
  secondary: '#00cec9',
  muted: '#636e72',
};

export const TYPOGRAPHY = {
  heading: { fontFamily: 'Inter, sans-serif', fontWeight: 700 },
  body: { fontFamily: 'Inter, sans-serif', fontWeight: 400 },
  mono: { fontFamily: 'JetBrains Mono, monospace', fontWeight: 500 },
};

export const ANIMATION = {
  fadeIn: { from: { opacity: 0 }, to: { opacity: 1 }, duration: 300 },
  slideUp: { from: { opacity: 0, y: 20 }, to: { opacity: 1, y: 0 }, duration: 400 },
  scaleIn: { from: { opacity: 0, scale: 0.9 }, to: { opacity: 1, scale: 1 }, duration: 350 },
};
```

### 3. Orchestrator Skill
Runs the full pipeline:
1. Run scout on transcript -> produce manifest
2. User reviews manifest (approve/reject individual graphics)
3. Run builder on manifest entries in batches (2-3 at a time)
4. Render each Remotion composition to a video clip
5. Composite clips onto source video at manifest timestamps with ffmpeg
6. Output final video with graphics overlays

## Pipeline State File

Maintain state so a multi-hour run can resume after interruption:

```json
{
  "pipeline_id": "broll-2024-03-15",
  "stages": {
    "scout": "complete",
    "manifest_review": "complete",
    "builder": { "status": "in_progress", "completed": [1, 2, 3], "next": 4 },
    "render": "pending",
    "composite": "pending"
  }
}
```

## Setup Interview

On first use:
- Brand palette and typography for the visual contract
- Target graphic density (default: 1-2 per minute)
- Output resolution and format (default: 1080p H.264)

## Staged Build Order

1. **Visual contract first** -- define and agree on palette, typography, animation
2. **One reference graphic** -- hand-build one Remotion component together, approve the look
3. **Scout** -- run on transcript, review manifest quality
4. **Builder** -- generate from manifest, validate against contract
5. **Render + composite** -- end-to-end on a short test

## Verification

Test the full pipeline on a short video (2-3 minutes with 3-5 graphics) before running on real footage.
