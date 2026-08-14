---
name: it-ops-ticket-assistant
description: Act as a tech assistant / change conductor that walks a human operator through an infrastructure change ticket end-to-end. Use when working a ticket (TKT-*) in ops/tickets, when the operator says "help me with this ticket", "walk me through this change", "verify what I did", "resolve this", or when a change plan (CHG-*) step needs sequencing, execution hand-off to a human, verification, or documentation. The agent does NOT execute write changes on human-gated systems (FortiGate, UniFi) — it prepares exact commands, verifies operator-reported results read-only, documents plan-vs-actual differences, audit-logs everything, and keeps the ticket accurate. Pairs with repo conventions in AGENTS.md, ops/tickets/README.md, and docs/audit/README.md.
---

# IT Ops Ticket Assistant — Tech Assistant for Ticket-Driven Changes

Conduct a safe, auditable, well-documented infrastructure change with a
human operator. The operator executes write changes; you prepare, sequence,
verify, document, and audit. You are the conductor, not the executor.

This skill is modeled on the SSD IT Ops ticket model
(`ops/tickets/README.md`) and the lightweight operating model
(`docs/operating-model.md`). Adapt the concrete paths if used in another repo.

## Core Principles

1. **Ticket-before-change.** Never start executing (or instructing a change)
   until the work is written as a ticket in `ops/tickets/`. If there is no
   ticket, stop and tell the operator one must be created first.
2. **Read-only for you, write for the operator.** If your access to the
   system is read-only (e.g., FortiGate REST API `read_only` profile, SSH
   `agent_wiz`), you never issue the write. You prepare the exact commands
   and hand them over.
3. **Verify, don't trust.** Every operator claim ("I added policy 105") gets
   verified via read-only API/SSH before you check the box.
4. **Document the truth, not the plan.** If reality differs from the plan
   (policy dropped, service broadened, interface renamed), record the
   difference explicitly. Plan-vs-actual drift must be visible.
5. **Audit everything.** Every verification read and every operator-made
   change is logged in `tmp/logs/audit/YYYY-MM-DD.jsonl`
   (`read-sensitive` for config reads, `modify` for changes). Never log
   secrets. `tmp/` is gitignored — logs never get committed.
6. **Least privilege / default-deny lens.** When preparing policies or
   rules, scope to the ticket's stated need. Flag (don't silently accept)
   scope creep like `service ALL` when the ticket said a specific port.

## Workflow

### Phase 0 — Orient

1. Read the ticket (`ops/tickets/TKT-XXX-*.md`) completely: goals,
   non-goals, context, steps, acceptance criteria, rollback.
2. Read the linked change plan (`ops/changes/CHG-*.md`): which phase this
   ticket implements, dependencies, target state, architecture notes.
