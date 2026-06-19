# Source Authority and Trusted References

## Source authority levels

| Level | Meaning | Examples |
|---:|---|---|
| 1 | binding project truth | current repository, tests, CI/CD config, production telemetry, approved engineering standards, accepted ADRs |
| 2 | approved operational context | active tickets, epics, runbooks, deployment guides, incident reviews |
| 3 | official external standards | ISO/IEC/IEEE, NIST, OWASP, SLSA, OpenSSF, ACM |
| 4 | respected industry guidance | Google Engineering Practices, Google SRE, DORA, OpenTelemetry, vendor well-architected frameworks |
| 5 | informal context | blogs, tutorials, forum answers, Stack Overflow, model memory |

## Priority rules

1. Use Level 1 before all lower levels.
2. Use Level 2 for scope, operational process, and delivery context.
3. Use Level 3 when internal sources are silent or defer to external standards.
4. Use Level 4 for patterns, heuristics, and review rubrics.
5. Use Level 5 only as non-authoritative context.
6. If a lower-level source conflicts with a higher-level source, the higher-level source controls.
7. If two same-level authoritative sources conflict, identify the conflict and escalate.
8. Prefer the newest approved source, but do not trust metadata alone. The content must show that it is current, approved, and applicable.
9. Do not use deprecated drafts unless the user asks for historical analysis.
10. Cite or identify the source basis whenever answering from documents, code, logs, or standards.

## Project-local truth

Prefer current, inspectable system evidence:

- source code
- tests
- package manifests
- API schemas
- database migrations
- infrastructure-as-code
- CI/CD definitions
- build results
- deployment records
- logs, metrics, and traces
- architecture decision records
- engineering standards
- runbooks
- incident reports
- active tickets and acceptance criteria

Do not claim what the code, tests, CI, or production system does unless inspected or provided by the user.

## External reference stack

Use these as external references when project-local sources do not answer the question.

| Area | Reference | Use for |
|---|---|---|
| Software engineering body of knowledge | SWEBOK Guide | broad software engineering terminology and knowledge areas |
| Requirements engineering | ISO/IEC/IEEE 29148 | requirement quality, traceability, acceptance criteria, requirements information items |
| Architecture description | ISO/IEC/IEEE 42010 | viewpoints, stakeholder concerns, architecture descriptions, ADR structure |
| Software quality model | ISO/IEC 25010 / SQuaRE | quality attributes: functional suitability, performance, compatibility, usability, reliability, security, maintainability, portability |
| Secure development | NIST SP 800-218 SSDF | secure SDLC practices and software producer responsibilities |
| Application security verification | OWASP ASVS | web/API security requirements and verification checks |
| Software supply chain | SLSA | provenance, build integrity, artifact trust, CI/CD supply-chain levels |
| Open-source risk | OpenSSF Scorecard | dependency and open-source project security posture |
| Code review | Google Engineering Practices | reviewer behavior, review quality, PR feedback discipline |
| Reliability engineering | Google SRE books/resources | SLOs, monitoring, alerting, incident response, postmortems, launch readiness |
| Delivery performance | DORA research | delivery health, deployment frequency, lead time, change failure rate, recovery time |
| Observability | OpenTelemetry documentation | traces, metrics, logs, semantic conventions, instrumentation |
| Cloud architecture | relevant cloud Well-Architected Framework | workload review for the actual cloud provider only |
| Professional responsibility | ACM Code of Ethics | public interest, harm avoidance, honesty, privacy, professional responsibility |

## Sources to avoid as primary authority

Do not use these as primary references when higher-quality sources are available:

- Stack Overflow answers
- Reddit threads
- old blog posts
- vendor marketing pages
- generated tutorials
- outdated framework docs
- unversioned PDFs
- copied diagrams without owner or date
- benchmark claims without methodology
- uncited “best practices”

## Source basis block

Include this block when recommendations depend on incomplete or mixed sources:

```markdown
## Source Basis

- Repo evidence:
- Internal standard:
- External standard:
- Vendor documentation:
- Operational evidence:
- General engineering judgment:
- Assumptions:
```
