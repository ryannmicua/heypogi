---
name: goal-prompt-generator
description: Transform an implementation plan or task description into a bounded goal prompt another agent session can pursue autonomously and be checked against. Use when packaging work for another session, writing a goal prompt, or preparing a task for autonomous execution.
---

# Goal Prompt Generator

Turn fuzzy work into a bounded, autonomous objective that another agent session can execute and be verified against — without sharing conversation context.

## Trigger Conditions

- User asks to package work for another session
- User asks to write a goal prompt
- User asks to prepare a task for autonomous execution
- User says "make this executable by another agent"

## Required Structure

Every goal prompt must include these sections:

### 1. Objective
One paragraph describing what the agent must accomplish. Self-contained — no back-references to this conversation.

### 2. Definition of Done
A checklist of verifiable, pass/fail statements. Every item must be checkable without re-deriving the plan. Example:
- [ ] File `src/foo.ts` exports `bar()` with signature `(x: number) => string`
- [ ] `npm test` passes with zero failures
- [ ] No new `console.log` or `debugger` statements remain

### 3. Repo Constraints
- **May modify**: exact files, directories, or patterns the agent may touch
- **Must NOT touch**: files, directories, or patterns that are off-limits — include config, generated code, unrelated modules, and sensitive paths

### 4. Verification Gates
Exact commands to run and expected results before claiming completion. Examples:
- Run `npm run lint` — must exit 0
- Run `npm test -- --coverage` — no regressions, coverage must not drop
- Run `npm run build` — must produce output at `dist/`

### 5. Stop Conditions
Situations where the agent must halt and ask instead of improvising:
- Test failure that is not obviously related to changes
- Need to modify a file outside the "may modify" list
- Ambiguity in the definition of done
- Discovery that the plan is infeasible or underspecified

## Self-Containment Rule

The receiving session has none of this conversation's context. The prompt must include:
- Exact file paths (never "the config file we discussed")
- All necessary background (never "as we talked about")
- Concrete values, not references to earlier decisions

## Quality Check

Before delivering, ask: "Could a competent agent with zero context execute this, and could I verify the result without re-deriving the plan?" If either answer is no, revise until both are yes.
