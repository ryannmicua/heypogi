# Residual Findings — Global Instructions Manager

Deferred from code review (2026-08-30). All P3 severity — not blocking for merge.

## C5: bash wc -l whitespace
- **File:** tooling/instructions/install-instructions.sh:160
- **Category:** quality
- **Description:** `lines=$(wc -l <<< "${diff_out}")` captures leading whitespace. Works by accident in arithmetic context.
- **Fix:** `lines=$(wc -l <<< "${diff_out}" | tr -d '[:space:]')`

## C6: PowerShell interactive input validation
- **File:** tooling/instructions/install-instructions.ps1:298
- **Category:** bug (P3)
- **Description:** Non-numeric input in interactive mode throws terminating error due to `$ErrorActionPreference = "Stop"`.
- **Fix:** Wrap `[int]$num` parse in try/catch or validate with regex first.

## C7: PowerShell -Json mutual exclusivity
- **File:** tooling/instructions/install-instructions.ps1
- **Category:** quality
- **Description:** PS1 rejects -Json when none of -Status, -DryRun, -Remove, -Auto are set, which is stricter than bash version. Consider allowing -Json with default interactive mode (suppressed output).
- **Fix:** Align behavior with bash version or document the difference.
