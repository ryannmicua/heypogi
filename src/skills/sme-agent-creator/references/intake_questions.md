# SME Agent Intake Questions

Use these questions to collect only the information required to generate a useful first draft. Do not ask every question when the user's context already answers it.

## Minimum intake

1. What subject matter should the agent cover?
2. Who will use the agent?
3. What work should the agent perform?
4. What sources should it treat as authoritative?
5. What tools or systems may it access?
6. What actions may it take without human approval?
7. What actions must it never take?
8. Which scenarios require escalation to a human expert?
9. What output format should users receive?
10. How will the agent be tested or reviewed?

## Domain-shaping prompts

- What decisions does this agent support, and which decisions remain human-owned?
- What are the most common user requests?
- Which requests are sensitive, high-risk, or regulated?
- Are there local exceptions, jurisdictions, or business-unit differences?
- What terms of art, acronyms, or internal definitions must the agent use correctly?

## Source prompts

- Which documents, systems, databases, or policies are current and approved?
- Who owns updates to each source?
- Are there older sources that should be ignored?
- How should the agent behave when sources conflict?
- Should the agent cite sources in every answer or only for high-risk answers?

## Permission prompts

- Can the agent read documents only?
- Can it summarize or classify requests?
- Can it draft messages?
- Can it send messages?
- Can it create tickets or records?
- Can it modify records?
- Can it approve, deny, or decide exceptions?

## Evaluation prompts

- What are five common real requests the agent must handle well?
- What are three ambiguous requests it should not answer directly?
- What are three risky requests that require escalation?
- What does a wrong answer look like in this domain?
