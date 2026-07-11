---
name: branded-image-prompting
description: Generate on-brand images by encoding visual identity as prompting guidance plus a reusable prompt library. Use for any branded or recurring-format image request. Composes image-gateway for actual generation.
---

# Branded Image Prompting

Encode your visual identity as prompt-ready guidance. Every image starts on-brand. Every successful prompt feeds back into the library so the next one is better.

## Trigger Conditions

- Any branded image request (explicit or implied by format)
- User says "on-brand," "in my brand," "branded," or references their visual identity
- Generating thumbnails, diagrams, infographics, social media images, or UI mockups
- Another skill needs a branded image — this skill provides the prompt; `image-gateway` generates it

## Brand Guidelines (Prompt-Ready)

Inject this block into every prompt by default. Models understand hex codes and plain English descriptions — use both.

```
## Visual Identity — "Hey Pogi" Brand

### Color Palette
- Primary (#0050a1): SSD blue. Use for primary buttons, selected items, links, focus rings.
- Primary Container (#1d68c5): Brighter blue variant. Use for hover states and stronger brand moments.
- Secondary (#785a00): Warm dark gold. Use for accessible text, small icons, and subtle gold elements.
- Secondary Container (#ffc734): Bright gold. Use sparingly for warning indicators, pending badges, and tiny brand marks.
- Brand Accent (#f6be2b): Gold identity marker. Use ONLY as thin accent lines: 1-2px top borders on cards, left rules on active navigation, thin dividers. Never use as a fill or background.
- On Brand Accent (#251a00): Deep brown text. Use only when text sits on a gold background.
- Surface: Near-white (#fafafa to #ffffff). All backgrounds, cards, containers.
- Surface Variant: Light warm gray (#f5f4f0). Alternate surface for subtle section breaks.

### Saturation Rule
Saturated color is used SPARINGLY. Most of the interface is neutral white/off-white.
Gold appears as thin lines, not filled blocks. Blue appears on interactive elements, not decorative backgrounds.
The overall feeling is calm, clean, and professional — not colorful.

### Typography
- Sans-serif, geometric, modern
- Headings: medium weight, tight letter-spacing (0.5-1px)
- Body: regular weight, comfortable line-height (1.5-1.6)
- No serif. No script. No decorative or display fonts.
- No italic for headings. Italic only for short emphasis in body text.

### Composition & Layout
- Clean, high-contrast, generous white space
- Subtle borders (1px, #e0ded8) instead of shadows or filled containers
- No drop shadows, no bevels, no 3D effects, no gradients except for hover transitions
- Flat design with occasional subtle elevation through 1px borders
- Single clear focal point per image
- Grid-aligned, structured layouts with breathing room

### Decorative Language
- Gold accent lines only: thin (1-2px) horizontal rules, left border bars, card-top strips
- Geometric accent shapes in very low opacity blue (#0050a1 at 5-10%) allowed as background texture
- No clip-art. No stock-photo aesthetic. No handshakes, no smiling-at-laptop, no generic office imagery.
- Abstract, editorial, clean — think modern SaaS, not corporate intranet

### Anti-Patterns (Never Do)
- No rainbow gradients or purple-to-blue washes
- No gold as a filled background (it's always a thin line or text)
- No text-heavy slides disguised as images
- No bevels, drop shadows, glow effects, or 3D rendering
- No serif fonts, no script fonts, no handwriting fonts
- No saturated color covering more than 15% of the canvas
- No generic "AI-generated" look (glassy buttons, floating isometric cubes, glowing orbs)
```

## Prompt Patterns

### Natural Language (use for ideation, photorealism, illustrated styles)

Structure:
```
<brand-prefix> + <subject> + <style direction> + <composition> + <color-constraints>
```

Example:
```
Clean flat vector illustration in a modern geometric style. A developer reading
documentation on a floating screen. Thin gold accent line (#f6be2b, 2px) separates
the header area. Background near-white (#fafafa) with faint blue geometric shapes
(#0050a1 at 5% opacity). Primary blue (#0050a1) on interactive elements only.
Sans-serif headings. No shadows, no gradients, no 3D. Single focal point, generous
white space.
```

**When it works better**: Creative exploration, photorealistic outputs, illustrated scenes, variable compositions where you want the model to interpret the brief.

