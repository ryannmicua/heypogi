# Memory Rules

Global memory lives under the Agentic Delivery System home in `memory/`.

## Resolve System Home

Resolve in this order:

1. `AGENTIC_DELIVERY_SYSTEM_HOME`
2. nearest ancestor `.agentic-delivery/config.json` with `system_home`
3. current directory or ancestor containing `memory/schema.md`

If no system home is found, do not write memory. Ask the user to set `AGENTIC_DELIVERY_SYSTEM_HOME` or create `.agentic-delivery/config.json`.

## Storage Paths

| Path | Purpose |
|---|---|
| `memory/proposed/` | Memory proposals awaiting review or auto-accept processing. |
| `memory/approved/` | Accepted memory records. |
| `memory/rejected/` | Rejected memory records retained for audit and learning. |
| `memory/review_log.md` | Append-only review log for all memory decisions. |

## Categories

- User delivery preference
- Project archetype
- Failure pattern
- Successful pattern
- Risk rule
- Tooling preference
- Mode decision

## Sensitivity Classes

| Class | Meaning | Default action |
|---|---|---|
| Low | Non-sensitive, reusable, and does not affect permissions, security, mode, or commitments. | May auto-accept after checks. |
| Medium | Reusable but may contain project-specific context, process commitments, or broad guidance. | Human review required. |
| High | Affects security, privacy, compliance, approval boundaries, operating modes, permissions, production data, or infrastructure. | Human approval required. |
| Prohibited | Contains secrets, credentials, private keys, production data, sensitive personal data, full source files, or unnecessary proprietary details. | Reject or rewrite without prohibited content. |

## Auto-Accept Rule

Auto-accept only when all are true:

- sensitivity class is Low
- content is reusable beyond one task
- evidence is explicit
- no approval boundary is changed
- no operating mode is changed
- no security or project commitment is created
- no prohibited content is present
- decision is recorded in `memory/review_log.md`

## Human Review Rule

Human review is required when memory:

- changes or recommends operating modes
- affects approvals, permissions, security, privacy, compliance, authentication, authorization, infrastructure, secrets, or production data
- contains project-specific commitments
- contains proprietary details beyond reusable learning
- has unclear sensitivity
- is classified Medium or High

## Read Policy

Approved memory may guide recommendations. Proposed memory is pending context only. Rejected memory may be used as audit evidence but must not become guidance.
