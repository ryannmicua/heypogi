---
name: stakeholder-update-email
description: After work ships with stakeholder-visible impact, send or draft a short, truthful update email to the right person. Use when work merges or ships with visible impact, or when asked for an update email.
---

# Stakeholder Update Email

After work ships with stakeholder-visible impact, send or draft a short, truthful update email to the person who needs to know. The discipline: updates go out only when something actually changed, in their vocabulary, with nothing unverified called done.

## Trigger Conditions

- Work merges or ships with visible impact for a stakeholder
- User asks for an update email
- End of a milestone or sprint with deliverable changes

## Gate: Should an Update Go Out?

If nothing stakeholder-visible changed, say so and send nothing. "Refactored the caching layer" is not stakeholder-visible. "Pages load in under 2 seconds now" is.

## Writing Rules

1. **Describe shipped behavior in the recipient's vocabulary** — not implementation details. Say "you can now export reports as PDF" not "added pdfkit integration"

2. **Never call anything done that wasn't verified** — if tests didn't pass, if it wasn't deployed, if you only "think" it works, it doesn't go in the update

3. **If something shipped partially, say which part** — "the dashboard is live; the export feature ships next week"

4. **No jargon, no status-report filler, no roadmap hedging** — the recipient cares about what's different now, not what was hard to build

## Format

```
Subject: <project/feature> update — <one-line summary of what changed>

<One sentence of what changed, in plain language.>

What this means for you:
- <impact point 1>
- <impact point 2>

What's next:
- <immediate next thing the stakeholder will see or should expect>

—
<your name>
```

Keep it short. If it takes the recipient more than 30 seconds to read, it's too long.

## Send/Draft Mechanics

The skill defaults to **draft-first mode**: always show the draft to the user for review before sending. Only send directly if:
- The user has explicitly authorized direct sends
- A sending method (Resend API, SMTP, mail provider API) is configured and tested

If a sending API is configured, CC the user on all sends.

## Stakeholder Setup (Interview Required)

On first use, interview the user for:
- Who the recurring stakeholders are
- What each stakeholder cares about (features, timeline, cost, reliability, etc.)
- Preferred sending method per stakeholder (direct send vs. draft for approval)
- Whether user should be CC'd on sends