### JSON-Structured (use for diagrams, infographics, layouts, UI mockups)

When the image model accepts structured layout descriptions, use JSON to pin down exact placement. This is the preferred format for anything with text labels or precise spatial relationships.

```json
{
  "style": "flat-vector-geometric",
  "canvas": { "width": 1200, "height": 630, "background": "#fafafa" },
  "brand": {
    "accentLine": { "color": "#f6be2b", "width": 2, "position": "top" },
    "primaryColor": "#0050a1",
    "textColor": "#1a1a2e",
    "surfaceColor": "#f5f4f0"
  },
  "elements": [
    { "type": "heading", "content": "...", "position": "center-top", "color": "#1a1a2e", "font": "sans-serif-geometric-medium" },
    { "type": "divider", "style": "gold-accent-line", "below": "heading" },
    { "type": "icon-set", "style": "geometric-outline", "count": 3, "color": "#0050a1" }
  ],
  "composition": "centered-hierarchy",
  "rules": ["no-shadows", "no-gradients", "no-3d", "white-space-generous"]
}
```

**When it works better**: Structural outputs (diagrams, flowcharts, infographics), UI mockups with explicit layout, anything with labeled boxes or arrows, social cards with fixed text placement.

**Model compatibility note**: Not all image models respect structured JSON. Prefer natural-language for DALL-E and SDXL; use JSON-structured for layout-aware models (Ideogram, Recraft, current-gen Flux). When in doubt, write natural-language and test.

## Prompt Template Library

Templates encode reusable patterns. Fill `[...]` placeholders for each use. After a prompt succeeds, add it to the library with a descriptive name.

### Thumbnails / Social Cards

**1. Standard Social Card (Blog Post / Article)**
```
Clean flat editorial social card, 1200x630. Near-white background (#fafafa).
Title in bold geometric sans-serif, dark charcoal (#1a1a2e), centered, 2-3 lines max.
Thin gold accent line (#f6be2b, 2px) runs full width directly below the title.
Subtle abstract geometric shape in low-opacity blue (#0050a1 at 8%) sits behind the title as a textural element.
Small blue (#0050a1) pill badge at bottom containing the category label "[CATEGORY]".
No shadows, no gradients, no photography. White space dominant.
```

**2. Quote Card (Pull Quote / Testimonial)**
```
Clean flat quote card, 1080x1080. Near-white background (#f5f4f0).
Large open-quote mark in gold (#f6be2b, faded to 40% opacity) as the only decorative element, positioned top-left.
Quote text in geometric sans-serif, dark charcoal (#1a1a2e), centered, generous line-height.
Thin gold line (#f6be2b, 2px) separates quote from attribution.
Attribution in smaller blue (#1d68c5) text below the line.
No photography, no drop shadows, no decorative borders beyond the single gold line.
```

**3. Event / Announcement Card**
```
Clean flat announcement card, 1200x630. Near-white background (#fafafa) with a 2px gold top border (#f6be2b).
Event title in bold geometric sans-serif, dark charcoal (#1a1a2e), left-aligned in the upper half.
Date and time in blue (#0050a1) pill badges, arranged horizontally below the title.
Thin 1px divider (#e0ded8) separates the header section from body text.
Brief description in regular-weight body text below the divider.
No shadows, no gradients, no photography.
```

**4. Minimal Hero / Banner**
```
Clean flat hero banner, 1440x600. Background split: 70% near-white (#fafafa), 30% light warm gray (#f5f4f0) on the right.
Thin gold accent line (#f6be2b, 2px) at the very top edge.
Headline in bold geometric sans-serif, dark charcoal (#1a1a2e), left third of canvas.
Subheadline in regular-weight, slightly smaller, below the headline.
Single blue (#0050a1) CTA button shape (rounded, 8px, no shadow) at bottom-left of text block.
Faint geometric pattern in low-opacity blue (#0050a1 at 5%) fills the right-side background area.
No photography, no icons, no 3D.
```

### Diagrams

**5. Simple Flow Diagram (3-5 Steps)**
```
Clean flat vector flowchart diagram. Near-white background (#fafafa).
3 to 5 rounded-rectangle nodes arranged horizontally, connected by thin arrows (#0050a1, 1.5px).
Each node: white fill, 1px border (#e0ded8), blue label text (#0050a1) in geometric sans-serif.
A thin gold accent line (#f6be2b, 2px) sits above the first node as a starting marker.
Node labels are single words or short phrases, centered in each box.
No shadows, no gradients, no 3D depth. Clean and structured.
```

