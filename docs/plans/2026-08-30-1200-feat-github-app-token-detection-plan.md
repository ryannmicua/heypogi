---
title: GitHub App Token Detection and PAT Fallback - Plan
type: feat
date: 2026-08-30
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** Skills that request Copilot code reviews detect when `gh` CLI is authenticated with a GitHub App installation token and either use a PAT override or stop with setup instructions, so the Copilot review step does not silently fail.
- **Means:** Add token-type detection (reading the first 4 characters of `gh auth token`) to `request-copilot-code-review` and `lfg-ship` skills. GitHub App installation tokens (`ghs_` prefix) trigger a PAT fallback path using `GH_TOKEN` env var override; every other result - classic PAT (`ghp_`), fine-grained PAT (reads as `gith`), OAuth (`gho_`), or an empty/unrecognized read - passes through unchanged.
- **Authority:** Session-settled in the invoking conversation - the token triage approach and the `GH_TOKEN` override were decided by the user and agent together.
- **Stop conditions:** Both skills classify the `ghs_` prefix versus everything else. PAT override only fires for `ghs_`. Under an App token with no PAT configured the skill stops (hard gate) with setup instructions; it does not offer to continue.
- **Execution profile:** Two skill file edits, one new secrets reference document, one new committed `.env.example` template, and a `.gitignore` check (`.env` is already ignored).

## Product Contract

### Summary

When `gh` CLI uses a GitHub App installation token, `gh pr edit --add-reviewer "@copilot"` fails because GitHub Apps cannot request reviews from other bots. The skills need to detect this and either substitute a user PAT or stop with setup instructions.

### Problem Frame

The `lfg-ship` skill chains through `request-copilot-code-review` to request Copilot reviews on PRs. Both skills assume `gh` is authenticated with a user token. When the agent runs under a GitHub App installation (`ghs_` prefix), the review request silently fails or errors. The user discovered this because their machine uses a GitHub App credential for `gh` operations.

**Observed failure (capture before implementing):** Run `gh pr edit <PR> --add-reviewer "@copilot"` under the App token and paste the exact error and exit code here. This distinguishes a bot-to-bot restriction (which the PAT fallback fixes) from a missing Copilot license or an outdated CLI (which it does not - in that case the PAT path fails identically and the plan needs rework).

### Requirements

**Token Detection**

- R1. Skills detect the `gh` token type by reading the first 4 characters of `gh auth token` output. The read is truncated in-process (never echoed raw): `.Substring(0,4)` on PowerShell, `| head -c 4` on bash/zsh. The raw token is never printed to stdout, a transcript, or an error message.
- R2. The check classifies the App-token prefix versus everything else. The 4-character read yields: `ghs_` for GitHub App installation tokens (the only branch that triggers fallback), `ghp_` for classic PATs, `gith` for fine-grained PATs (`github_pat_...` truncated to 4 chars), `gho_` for OAuth / browser-flow tokens. An empty or unrecognized read is treated as the non-`ghs_` case. The last three prefixes and the empty case are documented for operator context only; none of them branch.
- R3. Only `ghs_` triggers the fallback path. Every other result - including an empty or unrecognized read - proceeds with the normal command.

**PAT Fallback**

- R4. When `ghs_` is detected and `GH_PAT_COPILOT` env var is set, the skill prefixes the reviewer-request command with `GH_TOKEN="$GH_PAT_COPILOT"`. This applies to every request site: `gh pr edit <N> --add-reviewer "@copilot"`, the `gh pr create --reviewer @copilot` form, and the re-request command carried into the `lfg-ship` babysitter brief. The override is carried into the babysitter brief as unexpanded variable text (`GH_TOKEN="$GH_PAT_COPILOT" gh pr edit ...`), never as an interpolated value, so the credential is not written into a persisted subagent prompt. The babysitter re-checks the token prefix and that `GH_PAT_COPILOT` is set in its own environment before its first re-request, and stops with the R5 setup instructions if either check fails.
- R5. When `ghs_` is detected and `GH_PAT_COPILOT` is not set, the skill stops (hard gate - it does not offer to continue) and provides setup instructions: create a fine-grained PAT on github.com (Settings > Developer settings > Personal access tokens), scope to the repositories the operator ships from, grant `Pull requests: Read and write` permission, then set `GH_PAT_COPILOT` in the shell profile (`~/.bashrc` / `~/.zshrc` / PowerShell `$PROFILE`). Instructions use a placeholder (`GH_PAT_COPILOT=<your fine-grained PAT>`), not a literal `github_pat_...` value.

