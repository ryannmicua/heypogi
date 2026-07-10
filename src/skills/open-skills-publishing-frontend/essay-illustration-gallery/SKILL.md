---
name: essay-illustration-gallery
description: Turn a finished essay into a consistent illustration gallery -- select image-worthy moments, lock one style, generate images, caption each, and assemble a gallery page. Composes image-gateway for generation and site-publisher if publishing.
---

# Essay Illustration Gallery

Turn a finished essay into a complete illustration package. The hard part isn't generating images -- it's editorial judgment (which moments deserve images) and consistency (twenty images that look like one artist made them).

## Trigger Conditions

- User shares an essay or long post and asks for illustrations, images, or a gallery
- User wants visual material to accompany a written piece
- User says "illustrate this" or "make a gallery for this essay"

## Prerequisites

- `image-gateway` skill for image generation
- `site-publisher` skill if the gallery should be published
- `personal-voice-skill` (if available) for the social note
- `html-artifacts` (if available) for gallery assembly conventions

## Setup Interview

On first use, ask:
- Preferred illustration style direction -- help write a precise style descriptor locked per gallery:
  - "Hand-drawn editorial cartoon, ink and watercolor, muted palette, New Yorker style"
  - "Photorealistic, warm natural light, shallow depth of field, cinematic"
  - "Bold vector illustration, flat colors, geometric, corporate editorial"
- How many frames a typical essay should get (default: 15-20 for a 2000-word essay)

## Pipeline

### 1. Read and Map the Essay
- Read the entire piece to understand its arc (setup, development, climax, resolution)
- Identify the essay's structure: sections, turning points, key arguments

### 2. Moment Selection
Choose image-worthy moments across the FULL arc, not just the opener:
- **Opening hook** (1 frame)
- **Key argument/evidence per section** (1-2 frames each)
- **Turning point or counterargument** (1-2 frames)
- **Emotional or human moment** (1 frame)
- **Climax or revelation** (1 frame)
- **Resolution or call to action** (1 frame)

Each frame tied to a specific passage with a one-line rationale:
```
Frame 3: "The moment she realized the data was wrong" 
  -> Passage: "She stared at the screen for a full minute..."
  -> Rationale: The emotional turning point of the investigation
```

### 3. Style Lock
Write one detailed style descriptor, prepended to every prompt:
```
Style: Hand-drawn editorial cartoon style. Ink lines with watercolor wash. 
Muted palette of navy, rust, and ochre on cream paper. Cross-hatched shadows. 
No digital smoothing. Single-panel composition. New Yorker cartoon aesthetic.
```

Every frame uses this exact style prefix so all images are visually consistent.

### 4. Generate Images
For each frame:
- Combine style lock + frame-specific prompt
- Call `image-gateway` skill
- Store at `work/galleries/<essay-slug>/images/frame-XX.png`

### 5. Caption Each Frame
Per image, write:
- The quote or passage it illustrates
- 1-2 sentences on why this moment was chosen
- Never just "illustration for paragraph 3"

### 6. Assemble Gallery Page
Use `html-artifacts` conventions:
- Hero with essay title and author
- Grid or scroll of frames, each with image + caption
- Navigation: scroll, lightbox, or prev/next
- Link back to the full essay
- Credits (model, style, date generated)

### 7. Social Note (Optional)
A short ready-to-paste announcement in the author's voice:
```
I illustrated my essay "Why We Stopped Trusting Numbers" with 18 frames 
generated in a consistent hand-drawn style. The gallery is here: [URL]
```

Uses `personal-voice-skill` if available.

### 8. Publish (Optional)
If the user wants the gallery live, call `site-publisher`.

## Verification

Test on one essay with a reduced frame count (5-6 frames) first. Verify:
- All images share a consistent style
- Frame selection covers the full arc of the essay
- Each caption ties to a specific passage
