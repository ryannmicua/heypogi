# Open Items Register

## 1. Usage Note

Use this as the single canonical register for **blockers, risks, issues, assumptions, and dependencies** for this repository-as-a-project.

## 2. Status Definitions

Use these statuses consistently:

1. `open` - identified, recorded, and assigned, but active response has not yet materially started
2. `in progress` - active work is underway to resolve, reduce, clarify, or decide the item
3. `monitoring` - the item remains unresolved, but observation is the chosen treatment for now
4. `resolved` - dealt with in substance, but awaiting final confirmation or closure
5. `closed` - completed; no further action, monitoring, or decision required

## 3. Register Entries

Core columns only (no stage columns):

| Entry ID | Type | Title | Description | Owner | Status | Impact summary | Next action | Target resolution / decision date | Created date | Last updated date | Resolution note | Origin reference |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OIR-001 | blocker | Worker sandbox (full KTD11) for v2 | v1 ships a narrowed worker trust boundary (worktree + out-of-tree control store + scrubbed env + hash-chain evidence); it does NOT claim to survive a malicious same-OS-user delegated agent. A real OS/container sandbox that denies same-OS-user filesystem access is required to claim the full threat model. | ryannmicua | monitoring | v1 explicitly does not defend against a malicious delegated agent that can read/rewrite the out-of-tree control store or exfiltrate credentials. | Define and implement a real sandbox (Windows container via WSL2/Docker, or target Linux with an OS sandbox) wrapping delegated workers; re-enable full KTD11/U8 in v2. | v2 | 2026-07-28 | 2026-07-28 | v1 narrowed per session decision; see plan `docs/plans/2026-07-28-001-feat-paseo-plan-execution-supervisor-plan.md` KTD11/KTD12 revisions. | Issue #2; plan KTD11 |
| OIR-002 | dependency | Metered accounting gateway (U4) for v2 | v1 is subscription-only (Codex/OpenCode Go); no metered provider is in active use. U4 (metering gateway) and the metered legs of U2/U3/U6 are deferred. | ryannmicua | monitoring | v1 cannot execute metered runs; full Product Contract R3-R5/R19-R21 metered legs are v2. | Author a v2 plan to implement U4 + metered legs with the SSRF-hardened loopback gateway. | v2 | 2026-07-28 | 2026-07-28 | v1 scope decision per session; see plan "Ship v1 subscription-only" Key Decision. | Issue #2; plan U4 |
| OIR-003 | risk | Audit calibration bar (KTD7) on chosen audit model | Confirm opencode-go/glm-5.2 meets zero-false-pass on the 15-case calibration corpus at certification (zero blocker false approvals, >=14/15 agreement, <=2 false blocks). Nondeterministic model on an asymmetric bar. | ryannmicua | open | If the chosen audit profile cannot clear the bar after corpus tuning, no run can complete. | Run calibration at U5; if it fails after tuning, swap to a different cross-family audit model and record the contingency if invoked. | Implementation (U5) | 2026-07-28 | 2026-07-28 | Open; resolution deferred to U5 implementation. | Issue #2; plan KTD7 |
| OIR-004 | issue | Plan readiness label was mismatched (resolved) | The plan frontmatter said `artifact_readiness: requirements-only` despite a fully-developed Planning Contract + Implementation Units + Verification + DoD. | ryannmicua | closed | Contract defect could trigger the wrong review lens and block ce-work execution. | Bumped to `implementation-ready` after resolving the v1 scope/trust blockers on 2026-07-28. | Resolved 2026-07-28 | 2026-07-28 | 2026-07-28 | Resolved by bumping readiness and amending docs/AGENTS.md unified-plan convention. | Issue #2 |