**Pre-flight Gate (lfg-ship only)**

- R6. `lfg-ship` runs the token check during Step 0 (before any work begins). If `gh` uses a GitHub App token without a PAT fallback configured, Step 0 stops (Copilot review is a hard gate for the pipeline) and reports the R5 setup instructions. It does not offer to continue - a run that skips its own review step is not a completed run.
- R7. The Step 0 stop message includes the setup instructions from R5 and the single re-check command the operator runs after configuring the PAT.
- R8. The isolation record (`tmp/lfg-ship-context.json`) includes a `copilot_token_mode` field with value `user-token` or `app-token-with-pat`. An empty or unrecognized token read records `user-token` and the pipeline proceeds normally (`app-token-no-pat` never reaches the record because R6 stops the run first).

**Failure Handling**

- R9. If a Copilot review request is issued and the reviewer-list check does not then show `@copilot` on the PR (request errored, PAT mis-scoped or expired, Copilot not licensed), `lfg-ship` stops Phase 2 and reports the setup instructions and the observed error to the operator.

**Secrets Reference**

- R10. A central secrets reference document lists every **secret-bearing credential** (PATs, OAuth tokens, API keys, App installation tokens) used by agent infrastructure on this machine - by name and purpose only, never a value. Non-secret environment variables (`HEYPOGI_ROOT`, `OPENCODE_CONFIG_DIR`, etc.) stay in `DEPENDENCIES.md`, which the project instructions name as the canonical env-var inventory. The two documents cross-link: `DEPENDENCIES.md` points to `docs/secrets-registry.md` for credentials, and the registry points back for non-secret vars. Each registry entry includes: variable name, description, why it is needed, when it is used, dependents, scope, and expiry/rotation.
- R11. The document lives at `docs/secrets-registry.md` and is structured for quick lookup by agents and humans.
- R12. The initial entry covers `GH_PAT_COPILOT`. The document is designed to grow by adding rows and columns, not by restructuring.

### Scope Boundaries

**In scope:**
- Token detection logic in both skills (shell-specific truncation, no raw echo)
- PAT override for every reviewer-request site: `gh pr edit --add-reviewer`, `gh pr create --reviewer`, and the `lfg-ship` babysitter re-request loop
- Step 0 hard-gate stop in `lfg-ship` when an App token has no PAT
- Isolation record schema update
- Failure mode entry
- Secrets reference document (`docs/secrets-registry.md`) covering secret-bearing credentials, cross-linked with `DEPENDENCIES.md`
- Committed `.env.example` template; `.gitignore` check (`.env` already ignored)

**Out of scope:**
- Modifying `gh` auth configuration
- Automating PAT creation
- Handling other GitHub App limitations beyond Copilot review requests
- Changes to the `lfg` skill (Phase 1 pipeline)

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Detection by reading the first 4 characters of `gh auth token`** - The `gh auth token` command outputs the raw token; the first 4 characters classify the `ghs_` App-token prefix versus everything else (`ghp_`, `gith` for fine-grained PATs, `gho_`, or an empty read - all non-branching). The truncation happens in-process so the raw token never reaches stdout or a transcript: `(gh auth token).Substring(0,4)` on PowerShell, `gh auth token | head -c 4` on bash/zsh. This is a read-only check with no side effects. (session-settled: user-directed - chosen over `gh api user` which returns bot identity but not token type)

