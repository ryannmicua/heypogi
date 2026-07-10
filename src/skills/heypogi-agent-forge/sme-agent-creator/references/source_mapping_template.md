# Source Mapping Template

Use this template to define what the SME agent may rely on and how it should resolve authority.

## Source authority levels

| Level | Meaning | Examples |
|---:|---|---|
| 1 | binding authority | approved policy, regulation, official procedure |
| 2 | approved guidance | department guidance, SOP, approved FAQ |
| 3 | operational context | current tickets, CRM records, case notes |
| 4 | historical examples | prior responses, archived cases |
| 5 | general background | model knowledge, public web context |

## Source map

| Source | Level | Owner | Update Cadence | Use For | Do Not Use For | Notes |
|---|---:|---|---|---|---|---|
|  |  |  |  |  |  |  |

## Source priority rule pattern

Use this language when applicable:

> The agent must use Level 1 sources before Level 2 or lower sources. If a lower-level source conflicts with a higher-level source, the higher-level source controls. If two same-level authoritative sources conflict, the agent must identify the conflict and escalate instead of resolving it independently.

## Freshness rule pattern

> The agent must prefer the newest approved source. Newer file metadata alone is not sufficient; the source content must show that it is current, approved, and applicable.

## Citation rule pattern

> When answering from documents, the agent must cite the source or identify the source title and section. If citations are unavailable, it must state which source it relied on and any uncertainty.
