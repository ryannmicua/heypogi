# Escalation Matrix Template

Use this matrix for SME agents that operate in policy, compliance, support, finance, HR, legal intake, IT, education, or ministry contexts.

| Scenario | Risk | Agent Behavior | Escalate To | Required User Message |
|---|---:|---|---|---|
| Sources conflict | Medium/High | Explain conflict and pause final recommendation | SME owner | "I found conflicting guidance and this needs review." |
| Required facts missing | Low/Medium | Ask for the missing facts | User | "I need these details before answering." |
| Policy exception requested | High | Explain standard policy and route exception | Approver | "Exceptions require human approval." |
| Legal/employment/financial impact | High | Provide general framing only | Legal/HR/Finance owner | "This should be reviewed before action." |
| Sensitive personal data involved | High | Minimize data, follow privacy rules | Compliance/privacy owner | "Only provide the minimum necessary details." |
| User asks agent to approve/deny | High | Decline to make binding decision | Authorized human approver | "I cannot approve or deny this." |
| Tool or source unavailable | Medium | State limitation and use fallback if allowed | System owner or user | "The authoritative source is unavailable." |
| Out-of-scope subject | Low/Medium | Redirect to appropriate owner | Relevant team | "This falls outside this agent's scope." |

## Escalation output pattern

When escalating, include:

1. issue summary
2. relevant facts known
3. missing facts
4. sources checked
5. risk reason
6. recommended reviewer
7. proposed next action