- KTD2. **`GH_TOKEN` env var override** - The `gh` CLI respects `GH_TOKEN` as an auth override for individual commands. Prefixing `GH_TOKEN="$GH_PAT_COPILOT" gh pr edit ...` uses the PAT for that single call without changing the stored auth. This is non-destructive and reversible. (session-settled: user-directed - chosen over `gh auth login --with-token` which would change the stored auth globally)

- KTD3. **PAT stored as env var, not in config** - The PAT lives in `GH_PAT_COPILOT` environment variable, not in `gh` config or a dotfile. This keeps it out of version control and avoids conflicting with `gh auth` state. The user manages the env var through their shell profile or secrets manager. No runtime in this repo auto-loads a project `.env` file, so the shell profile (or an explicitly sourced file) is the supported source; `.env.example` is a naming reference only. Threat model is a single-operator machine: no just-in-time credential wrapper or cross-process redaction layer is in scope. (session note: substituting a human's PAT inside an unattended pipeline shifts action attribution for the reviewer request from the bot to the human - acceptable here, noted for the record.)

- KTD4. **`gh` shim pass-through** - This machine's `gh` shim injects a GitHub App installation token into every `gh` call. The `GH_TOKEN` override still works because the shim passes a caller-set `GH_TOKEN` through unchanged. The registry's When/Dependents columns name the shim so the interaction is discoverable.

### Assumptions

- `gh` CLI v2.88.0+ is installed (required for `@copilot` reviewer alias).
- The user has a GitHub account with Copilot code review enabled. **Verify before implementing:** run `gh pr edit <PR> --add-reviewer "@copilot"` under the App token and capture the actual error into the Problem Frame. If the cause is a missing Copilot license or an old CLI rather than a bot-to-bot restriction, the PAT path fails identically and the plan changes shape.
- The `GH_PAT_COPILOT` env var, when set, contains a valid fine-grained PAT with `Pull requests: Read and write` covering the repositories the operator ships from. The with-PAT mode asserts only that the variable is set, not that the token covers the current repo or is unexpired - a mis-scoped or expired token fails at the request, not at Step 0.
- `gh auth token` output starts with a 4-character prefix; `github_pat_...` truncates to `gith`, which is why R2 classifies the prefix rather than matching the full `github_pat_` literal.

---

## Implementation Units

### U1. Token detection and PAT fallback in request-copilot-code-review

**Goal:** Add a token-type check before the Copilot review request command, with PAT override for GitHub App tokens.

**Requirements:** R1, R2, R3, R4, R5

**Dependencies:** None

**Files:**
- `src/skills/dev-tool-reference/request-copilot-code-review/SKILL.md`

**Approach:**

1. Insert a new **Step 0: Token type check** section before the current Step 1 (line ~24). Also update the at-a-glance workflow block at the top of the skill so it starts at this check, not at "resolve the PR." Content:
   - Read the first 4 characters of `gh auth token`, truncating in-process (never echo the raw token): `(gh auth token).Substring(0,4)` on PowerShell, `gh auth token | head -c 4` on bash/zsh (guard the pipe against SIGPIPE under `set -euo pipefail`).
   - If the read is `ghs_`:
     - Check if `GH_PAT_COPILOT` env var is set.
     - If not set: **stop** with the setup instructions (create fine-grained PAT, scope to the repos you ship from, PR read/write permission, set the env var in the shell profile using a placeholder, not a literal token).
     - If set: note the override for Step 2.
   - Any other read - `ghp_`, `gith`, `gho_`, or empty/unrecognized: proceed to Step 1 with no special handling.

2. Update **Step 2** (line ~30-34) to show two command paths for **both** the edit and create forms:
   - Normal path: `gh pr edit <N> --add-reviewer "@copilot"` / `gh pr create --reviewer "@copilot" ...`
   - App token path: `GH_TOKEN="$GH_PAT_COPILOT" gh pr edit <N> --add-reviewer "@copilot"` / `GH_TOKEN="$GH_PAT_COPILOT" gh pr create --reviewer "@copilot" ...`
   - The existing GraphQL reviewer-list check already confirms the request landed; keep it as the post-condition and note that verification is read-only, so it is unaffected by the App token.

**Test scenarios (behavior table - hand-checked against the skill text, not executed):**
- Read `ghp_` -> skill runs the bare command.
- Read `gith` (fine-grained PAT) -> skill runs the bare command.
- Read `gho_` -> skill runs the bare command.
- Empty / unrecognized read -> skill runs the bare command.
- Read `ghs_` with `GH_PAT_COPILOT` set -> skill runs `GH_TOKEN="$GH_PAT_COPILOT" gh pr edit` (and the create form).
- Read `ghs_` without `GH_PAT_COPILOT` -> skill stops with setup instructions; raw token never appears in output.

**Verification:** Read the edited SKILL.md. Confirm Step 0 classifies `ghs_` vs. everything else, truncates in-process on both shells, and never echoes the raw token. Confirm Step 2 shows both command paths for edit and create. Confirm setup instructions use a placeholder, not a literal token. Confirm the at-a-glance block starts at the token check.

### U2. Pre-flight check, isolation record, and conditional overrides in lfg-ship

**Goal:** Add a Step 0 hard-gate token check, update the isolation record, and use the PAT override at every Phase 2 request site including the babysitter brief.

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8

**Dependencies:** None (parallel with U1)

**Files:**
- `src/skills/heypogi-agent-forge/lfg-ship/SKILL.md`

**Approach:**

1. In **Step 0** (line ~36), after the isolation question and before worktree creation, insert a **pre-flight token check**:
   - Read the first 4 characters of `gh auth token`, truncating in-process (never echo the raw token), shell-specific as in U1. Guard the bash pipe against SIGPIPE under `set -euo pipefail`.
   - If `ghs_` and `GH_PAT_COPILOT` not set: **stop the run** (hard gate) with the R5 setup instructions plus the one re-check command. Do not offer to continue.
   - If `ghs_` and `GH_PAT_COPILOT` set: record `app-token-with-pat`.
   - Any other read (including empty/unrecognized): record `user-token`, proceed.

2. Add `copilot_token_mode` to the **isolation record JSON** schema (line ~104):
   - `"copilot_token_mode": "user-token|app-token-with-pat"` (the no-PAT case never reaches the record - Step 0 stops first).
   - Derive from the detection result. Name the record's consumer: Step P2.1 and the babysitter brief read this field to decide whether to apply the override.

3. Update **Step P2.1** (line ~194-198): if `copilot_token_mode` is `app-token-with-pat`, prefix the `gh pr edit` / `gh pr create` reviewer command with `GH_TOKEN="$GH_PAT_COPILOT"`.

4. Update the **babysitter brief** (Step P2.2, line ~229): carry the override into the brief as **unexpanded** text (`GH_TOKEN="$GH_PAT_COPILOT" gh pr edit ...`), never an interpolated value. The brief instructs the babysitter to re-read the token prefix and confirm `GH_PAT_COPILOT` is set in its own environment before the first re-request, and to stop with the R5 instructions if either check fails. The no-token-values verification (U4 step / Verification Contract) covers the brief and the isolation record too, not just the registry.

**Test scenarios (behavior table - hand-checked against the skill text, not executed):**
- Read `ghp_` (or empty) -> `copilot_token_mode: "user-token"`, Phase 2 uses the bare command.
- Read `ghs_` with PAT -> `copilot_token_mode: "app-token-with-pat"`, Phase 2 and the babysitter re-request use the `GH_TOKEN` override; brief contains the literal string `$GH_PAT_COPILOT`, not an expanded token.
- Read `ghs_` without PAT -> Step 0 stops the run with setup instructions; no worktree created, no record written.

**Verification:** Read the edited SKILL.md. Confirm the Step 0 check stops (does not prompt to continue) on the no-PAT case. Confirm the isolation record schema has `copilot_token_mode` with two values and a named consumer. Confirm Step P2.1 and the babysitter brief apply the override, the brief carries it unexpanded, and the babysitter re-checks its own environment.

### U3. Failure mode entry in lfg-ship

**Goal:** Document the "reviewer request did not land" failure (errored, mis-scoped/expired PAT, Copilot unlicensed) in the Failure Modes table.

**Requirements:** R9

**Dependencies:** U2

**Files:**
- `src/skills/heypogi-agent-forge/lfg-ship/SKILL.md`

**Approach:**

1. Add a row to the Failure Modes table (line ~289):

   | Failure | Action |
   |---|---|
   | Copilot review request fails or the reviewer-list check does not show `@copilot` landed after the override fired | Stop Phase 2. Report setup instructions to operator. |

**Test scenarios:**
- Table row is present and correctly describes the failure and action.

**Verification:** Read the Failure Modes table. Confirm the new row exists with the correct failure description and action.

### U4. Secrets reference document

**Goal:** Create a central reference for the **secret-bearing credentials** used by agent infrastructure, documenting what each variable is, why it exists, when it is needed, which skills/scripts/apps depend on it, its scope, and its expiry/rotation. Provide a committed `.env.example` naming template, cross-link with `DEPENDENCIES.md`, and confirm `.env` is gitignored.

**Requirements:** R10, R11, R12

**Dependencies:** None (parallel with U1-U3)

**Files:**
- `docs/secrets-registry.md` (new file, committed)
- `.env.example` (new file, committed - a naming template, all values commented out)
- `.gitignore` (verify only - `.env` is already listed at line 17; the runtime `.env` file is the ignored artifact, `.env.example` is tracked)
- `DEPENDENCIES.md` (modify - add a one-line pointer from the Environment variables section to `docs/secrets-registry.md` for credentials)

**Approach:**

1. Create `docs/secrets-registry.md` with a table-based format. Columns:
   - **Variable** - the exact env var name (e.g., `GH_PAT_COPILOT`)
   - **Type** - category: PAT, OAuth token, API key, App installation token, etc.
   - **Description** - what the variable holds
   - **Why** - why it is needed (the problem it solves)
   - **When** - when it is used (which skills, which commands, what conditions)
   - **Dependents** - which skills, scripts, apps, or workflows require this secret (e.g., `request-copilot-code-review`, `lfg-ship`, a GitHub Action, a cron job)
   - **Scope** - the privilege the credential should carry (e.g., `Pull requests: Read and write` on the repos the operator ships from)
   - **Expiry/Rotation** - expiry date if any, and what to do on suspected exposure (regenerate, update the env var; no value lives in the repo to scrub)
   - **Setup** - brief setup instructions or pointer to where they live

2. Seed with `GH_PAT_COPILOT` as the first entry:
   - Type: Fine-grained PAT
   - Description: GitHub fine-grained personal access token for Copilot review requests
   - Why: GitHub App installation tokens (`ghs_`) cannot request reviews from other bots; this PAT provides a user-token fallback
   - When: Used by `request-copilot-code-review` and `lfg-ship` skills when the `gh auth token` read is `ghs_`; prefixed as `GH_TOKEN="$GH_PAT_COPILOT"` on `gh pr edit` / `gh pr create` reviewer commands. The machine's `gh` shim injects an App token into every `gh` call but passes a caller-set `GH_TOKEN` through, which is what makes the override effective.
   - Dependents: `request-copilot-code-review` skill, `lfg-ship` skill (Phase 2 Copilot review request, babysitter re-request loop)
   - Scope: `Pull requests: Read and write` on every repository the operator ships from (an owner-wide fine-grained PAT is acceptable if the operator chooses; a single-repo token silently fails elsewhere)
   - Expiry/Rotation: fine-grained PATs expire by default - record the expiry date; on suspected exposure, regenerate on github.com and update the shell profile. No rotation of repo content is needed because only the variable name is stored here.
   - Setup: Create at github.com > Settings > Developer settings > Personal access tokens; set the scope above; set `GH_PAT_COPILOT` in the shell profile using a placeholder in any pasted instructions, not a literal token.
   - **Discovery order:** No runtime in this repo auto-loads a project `.env` file. The supported source is the shell profile (`~/.bashrc` / `~/.zshrc` / PowerShell `$PROFILE`), or a file the operator sources explicitly. `.env.example` is a naming reference only. At runtime the skill checks `$GH_PAT_COPILOT` directly - only whether the variable is set matters.

3. Create `.env.example` at repo root as a template. Contents:
   ```
   # GitHub fine-grained PAT for Copilot review requests (used when gh is authenticated as a GitHub App)
   # See docs/secrets-registry.md for details. Set this in your shell profile, not here - nothing loads this file.
   # GH_PAT_COPILOT=<your fine-grained PAT>
   ```
   All values commented out and placeholdered - this is a naming reference, not a config.

4. Confirm `.env` is in `.gitignore` (already present at line 17). The ignored artifact is the runtime `.env`; `.env.example` is committed. Never commit an actual `.env` file.

5. Add a note at the top of `docs/secrets-registry.md`: "This file tracks secrets by name and purpose only. Never commit actual token values."

6. In `DEPENDENCIES.md`, add a one-line pointer from the Environment variables section: non-secret env vars stay here; secret-bearing credentials are in `docs/secrets-registry.md`. Add the reciprocal pointer in the registry note.

**Test scenarios:**
- `docs/secrets-registry.md` exists with the correct table structure and `GH_PAT_COPILOT` entry.
- Table has columns: Variable, Type, Description, Why, When, Dependents, Scope, Expiry/Rotation, Setup.
- Dependents column lists the specific skills that consume the secret; Scope and Expiry/Rotation are populated for the first entry.
- `.env.example` exists at repo root, committed, with `GH_PAT_COPILOT` commented out.
- `.env` is in `.gitignore`; `.env.example` is not ignored.
- `DEPENDENCIES.md` and `docs/secrets-registry.md` cross-link.
- No actual token values appear in any committed file.
- All files are structured so new entries can be added as rows/columns without restructuring.

**Verification:** Read `docs/secrets-registry.md`, `.env.example`, `.gitignore`, and the `DEPENDENCIES.md` env-var section. Confirm the table structure, the `GH_PAT_COPILOT` entry with Dependents/Scope/Expiry, the committed `.env.example` template, that `.env` (not `.env.example`) is gitignored, and the bidirectional cross-link.

---

## Requesting the Copilot review for this run

This plan's own PR needs the fallback path, so the review request for this work uses the override form rather than the bare command.

**Machine state (checked 2026-08-30):** `gh auth token` reads `ghs_`, confirming the GitHub App installation token described in the Problem Frame.

**Before requesting, confirm the PAT is visible to the shell that will run the command:**

```bash
echo "GH_PAT_COPILOT set? ${GH_PAT_COPILOT:+yes}"
```

If this prints nothing, the variable is not in that process's environment. Do not proceed - `GH_TOKEN="$GH_PAT_COPILOT"` would expand to empty, `gh` would fall back to the App token, and the request would fail exactly as it does today. Export it in the shell that issues the command, or source the profile that defines it.

**Request the review:**

```bash
GH_TOKEN="$GH_PAT_COPILOT" gh pr edit <N> --add-reviewer "@copilot"
```

The quotes around `"@copilot"` are load-bearing on PowerShell, where a bare `@copilot` parses as a splatting operator and the command fails with `flag needs an argument: --add-reviewer`. On bash/zsh they are optional but harmless.

**Verify it landed** (read-only, unaffected by the App token, so no override needed):

```bash
gh api graphql -f query='query { repository(owner:"OWNER", name:"REPO") { pullRequest(number:N) { reviewRequests(first:10) { nodes { requestedReviewer { __typename ... on Bot { login } ... on User { login } } } } } } }'
```

Expected: `{"__typename":"Bot","login":"copilot-pull-request-reviewer"}`. An empty list or a list without that bot means the request did not land - capture the output into the Problem Frame rather than claiming success.

## Verification Contract

- Read both edited SKILL.md files end-to-end after all units are applied.
- Confirm the token check classifies `ghs_` versus everything else, and documents `ghp_`, `gith`, `gho_`, and the empty read as non-branching.
- Confirm truncation is in-process on both shells and the raw token is never echoed.
- Walk the behavior tables (six U1 rows, three U2 rows) against the edited skill text: for each row, confirm the skill specifies the exact command form (bare vs. `GH_TOKEN="$GH_PAT_COPILOT"` prefix), the stop-or-proceed branch, and that no step echoes the raw token. This repo has no test runner; these are read-and-confirm checks like every other line here.
- Confirm PAT override fires only for `ghs_`, at every request site: `gh pr edit`, `gh pr create`, and the babysitter re-request.
- Confirm the babysitter brief carries the override as the literal string `$GH_PAT_COPILOT` (unexpanded) and re-checks its own environment.
- Confirm setup instructions include fine-grained PAT creation, repo scoping, PR read/write permission, and shell-profile setup with a placeholder (no literal token anywhere).
- Confirm `lfg-ship` Step 0 stops the run (no continue prompt) on the App-token-no-PAT case.
- Confirm `lfg-ship` isolation record includes `copilot_token_mode` with values `user-token` / `app-token-with-pat` and a named consumer.
- Confirm `lfg-ship` Failure Modes table has the new entry keyed on the reviewer-list check.
- Confirm `docs/secrets-registry.md` exists with the correct table structure (incl. Scope, Expiry/Rotation) and `GH_PAT_COPILOT` entry.
- Confirm no actual token values appear in `docs/secrets-registry.md`, `.env.example`, the isolation record schema, or the babysitter brief.
- Confirm `.env.example` is committed with `GH_PAT_COPILOT` placeholdered; `.env` is in `.gitignore` (line 17) and `.env.example` is not.
- Confirm `DEPENDENCIES.md` and `docs/secrets-registry.md` cross-link.
- Confirm the Problem Frame records the actual observed error from `gh pr edit --add-reviewer "@copilot"` under an App token.

## Definition of Done

- Both SKILL.md files (`src/skills/dev-tool-reference/request-copilot-code-review/SKILL.md`, `src/skills/heypogi-agent-forge/lfg-ship/SKILL.md`) are edited and verified.
- Token detection classifies `ghs_` vs. everything else; `ghp_`, `gith`, `gho_`, and the empty read all pass through unchanged.
- Truncation is in-process on both shells; the raw token is never echoed.
- Every row of the U1 and U2 behavior tables is confirmed present and correct in the edited skill text.
- PAT fallback uses `GH_TOKEN` env var override (non-destructive) at every request site, including the babysitter re-request, carried unexpanded into the brief.
- `lfg-ship` Step 0 stops the run before any work when an App token has no PAT - no continue prompt.
- Setup instructions are clear, actionable, and contain no literal token values (placeholders only).
- No existing behavior is changed for non-`ghs_` token results.
- The actual observed failure error is recorded in the Problem Frame.
- `docs/secrets-registry.md` exists with `GH_PAT_COPILOT` as the first entry, including Dependents, Scope, and Expiry/Rotation.
- `docs/secrets-registry.md` and `DEPENDENCIES.md` cross-link; the registry covers secret-bearing credentials only.
- `.env.example` is committed at repo root with `GH_PAT_COPILOT` placeholdered; `.env` remains gitignored.
- Secrets reference is structured for growth (new entries are rows/columns, not structural changes).
