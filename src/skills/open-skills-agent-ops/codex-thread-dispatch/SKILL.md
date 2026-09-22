---
name: codex-thread-dispatch
description: "Dispatch bounded work to a separate Codex task, choose the correct project and checkout state, and supervise the handoff through startup and completion. Use when the user explicitly asks to hand off, delegate, or open a new Codex session for repository work."
---

# Codex Thread Dispatch

Use this skill when the user explicitly asks for a separate Codex task, chat session, or agent handoff. The current agent remains responsible for translating the request, selecting the execution context, confirming startup, and reporting the result.

Do not use this skill for ordinary implementation in the current task, hidden background work, scheduled automation, or terminal/tmux/OpenCode delegation. Those workflows use their own mechanisms.

## Dispatch rules

1. Make the handoff bounded. Identify the objective, files or project in scope, definition of done, verification gates, and stop conditions. Preserve the user's intent and do not delegate an unresolved design decision as if it were mechanical work.
2. Call `list_projects` before creating a project task. Select the exact returned project; never invent a project id, branch, host, or path. Check whether the project is a Git repository.
3. Use a managed worktree for Git repositories by default. Use a local checkout for non-Git projects. Use a local checkout for a Git repository only when the user explicitly wants the delegate to work in the shared checkout or the task must include current uncommitted changes and that shared access is acceptable.
4. If current uncommitted changes are required, use the worktree `startingState` of `working-tree` only when the API can resolve that state. If setup fails, do not retry the same payload repeatedly. Either use the explicitly authorized local checkout or report the limitation and ask for direction.
5. Create the task with `create_thread`. The project id belongs inside `target`, not at the top level:

   ```json
   {
     "target": {
       "type": "project",
       "projectId": "<id returned by list_projects>",
       "environment": {
         "type": "worktree"
       }
     },
     "prompt": "<self-contained handoff prompt>"
   }
   ```

   Add `startingState` only when the user requested a particular Git state. Omit `model` and `thinking` unless the user explicitly requests them. Add a concise `title` when it improves discoverability.

## Handoff prompt

Write the initial prompt for an agent with no access to the current conversation. Include:

- **Objective:** the concrete result to produce;
- **Definition of done:** observable completion criteria;
- **Scope:** exact project, files, systems, or boundaries;
- **Constraints:** relevant repository instructions, authority limits, and preservation rules;
- **Verification:** commands or inspections and what counts as passing;
- **Stop conditions:** when to stop and ask the user rather than guessing;
- **Report:** changed files, verification evidence, deviations, and unresolved issues.

Tell the delegate whether it may edit, create, delete, commit, push, open a pull request, or make external changes. Do not grant permissions that the user did not request. Do not include transient tool failures or speculative context unless it changes the delegate's decisions.

## Startup confirmation

After a successful `create_thread` call:

1. Emit `::created-thread{threadId="..."}` in the final response on its own line.
2. Wait once for an initial status using `wait_threads`, including the returned `threadId` and `hostId`. A short bounded wait is enough to confirm that the task is active or needs attention.
3. Report the task title or purpose, selected project/environment, and whether the delegate started successfully.

If creation fails because of invalid arguments, inspect the schema and correct the payload once. Common errors include putting `projectId` at the top level instead of inside `target`, inventing a starting branch, or selecting an environment incompatible with the project. Do not keep retrying an unchanged request.

## Supervision and follow-up

Use `wait_threads` with the latest cursor for progress monitoring. Prefer one bounded wait over repeated unchanged reads. Use `read_thread` when detailed output is needed, and use `send_message_to_thread` only for a clear correction, clarification, or next step.

When the task completes, review the delegate's report against the definition of done. For repository work, inspect the resulting diff and run the stated verification checks in the relevant checkout. Do not report completion solely because the delegate says it is done.

If the delegate requests a decision, encounters a scope conflict, or needs authority the user did not grant, stop and bring that decision to the user. Do not silently expand the handoff.