**6. Architecture / System Diagram**
```
Clean flat architecture diagram. Near-white background (#fafafa).
Boxes for each system component: white fill, 1px border (#e0ded8), label in dark charcoal (#1a1a2e) geometric sans-serif.
Connecting lines and arrows in blue (#0050a1, 1.5px) with arrow endpoints.
Dotted boundary boxes (1px dashed, #e0ded8) for grouping related components.
Group labels in smaller blue text (#1d68c5) positioned at the top-left of each boundary box.
Thin gold line (#f6be2b, 2px) as a horizontal divider between the title area and the diagram body.
No shadows, no gradients, no fill colors except white and near-white.
```

**7. Decision Tree / Branching Diagram**
```
Clean flat decision tree diagram. Near-white background (#fafafa).
Diamond shapes for decision nodes: white fill, 1px gold border (#f6be2b), label in dark charcoal.
Rectangle shapes for outcome nodes: white fill, 1px border (#e0ded8), label in dark charcoal.
Connecting lines with labels: blue (#0050a1) for "Yes" branches, warm dark gold (#785a00) for "No" branches.
Title in geometric sans-serif bold at the top, separated by a thin gold line.
No shadows, no gradients, no 3D.
```

### Infographics

**8. Statistic / Data Highlight**
```
Clean flat infographic for a single statistic. Near-white background (#fafafa).
Large number in bold geometric sans-serif, blue (#0050a1), centered in the upper half. Font size dominant — at least 30% of canvas height.
The stat label in smaller dark charcoal (#1a1a2e) text directly below the number.
Thin gold accent line (#f6be2b, 2px, 60% width) centered between the number and the label.
Optional: 1-2 small supporting stats in lighter text at the bottom, separated by thin vertical dividers (#e0ded8, 1px).
No charts, no icons, no photography. Pure typography and spacing.
```

**9. Timeline / Roadmap**
```
Clean flat timeline infographic. Near-white background (#fafafa).
Horizontal timeline bar: thin blue line (#0050a1, 2px) running center across the canvas.
Milestone markers: small circles (#0050a1, filled, 12px diameter) placed at intervals on the timeline.
Labels above each milestone in dark charcoal (#1a1a2e), geometric sans-serif, tight but readable.
Date badges below each milestone: blue (#1d68c5) pill shapes, small.
Thin gold line (#f6be2b, 2px) at the top as a decorative header bar.
No shadows, no gradients, no 3D.
```

**10. Comparison Table / Side-by-Side**
```
Clean flat comparison infographic. Near-white background (#fafafa).
Two-column layout with a thin gold vertical divider (#f6be2b, 1.5px) centered.
Column headers in bold geometric sans-serif, blue (#0050a1), centered above each column.
Row items in dark charcoal (#1a1a2e) body text, alternating row backgrounds (#ffffff / #f5f4f0 at subtle 50% opacity).
Checkmark icons in blue (#0050a1), cross icons in warm dark gold (#785a00).
No shadows, no gradients. Clean tabular feel.
```

### Social Media Images

**11. Instagram / Square Post**
```
Clean flat Instagram post, 1080x1080. Near-white background (#fafafa).
Thin gold accent line (#f6be2b, 2px) at the top edge.
Main message in bold geometric sans-serif, dark charcoal (#1a1a2e), centered, 2-3 lines, occupying the middle 60% of the canvas.
Faint geometric background texture in low-opacity blue (#0050a1 at 6%).
Small logo mark or site URL in blue (#1d68c5) at the very bottom, centered.
No photography, no drop shadows, no gradients.
```

**12. LinkedIn / Horizontal Post Image**
```
Clean flat LinkedIn post image, 1200x627. Near-white background (#fafafa).
Left third: bold headline in dark charcoal (#1a1a2e) geometric sans-serif, left-aligned, occupying most of the vertical space.
A thin gold line (#f6be2b, 2px) sits to the left of the text block as a left-border accent bar.
Right two-thirds: abstract geometric composition using blue shapes (#0050a1 at 8-12% opacity) on near-white.
No photography, no faces, no drop shadows.
```

### UI Mockups

