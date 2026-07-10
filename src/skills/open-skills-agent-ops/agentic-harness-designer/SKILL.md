---
name: agentic-harness-designer
description: Design or review agent-powered systems and products by walking the real architecture questions and producing a phased plan. Use when designing, evaluating, or debugging any AI-agent-powered product, tool, or serious automation.
---

# Agentic Harness Designer

A design-review skill for building agent-powered products and systems. When the problem is "how should this AI system actually work," walk the real architecture questions — treating the problem as an agent-system problem, not a model-choice problem. The model matters less than the harness around it.

## Trigger Conditions

- Designing an AI-agent-powered product, tool, or automation
- Evaluating an existing agent system
- Debugging a system where agents behave unpredictably
- User asks "how should this AI system work?"
- User describes a new automation or agent workflow

## Design Walk (In Order)

### 1. Tool Design
What tools does the agent get, and what are their exact contracts?
- Tool name, parameters, return type, side effects
- What each tool is allowed to do vs. not do
- Error modes and how the agent should handle them

### 2. Permission Model
- **Autonomous**: actions the agent takes without asking
- **Approval-gated**: actions that require human confirmation before execution
- **Forbidden**: actions the agent must never take (and ideally, tools it doesn't have)
- State the approval boundary explicitly — be specific about which operations fall where

### 3. Workflow State and Durability
- What survives a crash or restart?
- Where does workflow state live (filesystem, database, in-memory)?
- Can a session be resumed from where it left off, or does it start over?
- What happens to in-flight work if the harness process dies?

### 4. Context and Memory Strategy
- What does the agent know and from where? (system prompt, RAG, tool output, conversation history)
- What must the agent NOT accumulate? (unbounded conversation logs, stale facts, sensitive data)
- How is context trimmed or summarized when it grows too large?
- Is there a persistent memory layer (vector DB, knowledge base, file system)?

### 5. Evaluation
- Concrete checks that prove the system works — not vibes, not "looks good"
- Test suites for tool behavior, prompt adherence, output format
- Regression tests for known failure modes
- Success metrics: accuracy, latency, cost, completion rate
- How often evals run (per-change, nightly, pre-release)

### 6. Observability
- What is logged: tool calls, decisions, errors, durations, costs
- What the operator can see mid-run: live logs, dashboard, session replay
- Alerting for: stuck loops, permission boundary hits, cost spikes, error rate increases
- Audit trail: can you reconstruct what the agent did and why?

## Failure-Mode Review

Check the design against the common killers:

| Failure Mode | Check |
|-------------|-------|
| Missing approval gates | Can the agent delete data, spend money, or send messages without confirmation? |
| Non-durable state | If the harness crashes, is work lost or safely suspended? |
| Unbounded context growth | Does the agent accumulate conversation history until it breaks or gets expensive? |
| No evals | How do you know it still works after the next prompt change? |
| Invisible execution | Can you see what the agent is doing while it's doing it, or only after? |

## Output

Produce a design document with:
1. **Architecture decisions and rationale** — what you chose and why
2. **Phased implementation plan** — each phase independently shippable and testable
3. **Risk register** — what could go wrong, likelihood, mitigation

Phases should follow this pattern:
- Phase 1: Minimal viable harness — one tool, one workflow, observable
- Phase 2: Add tools, expand autonomy gradually
- Phase 3: Polish, evals, monitoring
- Each phase ships something useful on its own