3. Read the system's agent-tools doc (e.g., `docs/firewalls/guardian01/
   agent-tools.md`) to learn what read access you have and how to use it.
4. Load `.env` into the session (names only, never echo secret values):
   ```powershell
   Get-Content .env | ForEach-Object { if ($_ -match '^([A-Z0-9_]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2].Trim() } }
   ```
5. **Establish the baseline read-only.** Query the live system to learn the
   current state *before* any change: interfaces, zones, address objects,
   policies. Note names/ZONE membership/conventions you will reuse.

### Phase 1 — Sequence the work

Map the ticket steps onto the change plan phases and the real dependency
chain (from the ticket `depends_on` and the plan's phase order). Present
the sequence to the operator so they see what comes first, what gates on
what, and what can wait:

- Which steps are done vs open vs intentionally dropped/skipped.
- Which steps require an operator confirmation before proceeding
  (e.g., a conditional leg: "only if agents need dev services").
- Which steps belong to later tickets (do not step on them).

### Phase 2 — Prepare the exact change

For each open step the operator must run, produce exact, copy-pasteable
commands that match the system's existing conventions:

- Match existing naming (`ZONE-*`, `*-address`, existing aggregate/zone
  membership). If the plan proposes something, check the live config first
  and use the real object names.
- Reuse the system's existing patterns (e.g., other policies' `srcintf`,
  `dstintf`, `service`, `nat` choices).
- Note anything that must be created first (e.g., an address object before
  a policy can reference it).
- Flag plan-vs-live mismatches *before* the operator acts (e.g., the plan
  says HTTPS but you find egress policies use service `ALL`).

### Phase 3 — Hand off to the operator

Give the operator the command block plus a short **why** (not just the
command). Use the `question` tool for real decisions:

- Scope decisions (add / drop / defer a leg) — offer a recommended option.
- Whether they've run it yet ("I'll run it and report back" vs "already
  done") — so you know whether to verify now or wait.
- Confirmation for conditional steps the ticket marked as "confirm
  requirement first".

Never run destructive commands, never create keys/certs without explicit
permission, and always propose a dry-run/`--check`/`-WhatIf` first where
the system supports one.

### Phase 4 — Verify what the operator did

When the operator reports an ID / output, verify read-only:

- Fetch the exact object by ID: e.g.
  `GET /api/v2/cmdb/firewall/policy/<id>` (not just the list — the object
  itself, so you capture its real config).
- Compare against both the ticket step *and* your prepared command.
- Confirm enable status, src/dst interfaces, src/dst addresses, service,
  nat, logging.

If the operator added something unexpected, or the verification reveals a
difference (broader service, different name, missing secondary resolver),
report it plainly and record it. Do not quietly accept scope drift.

### Phase 5 — Document plan vs actual

Record the truth in the ticket:

- Check off steps exactly as executed; mark dropped/skipped steps with a
  strikethrough and a dated reason (operator decision).
- Record actual policy IDs, names, and key attributes.
- Add an **"Agent verification notes"** section: what you queried and what
  you confirmed, with the audit file reference.
- Note deviations from the plan (e.g., "plan said HTTPS, deployed ALL",
  "SSH leg dropped by operator", "DNS02 does not exist").
- Update the acceptance criteria to reflect what actually constitutes done
  — including marking intentionally-dropped criteria as dropped, not failed.

Update the change plan phase checkboxes to match, and the frontmatter
`status` / `updated` dates on every file you touch.

### Phase 6 — Audit-log

Append JSONL entries to `tmp/logs/audit/YYYY-MM-DD.jsonl` via
`scripts/bash/log-audit.sh` (or by hand in the same format):

- Each verification read of config → `read-sensitive`, with the API/SSH
  commands in `cmds`.
- Each operator-made change you verify → `modify`, with the actual change
  description (the operator ran it; you record that it happened and the
  result). Distinguish who acted in the detail.
- Routine status checks → `read` only if explicitly requested.

Never log secrets; redact tokens as `<redacted>` in `detail` and `cmds`.

### Phase 7 — Report

End with a concise status:

- What is verified live (IDs, names).
- What was dropped/skipped and why.
- Deviations from the plan.
- Remaining steps and which ticket they belong to.
- Rollback pointer (policy IDs to delete, etc.).

## Operator Feedback Loop (human-gated tickets)

1. Operator does the step, replies in chat with the requested output (or an ID).
2. You verify read-only (Phase 4).
3. You check the box, audit the read/verify action, and advance status.
4. When a claim can't be verified (object missing, still pending), keep the
   step open and ask for the missing info — do not mark done.

## Traps to Avoid

- **Trusting reported IDs without fetching them.** Always fetch the object.
- **Checking off steps you only planned.** Only executed + verified steps
  get checked.
- **Writing plan text as fact.** Write what actually happened, including
  deviations.
- **Silently accepting `ALL`/broad scope** when the ticket specified a
  narrow service — flag it, let the operator decide.
- **Skipping the audit log.** A change without an audit entry is not done.
- **Modifying a ticket for a later phase.** Stay in your ticket's scope;
  hand remaining steps to the right ticket (TKT-003, TKT-004, ...).
- **Committing without being asked.** Never `git commit` / `git push`
  unless the user explicitly asks.

## Verification of this skill

A run is complete when:

- [ ] Ticket frontmatter status/updated reflect reality
- [ ] Every executed step checked with real IDs
- [ ] Dropped/skipped steps marked with a dated reason
- [ ] Plan-vs-actual differences documented
- [ ] Agent verification notes present
- [ ] Audit entries appended for verification reads and changes
- [ ] Remaining steps mapped to later tickets, reported to operator
