---
name: audience-content-system
description: Generate content for "Got a minute?" — internal AI tips and tutorials for Adventist office employees who are beginners in tech. Use when planning or drafting anything for this publication.
---

# Audience-Content System: "Got a minute?"

Generate content for internal staff at Adventist offices — office employees who know little about tech and are beginners with AI. Every piece starts calibrated to them. No "dumb it down" pass afterward.

## Trigger Conditions

- Planning or drafting any piece for "Got a minute?"
- User asks to "plan this week's content" or "draft a Quick Tip / Tutorial"
- Batch content planning or editorial calendar work
- Any prompt mentioning "for the staff" or "for Got a minute?"

## Audience Contract

### Knowledge Floor (what every reader has)

- Can use email, a web browser, and Microsoft Word
- Has heard of ChatGPT or "AI" in the news, may have tried it once
- Understands the idea of "asking a question and getting an answer"
- Reads at a general-office level (not technical)

### Knowledge Ceiling (what they definitely don't know — never assume)

- How AI works under the hood (training, parameters, neural anything)
- What different AI tools are or how they differ
- Technical vocabulary of any kind
- Keyboard shortcuts beyond Ctrl+C / Ctrl+V
- File formats, extensions, or system settings
- What "the cloud" actually means
- Browser dev tools, inspect element, or console
- Any concept that requires a computer science metaphor to explain

### Banned Jargon (with plain-language substitutions)

| Instead of | Use |
|---|---|
| LLM / Large Language Model | "the AI" or "the tool" |
| API / API key | "connect your account" or skip entirely |
| IDE / code editor | skip — not relevant to this audience |
| Prompt engineering | "how you ask the AI" |
| Token | skip — never mention |
| Hallucination / hallucinate | "made-up answer" or "the AI got it wrong" |
| Model / version (e.g. GPT-4) | skip — never mention versions |
| Parameters / context window | skip — never mention |
| Embedding / vector | skip — never mention |
| Fine-tuning / training | skip — never mention |
| RAG / retrieval | skip — never mention |
| Neural network | skip — never mention |
| Algorithm | "the way it works" |
| Machine learning | "AI learning from examples" (only if essential, otherwise skip) |
| Interface / UI | "the screen" or "the chat box" |
| Input / output | "what you type" / "what you get back" |
| Generate | "write" or "create" |
| Deploy / deployment | skip — never mention |
| Repository / repo | skip — never mention |
| Dataset / training data | "examples it learned from" (only if essential, otherwise skip) |
| Query | "ask" or "question" |
| Optimize | "make better" |

### Tone Rules

- Write like you're explaining something to a friendly coworker at their desk
- Short sentences. One idea per sentence.
- Never say "simply" or "just" — nothing is simple to a beginner
- Use real office situations they'd recognize: scheduling, email, bulletins, forms, spreadsheets
- If a concept needs more than 2 sentences to explain, it's too complex for this audience — find a simpler framing or skip it
- Include a "Try this" prompt in every Quick Tip
- Include a "What to watch out for" caution in every piece

## Content Format Templates

### Format: Quick Tip

- **Length**: 200-400 words
- **Cadence role**: The weekly staple — one practical, immediately usable AI trick
- **Title formula**: "Use this prompt when you want to <do something at work>"

**Section structure**:

1. **The scenario** (1-2 sentences): a real office situation they face
2. **The prompt** (copy-paste ready, in a code block): the exact text to type into ChatGPT
3. **When to use it** (1 sentence): what situation this solves
4. **What you'll get back** (2-3 sentences): what the AI will produce, with a short example
5. **Try this variation** (1 prompt + 1 sentence): a slightly different version for a related task
6. **Watch out** (1 sentence): one thing to double-check or be careful about
7. **Got a minute?** (1 sentence closer): encouraging, ties back to saving time or doing better work

**Example skeleton**:
```
Use this prompt when you want to summarize a long email thread

## The scenario
You've been copied on a 20-message email chain and need to know what was decided.

## The prompt
[copy-paste prompt]

## When to use it
Whenever you're catching up on a long discussion and need the key points fast.

## What you'll get back
A short summary of the main decision, who's doing what, and any deadlines. For example:
> [example output]

## Try this variation
> [alternate prompt]
Use this when you need to reply with just your part done.

## Watch out
Always read the original thread before acting — the AI summarizes, but you make the call.

## Got a minute?
That's one less email thread to untangle. See you next week.
```

### Format: Tutorial

- **Length**: 400-800 words (keep under one printed page)
- **Cadence role**: The deeper dive — once every 3-4 weeks, when a topic needs step-by-step
- **Title formula**: "How to <accomplish a task> with <tool>"
- **Step count**: 3-7 steps maximum

**Section structure**:

1. **What you'll need** (bullet list, max 4 items): only things they already have — a browser, a free account, 5 minutes
2. **What you'll learn** (2-3 bullet points): concrete outcomes, not abstract concepts
3. **Steps** (numbered, one action per step):
   - Each step is one clear instruction
   - Bold the thing they click or type
   - No step has a sub-step
   - If a step has more than 3 sentences, split it
4. **What good looks like** (1-2 sentences): how they'll know it worked
5. **Stuck?** (1-2 sentences): the one most common problem and its fix
6. **Next time** (1 sentence): what they can try after mastering this

**Step-writing rules**:
- Every step starts with a verb: "Open", "Type", "Click", "Copy", "Paste"
- Button names in bold: "Click **Send**"
- Things they type are in `code` formatting
- Never say "the system will…" — say "you'll see…"
- Screenshots are ideal — note where one would help with `[SCREENSHOT: <description>]`

## Batch Planning Mode

When asked to plan content, produce a table covering one cycle (4 weeks for weekly cadence):

```markdown
# Content Plan: <theme>
**Publication**: Got a minute?
**Cycle**: <date range>

| Week | Format | Title | Hook |
|------|--------|-------|------|
| 1 | Quick Tip | <title> | <one-line hook> |
| 2 | Quick Tip | <title> | <one-line hook> |
| 3 | Tutorial | <title> | <one-line hook> |
| 4 | Quick Tip | <title> | <one-line hook> |
```

Rules for batch planning:
- 3 Quick Tips + 1 Tutorial per 4-week cycle (tutorials every 3-4 weeks)
- Each piece must solve a real office task — no abstract "learn about AI" pieces
- Hooks must be concrete: "Get a first draft of the weekly bulletin in 30 seconds" not "Improve your productivity with AI"
- Vary the office domain across the cycle (email, scheduling, writing, data/spreadsheets)

## Calibration Check

Before delivering ANY draft, run this check aloud:

> "Would someone who has never used an AI tool before follow every single step without getting lost?"

If the answer is no, fix the draft. Specific failure modes to watch for:

- **Jargon leak**: Did any banned word slip in? (check the banned list)
- **Assumed knowledge**: Did I skip explaining where to click, what to open first, or what they'll see?
- **Too many steps**: Does a step have more than 3 sentences? Split it.
- **Abstract outcome**: Is the result described in terms they'd recognize from their actual workday?
- **Missing caution**: Did I warn them about the one thing that could go wrong?

## Verification

After writing the skill, test it. Plan one content batch on a user-provided theme. Draft the shortest piece from the plan. Run the calibration check.
