---
name: image-model-arena
description: Build and publish image-model comparison pages -- one review page per model plus a shared side-by-side viewer -- generated from a single config. Composes image-gateway and site-publisher. Use when testing new image models or comparing models.
---

# Image Model Comparison Arena

Build and publish image-model comparison pages from a single config file. One review page per model plus a shared side-by-side comparison viewer. Composition as architecture: this skill generates nothing directly -- it delegates to `image-gateway` for images and `site-publisher` for publishing.

## Trigger Conditions

- User wants to test a new image model
- User asks to compare image models
- User wants to add a model to an existing comparison

## Prerequisites

- `image-gateway` skill installed and configured
- `site-publisher` skill installed and configured
- Budget for generation costs (typically $2-$10 per model)

## Setup Interview

On first use, ask:
- Standard test prompt set (help design 6-10 prompts covering):
  - Photorealism (portrait, landscape, object)
  - Text rendering (signage, UI mockups)
  - Diagrams (flowcharts, architecture)
  - People (groups, expressions)
  - Style range (illustration, 3D, vector)
- Where comparison configs and generated images should live

## Config Format

```json
{
  "arena_id": "image-model-comparison-2024-03",
  "title": "Image Model Comparison: Q1 2024",
  "models": [
    {
      "id": "dall-e-3",
      "name": "DALL-E 3",
      "provider": "openai",
      "openrouter_model_id": "openai/dall-e-3",
      "cost_per_image": 0.04,
      "default_size": "1024x1024"
    }
  ],
  "prompts": [
    {
      "id": "photoreal-portrait",
      "category": "photorealism",
      "prompt": "A portrait of a woman in natural window light, 85mm lens, shallow depth of field",
      "evaluation_criteria": "Skin texture, eye detail, lighting naturalness"
    }
  ],
  "page_metadata": {
    "slug": "image-model-comparison-2024",
    "title": "Image Model Comparison: Q1 2024",
    "description": "Side-by-side comparison of image generation models"
  }
}
```

## Pipeline

### 1. Generate Images
For each model x each prompt:
- Call `image-gateway` skill
- Store result at `work/arena/<arena_id>/images/<model_id>/<prompt_id>.png`
- Record generation time and any errors

### 2. Optimize for Web
- Resize large images (max 1200px on longest edge)
- Convert to WebP with fallback
- Generate thumbnails for comparison grid (300px)

### 3. Build Per-Model Pages
One review page per model with:
- Model name, provider, cost per image
- Each prompt + output + evaluation notes
- Content-policy quirks observed (what was rejected, what was softened)

### 4. Build Comparison Viewer
- Side-by-side grid: prompts as rows, models as columns
- Click to expand full-size comparison
- Filters by prompt category

### 5. Publish
- Call `site-publisher` skill for the index and per-model pages
- Never reimplement publishing logic

## Model Registry

Maintain a running registry of observations:

```json
{
  "models": {
    "dall-e-3": {
      "cost_per_image_1024": 0.04,
      "cost_per_image_1792": 0.08,
      "content_policy_quirks": [
        "Rejects prompts with 'blood' even in medical context",
        "Softens facial detail on non-famous subjects"
      ],
      "strengths": ["Text rendering", "Following complex prompts"],
      "weaknesses": ["Photorealism vs Midjourney", "Style consistency across generations"]
    }
  }
}
```

## Regeneration Support

Adding one model must not require redoing the others. Each model's images live independently. Rebuild only the affected pages when a single model is added.

## Verification

Test with 2 models on a 3-prompt subset before running at full scale.
