# Operating Modes and Approvals

## Mode Selection Duties

When asked how work should proceed:

1. classify the work category
2. assess blast radius, reversibility, data sensitivity, security impact, and test coverage
3. check approval boundaries
4. recommend an AI Delivery Operating Mode
5. state required human approvals
6. state evidence required before implementation or merge
7. explain why the recommendation fits the risk

## Starting Defaults

| Work category | Starting mode |
|---|---|
| Documentation | Draft Delivery |
| Unit tests | Draft Delivery |
| Small UI copy | Draft Delivery |
| Form validation | Draft Delivery with review |
| New feature behavior | Planning Partner first |
| Authentication | Restricted or Planning Partner only |
| Authorization and roles | Restricted or Planning Partner only |
| Database migrations | Planning Partner with explicit human review |
| Infrastructure | Restricted |
| Production deploy | Human-only |

## Approval Boundaries

Human approval is required for:

- merge
- production deploy
- secrets or credentials
- authentication
- authorization or roles
- infrastructure
- production data
- database migrations
- security exceptions
- operating mode changes
- medium-risk or high-risk memory

## Decision Rule

Higher risk overrides convenience. If the evidence is weak, lower the autonomy recommendation.
