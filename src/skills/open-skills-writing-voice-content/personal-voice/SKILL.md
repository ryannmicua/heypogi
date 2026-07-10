---
name: personal-voice
description: Write in the user's authentic voice across contexts -- not a single tone preset, but a model of how they actually write and when they shift registers. Use whenever asked to write, rewrite, or review something in the user's voice.
---

# Personal Voice Skill

Encode how you actually write across contexts, not as a single tone preset. The difference between an agent that drafts for you and one that drafts as you.

## Trigger Conditions

- User asks to write, rewrite, or review something in their voice
- Drafting emails, posts, docs, messages, or any prose on the user's behalf
- User says "make this sound like me" or "in my voice"

## Setup

Collect 5-10 real writing samples across different contexts:
- Emails (internal, external, short replies)
- Posts or articles (social, blog, newsletters)
- Documentation or technical writing
- Casual messages (Slack, texts, DMs)

Analyze and present to the user for review:
1. Distinct registers observed
2. Sentence-level patterns
3. Anti-patterns (words/openers/constructions never used, plus AI-prose tells)
4. Rules for when to use which register

## Register Model

Define registers with one short sample each. Example structure:

### Direct / Instructional
- **When**: Technical docs, instructions, quick decisions
- **Traits**: Short sentences, imperative mood, no softening
- **Sample**: "The cache expires after 10 minutes. Set TTL higher if you need longer."

### Warm / Relational
- **When**: Team updates, feedback, 1:1 communication
- **Traits**: Acknowledges context, genuine not performative
- **Sample**: "Hey, good catch on the deploy issue. I pushed a fix -- give it a look when you can."

### Analytical
- **When**: Decision docs, proposals, post-mortems
- **Traits**: Evidence-forward, names tradeoffs explicitly, admits gaps
- **Sample**: "Three options here. Option B is fastest but fragile under concurrency. I'd go with C despite the extra day of work."

### Business-Formal
- **When**: External stakeholders, vendors, cross-org communication
- **Traits**: Clarity over formality, no jargon, direct but respectful
- **Sample**: "The timeline moves to March 15th due to a dependency from the platform team. Happy to walk through the details if helpful."

## Anti-Patterns

Explicitly ban:
- AI-prose tells: "delve," "tapestry," "landscape," "crucial," "moreover," "furthermore," "it is worth noting"
- Openers never used: "I hope this finds you well," "As we discussed," "Just circling back"
- Constructions never used: rhetorical questions as openers, hedging stacks ("I was just wondering if maybe...")
- Any filler the user explicitly identifies from their samples

## Accuracy Over Voice

For technical content, accuracy beats voice. Never bend facts, simplify data, or round numbers to sound more like the user. A slightly blunter sentence with correct numbers is better than a voice-perfect sentence with approximated ones.

## Verification

Draft one short email and one short post on user-provided topics. Let the user grade them -- identify what rang true and what needs adjustment.
