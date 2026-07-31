---
name: supervisor-prompt-builder
description: Generate a structured supervisor/deepseek prompt from a project's issue register and conventions. Use when the user asks for a "deepseek prompt", "supervisor prompt", "orchestrator prompt", or wants to encode an issue-resolution workflow as a prompt an external model can follow turn by turn.
---

# Supervisor Prompt Builder

Produces a complete, standalone prompt that instructs an AI (DeepSeek or any agentic model) to act as a **supervisor** — pick an open issue, delegate to subagents (brainstorm → plan → implement), and wrap up.

## Process

Follow these steps in order. Do not skip any.

### Step 1: Gather project context

Read the project's conventions and entry points:

- `AGENTS.md` — build system, test commands, architecture, quirks
- `README.md` (if exists) — project overview
- Relevant manifest files — `package.json`, `Cargo.toml`, etc.

Collect:
- Test command (e.g., `npm test`)
- Start command (e.g., `npm start`)
- Code conventions (framework, dependencies, module system)
- Architecture summary (key files and their roles)

### Step 2: Read the issue register

Read `docs/issue-register.md` (or similar). Identify all **Open** issues with their ID, area, description, expected behavior, and priority.

### Step 3: Check available agent/skill infrastructure

Look at which CE skills exist (`ce-brainstorm`, `ce-plan`, `lfg`, `ce-debug`, etc.) and their descriptions. Also check the `wrapup` skill location and convention. If the project has custom agents or subagents, note those too.

### Step 4: Build the prompt

Compose the prompt using this template. Fill in the bracketed sections from Steps 1–3.

```text
**Context:** You have access to [project path]. The project conventions
are documented in AGENTS.md — [key conventions: test command, start command,
no-deps, ESM, etc.]. The issue register is at docs/issue-register.md.

**Role:** You are a supervisor agent. Your job is to resolve one open issue
from the issue register by orchestrating subagents in sequence. You do not
implement anything yourself — you delegate.

**Workflow — execute in order:**

1. **Pick one issue** from the register. Choose the highest-priority open
   issue. State your choice and why.

2. **Delegate `ce-brainstorm`** — Ask a subagent to explore the issue,
   understand the relevant code, and generate solution approaches. Give
   them the full issue details, relevant file paths (grep for related code
   first), and the project conventions. Wait for their output.

3. **Delegate `ce-plan`** — Give the brainstorm output to a subagent and
   ask for a concrete implementation plan with file-by-file steps, test
   expectations, and verification criteria. Review and approve or send back
   for revision.

4. **Delegate `lfg`** — Give the approved plan to `lfg` to implement,
   commit, push, and open a PR. Do not intervene unless it fails. If it
   fails, diagnose and re-delegate.

5. **Verify** — Check that the PR CI passes and tests pass. If not, debug
   using `ce-debug` and re-delegate.

6. **Run `/wrapup`** — Once satisfied, kick off the wrapup skill: session
   digest, git summary, compound any solutions, report.

**Rules:**
- You do not write code or edit files yourself.
- You give subagents full context: issue ID, relevant file paths and line
  numbers, code conventions, test commands.
- You make decisions subagents cannot (issue selection, plan approval,
  go/no-go on PR, merge readiness).
- If a subagent asks a question you cannot answer, go read the relevant
  code/files and respond.
- Keep the session moving — don't block on perfection. A working PR is
  the goal.
- At the end, present a clean summary of what was done, which issue was
  resolved, and what PR was opened.
```

### Step 5: Output

Present the final prompt in a fenced code block so the user can copy it directly. The prompt must be self-contained — the target model should be able to follow it with no additional context from the user.

## Example

```
**Context:** You have access to C:\Users\rmicua\...\ITS Sofa.
The project conventions are documented in AGENTS.md — no npm deps, ESM,
Node built-in http server on port 3000, tests via `npm test` (node --test
+ node --check). The issue register is at docs/issue-register.md.

**Role:** You are a supervisor agent...
```
