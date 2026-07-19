# Evaluation examples

These examples illustrate judgment and revision style. Do not copy their scores mechanically.

## Example 1: vague general prompt

### Input

> You are a helpful assistant. Always be concise. Research the issue thoroughly and answer the user. Never ask questions. Always use every tool available. Keep searching until you are completely certain.

### Key findings

- **Major — outcome missing:** “answer the user” does not define the task or completion bar.
- **Major — contradictory stopping behavior:** “be concise,” “research thoroughly,” and “keep searching until completely certain” provide no evidence threshold or stopping rule.
- **Major — poor tool routing:** “use every tool” exposes irrelevant tools and wastes calls.
- **Major — unjustified absolute:** “never ask questions” blocks the smallest necessary clarification.
- **Minor — generic personality:** “helpful” does not define observable writing or collaboration behavior.

### Minimal revision

> Resolve the user's request using the available evidence. Use only tools relevant to a required fact or action. Ask for the smallest missing field only when the request cannot be completed safely or correctly without it. Stop when the core request is supported and complete; do not continue searching for optional detail. Lead with the answer and include material evidence, caveats, and next action.

## Example 2: coding agent prompt

### Input

> Fix the bug in the repository. Do not change anything else. Ask before editing any file. Run all tests. Never stop until all tests pass.

### Key findings

- **Major — approval friction:** a request to fix authorizes in-scope local edits, but “ask before editing any file” forces unnecessary pauses.
- **Major — impossible validation contract:** “all tests” may be unavailable, expensive, or contain unrelated failures.
- **Major — unsafe persistence:** “never stop” lacks fallback behavior.
- **Minor — scope ambiguity:** “anything else” should distinguish necessary supporting changes from unrelated refactors.

### Minimal revision

> Diagnose and fix the reported bug with the smallest in-scope code change. You may inspect files, edit affected code, and run non-destructive validation without asking first. Avoid unrelated refactors or feature changes. Run the most relevant targeted tests, then applicable type, lint, build, or smoke checks. If a check cannot run or an unrelated failure remains, report it with the evidence and stop rather than expanding scope.

## Example 3: grounded research prompt

### Input

> Find everything about the vendor and write a definitive assessment. Use citations. If you cannot find evidence, say the vendor does not have that capability.

### Key findings

- **Major — unbounded retrieval:** “everything” has no coverage or stop condition.
- **Critical — evidence inversion:** absence of retrieved evidence is treated as proof that the capability does not exist.
- **Major — undefined citation contract:** the prompt does not state which claims require support or how to handle conflicting sources.

### Minimal revision

> Assess the vendor against the stated requirements using retrieved sources. Start with a broad search, then make additional retrieval calls only for required facts that remain unsupported or for named artifacts that must be read. Cite each material factual claim from retrieved evidence, distinguish inference from direct support, and state source conflicts. When evidence is missing, label the requirement unverified rather than concluding that the capability does not exist.
