---
name: image-gateway
description: Generate or edit images through the OpenRouter API with one command and zero per-call setup. Stores saved preferences so routine image requests just work. Use for any image generation or editing task.
---

# Image Generation Gateway

Generate or edit images through the OpenRouter API with one command. Centralize all image generation so a fix to the API call benefits every workflow that produces images.

## Trigger Conditions

- User asks to generate an image
- User asks to edit or modify an existing image
- Another skill needs image generation (they call this one, don't reimplement)

## Setup

On first use, collect:
1. **Default image model** (suggest: `openai/dall-e-3` or `stability/sdxl`)
2. **Default output directory** (default: `work/images/`)
3. **OpenRouter API key location** — must be read from an env file, never written into the skill

Store preferences in the skill so routine requests are zero-config.

## API Request Shape

### Generate
```bash
curl https://openrouter.ai/api/v1/images/generations \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<saved-default-model>",
    "prompt": "<prompt>",
    "n": 1,
    "size": "<saved-default-size>"
  }'
```

### Edit (inpainting)
```bash
curl https://openrouter.ai/api/v1/images/edits \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -F "image=@<path-to-image>" \
  -F "mask=@<path-to-mask>" \
  -F "prompt=<prompt>" \
  -F "n=1" \
  -F "size=<saved-default-size>"
```

## Gotochas

- Check OpenRouter model list for current live model IDs before each session — these change
- DALL-E models bill per image (check current pricing at openrouter.ai/models)
- SDXL models bill per inference step; larger sizes cost more
- Rate limits apply per API key

## Preferences (Fill on Setup)

- **Default model**: `___`
- **Default output directory**: `___`
- **Default size**: `1024x1024` (adjust per model capabilities)
- **API key location**: `___` (env file path, never inline)

## Rule for Other Skills

Do not write your own image API code. Call this skill. If the API shape changes, it gets fixed here once.

## Verification

Generate one image with saved defaults, review the result, and update the skill with anything learned from the test.
