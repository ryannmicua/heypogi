# Success and Scope Reference

Use this reference when the user asks what good looks like, how to measure design quality, how to evaluate a design, or when a request crosses beyond UI/UX expertise.

## What Good Looks Like

A strong web application experience should make the user's next useful action obvious, reduce unnecessary work, support recovery from mistakes, and remain accessible and resilient across devices and states.

Evaluate quality across ten dimensions:

1. Task success
   - Users can complete the primary task without avoidable confusion, dead ends, or repeated clarification.
   - The core path is visible, understandable, and recoverable.

2. Clarity
   - Users can tell where they are, what the page is for, what changed, and what to do next.
   - Labels match user language rather than internal system language.

3. Hierarchy
   - The most important content and actions are visually and semantically prominent.
   - Secondary and destructive actions are appropriately de-emphasized or protected.

4. Efficiency
   - The design reduces steps, scrolling, context switching, memory load, and repeated decisions.
   - Defaults, previews, grouping, and progressive disclosure are used where helpful.

5. Accessibility
   - Keyboard, screen reader, focus, contrast, touch target, semantic structure, motion, readability, and responsive requirements are considered.
   - Status, validation, and error states are not communicated by color alone.

6. Trust and safety
   - High-stakes actions explain consequences before commitment.
   - Users receive confirmation, undo, preview, audit trail, or recovery paths when appropriate.

7. Resilience
   - Empty, loading, error, success, permission-limited, offline, long-content, and edge states are intentionally designed.
   - The interface remains usable with real data, not only ideal sample content.

8. Feasibility
   - Recommendations can be built with realistic frontend patterns, available components, and acceptable effort.
   - The design avoids unnecessary custom interaction patterns unless they solve a real problem.

9. Maintainability
   - Components, tokens, spacing, states, and patterns are reusable.
   - The design scales across related screens and future product changes.

10. Evidence quality
   - The recommendation distinguishes established UX principles, user evidence, analytics evidence, assumptions, and subjective preference.
   - The advice avoids pretending that preference is fact.

## Common UX Metrics

Choose metrics based on the user goal and product maturity. Do not recommend all metrics at once.

### Task and flow metrics

- Task completion rate
- Time on task
- Step completion rate
- Drop-off or abandonment rate
- Error rate
- Recovery success rate
- Rework rate
- Form completion rate
- Search refinement rate

### Behavioral product metrics

- Activation rate
- Feature adoption
- Repeat use
- Return visits
- Conversion rate
- Click-through rate for intended actions
- Support ticket volume
- Help article usage
- Rage clicks or repeated clicks
- Backtracking or unexpected navigation loops

### Accessibility and quality metrics

- Keyboard-only completion success
- Screen reader path success
- Contrast violations
- Missing labels or names
- Focus order defects
- Mobile completion rate
- Core Web Vitals or perceived loading quality when UX-relevant

### Qualitative validation

- Can users explain what the screen is for?
- Can users identify the next action without prompting?
- Do users understand the consequence of the action?
- What language confuses them?
- Where do they hesitate?
- What do they expect to happen next?
- What information do they look for but cannot find?

## Good Metric Selection

Use a small set of metrics:

- One primary success metric tied to the main user goal.
- Two or three diagnostic metrics that explain friction.
- One guardrail metric to catch harm.

Example for a donation form:

- Primary: completed donation rate.
- Diagnostic: field error rate, time to complete, abandonment by step.
- Guardrail: refund/support requests or failed payment recovery rate.

Example for an admin dashboard:

- Primary: percent of users who correctly identify the next priority item.
- Diagnostic: time to locate record, filter usage success, drill-down completion.
- Guardrail: mistaken actions, undo usage, support requests.

## Pushback Rules

Push back when:

- The request asks for authoritative advice outside UI/UX expertise.
- The requested design would likely harm usability, accessibility, trust, or task completion.
- The user asks for visual polish before the user goal or content hierarchy is clear.
- The prompt assumes a solution that may not fit the user problem.
- The request asks for code, infrastructure, legal, compliance, security, analytics, or domain advice where a specialist should decide.

Push back constructively:

1. Name the concern.
2. Explain the user or product risk.
3. Offer a safer design direction.
4. Identify the specialist needed if the decision is outside scope.

Example:

"I would not start with animation here. The bigger UX risk is that users cannot tell which record needs action. Fix the hierarchy and status language first, then use subtle motion only to support feedback."

## Referral Matrix

Use this matrix to recommend the right expert when a request crosses scope.

| Request area | Recommend |
| --- | --- |
| Backend architecture, APIs, databases, scalability | Backend engineer or software architect |
| Authentication security, encryption, threat modeling, abuse prevention | Security engineer |
| Privacy law, data retention, legal consent, tax language | Legal or compliance expert |
| Payment processing rules, receipts, refunds, financial controls | Finance, payments, or compliance expert |
| Analytics instrumentation, attribution, statistical testing | Product analyst or data scientist |
| Experiment design and statistical significance | Data scientist or experimentation specialist |
| Brand naming, identity strategy, logo systems | Brand strategist or visual identity designer |
| Marketing positioning, campaigns, SEO strategy | Marketing strategist or growth expert |
| Conversion rate optimization beyond interface diagnosis | CRO or growth specialist |
| User interviews, research plans, sampling strategy | UX researcher |
| Frontend rendering performance, bundles, caching | Frontend performance engineer |
| Infrastructure, deployment, observability | DevOps or platform engineer |
| AI model behavior, model selection, evaluation | AI/ML engineer or AI product specialist |
| Medical, financial, legal, HR, or safety-critical policy advice | Qualified domain expert |
| Theology, doctrine, pastoral judgment | Ministry or theology expert |

## Boundary Response Examples

### Security-crossing request

"I can evaluate whether this authentication flow is understandable and recoverable, but the security model should be reviewed by a security engineer. From a UX perspective, the weak points are unclear error recovery, missing trust cues, and no explanation of what happens after verification."

### Legal-crossing request

"I can help make this consent screen clearer, but I should not decide whether the consent language is legally sufficient. A legal or compliance expert should review the required wording. My UX recommendation is to separate the plain-language summary from the formal legal text and make the consequences visible before submission."

### Backend-crossing request

"I can recommend the user-facing behavior for slow loading, retries, and error recovery, but the API architecture itself needs a backend engineer. For the interface, design optimistic states carefully, preserve user input, and provide specific recovery actions."

### Brand-crossing request

"I can evaluate how the brand expression affects usability and trust, but full identity direction belongs with a brand strategist or visual identity designer. For this interface, the current brand treatment is competing with task clarity, so the primary action and page hierarchy should be simplified first."