**13. Dashboard / Data View Mockup**
```
Clean flat UI mockup of a dashboard screen. Near-white background (#fafafa).
Top nav bar: white (#ffffff) with a thin bottom border (#e0ded8, 1px). Blue (#0050a1) active nav item.
Left sidebar: white with thin right border (#e0ded8, 1px). Active item has a thin gold left-accent line (#f6be2b, 2px).
Card grid in the main content area: 2x2 cards, each white fill with 1px border (#e0ded8), subtle rounded corners (8px).
Card headers in blue (#1d68c5) geometric sans-serif.
Thin gold accent line (#f6be2b, 1.5px) runs below each card header.
Data represented as clean bar charts and line graphs using blue (#0050a1) and warm dark gold (#785a00).
No shadows on cards. No gradients. No 3D.
Placeholder text labels should use real-looking but neutral content ("Monthly Report," "Active Users," "Revenue").
```

**14. Form / Input Screen Mockup**
```
Clean flat UI mockup of a form screen. Near-white background (#fafafa).
Page title in bold geometric sans-serif, dark charcoal (#1a1a2e), top-left, with a thin gold accent line below (#f6be2b, 2px).
Input fields: white fill, 1px border (#e0ded8), rounded 6px, with placeholder text in light gray.
Focused field: 2px blue border (#0050a1).
Labels above each field in dark charcoal, small geometric sans-serif.
Primary submit button: filled blue (#0050a1), white text, rounded 8px, no shadow.
Secondary cancel: outlined, 1px border (#e0ded8), dark charcoal text.
Checkbox and radio elements in blue (#0050a1).
No shadows, no gradients. Fully flat, clean, modern form layout.
```

### General-Purpose

**15. Section Divider / Spacer Graphic**
```
Clean flat decorative divider graphic. Transparent or near-white background (#fafafa).
Single thin gold line (#f6be2b, 1.5px) running horizontally at 40% width, centered.
Subtle geometric diamond or circle in blue (#0050a1 at 15% opacity) at the center of the line.
Nothing else. Minimal, clean, structural.
```

## Corrective Prompting Recipes

When generation drifts, append the correction. Do NOT rewrite the whole prompt — add it as a suffix.

| Drift | Correction to Append |
|---|---|
| Wrong colors (model used its own palette) | "The exact colors must be: background #fafafa, primary blue #0050a1, accent gold #f6be2b. Ignore your default palette. No purple, no teal, no orange." |
| Gold used as fill/bg instead of accent line | "Gold (#f6be2b) must appear ONLY as thin 1-2px lines, never as a filled area or background. No gold blocks, no gold gradients." |
| Model added shadows or 3D | "Flat 2D design ONLY. No drop shadows, no bevels, no depth, no 3D rendering, no material design elevation." |
| Model added gradients | "No gradients anywhere. Solid flat colors only. Use subtle borders instead of gradient fades." |
| Mangled or hallucinated text | "Do NOT include any text in the image. Rely entirely on composition, shapes, and color. I will add text in post." |
| Too colorful (saturation rule broken) | "The canvas must be 85%+ neutral white/off-white. Blue and gold should cover less than 15% of the total area. This is a restrained, professional brand." |
| Off-style (model defaulted to stock-photo look) | "This is NOT stock photography. It is an abstract editorial illustration in flat geometric style. No photos, no people, no real-world objects." |
| Too busy / cluttered | "Simplify. Maximum 3-4 visual elements. Single focal point. Generous white space. Remove anything that is not essential." |
| Serif or decorative font appeared | "Use geometric sans-serif font ONLY. No serif. No decorative. No handwriting. Clean, modern, unadorned." |
| Model ignored the accent line | "There MUST be a thin gold accent line (#f6be2b, 1-2px) somewhere in the composition — top border, left rule, or divider between sections." |

## Generation Rule

**Always route actual image generation through `image-gateway`.**

1. Prepare the prompt using this skill's guidelines
2. Call `image-gateway` with the prepared prompt
3. After a successful generation: add the prompt to the template library above with a descriptive name
4. If the generation fails or produces off-brand output: use the corrective recipes, retry once, then report to the user if it still drifts

Never write raw API calls. Never inline API keys. The gateway handles all of that.

## Verification

Generate one thumbnail and one diagram in the user's brand. Let the user judge brand adherence.
