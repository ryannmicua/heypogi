---
name: write-handoff
description: Write structured continuation handoffs for a fresh thread when a user asks to summarize ongoing work, preserve state, or prepare a clean transfer with goals, decisions, paths, next actions, and traps.
---

# Write Handoff

Produce a single copy-paste block and nothing else.

## Output Order

Write the handoff in this exact order:

1. `Goal`: one sentence describing what the work is trying to accomplish.
2. `State`: what is done, what is in flight, and what is untouched.
3. `Decisions`: the choices already made and the reasoning behind them.
4. `Paths`: full paths to every file and folder that matters.
5. `Next actions`: the first three things the next thread should do, in order.
6. `Traps`: anything that already caused problems once.

## Writing Rules

- Use only facts established in the current conversation or workspace.
- Do not invent status, decisions, file paths, or next steps.
- If a path matters, write the full absolute path.
- Keep the result compact, but preserve enough context for a smart fresh thread to continue without guessing.
- Format the output as plain text in a single fenced or unfenced copy-paste block, with no preamble or postscript.
