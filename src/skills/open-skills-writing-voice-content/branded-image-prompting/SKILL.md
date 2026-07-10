---
name: branded-image-prompting
description: Generate on-brand images by encoding visual identity as prompting guidance plus a reusable prompt library. Use for any branded or recurring-format image request. Composes image-gateway for actual generation.
---

# Branded Image Prompting Guide

Encode your visual identity as prompting guidance plus a reusable prompt library. Every image that works gets added back to the library.

## Trigger Conditions

- Any branded or recurring-format image request
- Thumbnails, diagrams, infographics, social images, mockups
- User says "on-brand" or references their visual identity

## Prerequisites

- `image-gateway` skill for actual generation
- Brand basics (collected in setup interview)

## Setup Interview

On first use, ask:
- Brand colors (hex codes)
- Typography direction (serif/sans-serif, geometric/humanist, any specific families)
- Overall visual style with reference images if available
- Most common image formats (thumbnails, diagrams, infographics, social, mockups)

## Brand Guidelines (Prompt-Ready)

Define in language image models understand:

```markdown
## Visual Identity

### Colors
- Primary background: `#0a0a0f` (near-black)
- Surface: `#1a1a2e` (dark navy)
- Primary text: `#f0f0f5` (off-white)
- Accent: `#6c5ce7` (vibrant purple)
- Secondary: `#00cec9` (teal)

### Typography Direction
- Geometric sans-serif, clean and modern
- No serif, no script, no decorative fonts
- Tight letter-spacing for headings, comfortable for body

### Composition Style
- Clean, high contrast, negative space
- Centered or asymmetric, never cluttered
- Strong single focal point per image
- Flat design with occasional subtle gradients for depth

### Anti-Patterns
- No bevels, drop shadows, or 3D effects
- No stock-photo aesthetic (no handshakes, no smiling-at-laptop)
- No rainbow gradients or purple-to-blue defaults
- No text-heavy slides disguised as images
```

## Prompt Patterns

### Natural Language (best for ideation, photorealism, style-driven)
```
<brand-prefix> + <subject> + <style direction> + <composition> + <brand-constraints>

Example: "Clean flat vector illustration. A developer reading documentation 
on a floating screen. Geometric shapes in the background. Colors: near-black 
background (#0a0a0f), vibrant purple accent (#6c5ce7), teal highlights 
(#00cec9). Minimalist. No gradients. No shadows."
```

### JSON-Structured (best for diagrams, infographics, layouts)
When the image model supports structured prompting, route through the structured format. Document which models support this.

## Prompt Template Library

### Thumbnails
```
1. <template-name>: "<filled-in prompt>"
2. <template-name>: "<filled-in prompt>"
```

### Diagrams / Architecture
```
1. <template-name>: "<filled-in prompt>"
2. <template-name>: "<filled-in prompt>"
```

### Infographics
```
1. <template-name>: "<filled-in prompt>"
```

### Social Images
```
1. <template-name>: "<filled-in prompt>"
```

### UI Mockups
```
1. <template-name>: "<filled-in prompt>"
```

Start with 10+ starter templates and add successful prompts back to the library.

## Corrective Prompting Recipes

| Drift | Correction |
|-------|------------|
| Wrong colors | "The background must be exactly #0a0a0f, not blue or gray." |
| Mangled text | Skip text in the image; rely on composition and color alone. |
| Off-style (3D when flat desired) | "Flat 2D design only. No depth, no bevels, no 3D rendering." |
| Too busy | "Single subject. Clean background. Maximum 3 visual elements." |
| Generic AI look | "Editorial illustration style, not stock-photo aesthetic." |

## Generation Rule

Always route actual generation through `image-gateway`. Never write raw API calls. After generation, add successful prompts back to the template library.

## Verification

Generate one thumbnail and one diagram in the user's brand. Let the user judge brand adherence.
