---
name: human-gate
description: Enforce the review-and-submit boundary in high-stakes agent workflows. Define what the agent may and must not do -- the human reviews, signs, sends, files, or submits. Use at the export boundary of any high-stakes workflow.
---

# Human Gate

Define and enforce the stop line for high-stakes workflows: the agent may organize, draft, validate, and export, but a human reviews, signs, sends, files, or submits. This is the product boundary that keeps the person in charge.

## Trigger Conditions

- A high-stakes workflow reaches the export/packet stage
- Work involves healthcare, taxes, legal, finance, or identity data
- User asks "what can the agent do here?" or "where does the agent stop?"
- Setting up a new case workflow that involves sensitive data

## Allowed Actions (Agent May)

- Organize and ingest source documents
- Extract, normalize, and chunk data
- Draft letters, summaries, and responses
- Validate citations and run sanity checks
- Export packets for human review

## Forbidden Actions (Agent Must Not)

- Sign any document or form
- Send email, mail, or fax on behalf of the user
- File documents with any institution, agency, or court
- Submit claims, appeals, or applications
- Authorize payments or transfers
- Transmit sensitive data over any channel
- Delete or modify original source documents
- Take any action that creates a legal or financial commitment

## Review Checklist

Every exported packet must include a human review checklist:

```markdown
## Human Review Checklist

Before filing, sending, or submitting, confirm:

[ ] All cited claims match the source documents I've read
[ ] Dates, amounts, and codes are correct
[ ] No personally identifying information is exposed incorrectly
[ ] The draft letter accurately represents my situation
[ ] I understand and accept the unresolved questions listed
[ ] I am the one filing, sending, or submitting -- not the agent

Signed: ________________  Date: ________________
```

## Workflow Stop

The agent stops at packet export. The packet is the handoff artifact. Only a separate, human-initiated workflow may proceed to sending, filing, or submitting -- and that workflow must re-verify the packet content.

## Domain-Specific Disclaimers

Without burying the actual next step, include context-appropriate language:

- **Healthcare**: "This is not medical advice. A licensed professional should review before submission."
- **Tax**: "This is not tax advice. A qualified preparer should review before filing."
- **Legal**: "This is not legal advice. An attorney should review before use."
- **Finance**: "This is not financial advice. Verify all figures before acting."

## Verification

Run against a sample packet. Show where the workflow stops (at export). Confirm the checklist is included and the forbidden actions are clear.
