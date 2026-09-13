---
lorespec: "0.1"
id: "2026091301"
date: "2026-09-13"
source: "claude"
topic: "Paseo env var architecture: removed .env-paseo allowlist, load .env-secrets directly, auto-hash password"
tags: [paseo, env-vars, security, systemd, dev-stack, secrets-management]
classification:
  type: technical
  secondary_type: strategy
  domains: [devops, security, ai-agents]
  value: high
trails: [paseo-architecture, secrets-management, ai-agent-security]
---

## Session Arc

### Started
User asked why env vars can't be seen by agents in Paseo/OpenCode. Diagnosis revealed the systemd unit loaded a generated `.env-paseo` allowlist (carrying only `PASEO_PASSWORD`) instead of `.env-secrets` directly — by design (rule R28).

### Pivots
- User challenged the R28 security rationale: "isn't having env vars secrets the point?" — led to examining whether the allowlist actually protected anything.
- User asked for per-session env var injection (`paseo run --env`), then asked if agent CLIs (opencode/codex) load their own `.env` files.
- User requested websearch on "recommended way to pass secrets to AI agents" — the research consensus (Infisical, Auth0, OWASP, Bitwarden, Sonar) confirmed: **the threat is the model seeing secrets in context, not the process having them in env vars**. This invalidated R28's premise.
- User pointed out the recursive problem: "the thing calling paseo run is also an agent" — the orchestrator agent doesn't have the secrets either, so per-session injection from agents doesn't work.
- User concluded: "why not just change the logic to load .env-secrets?" — simplest fix, correct threat model.

### Ended
All changes committed. `.env-paseo` allowlist removed from template and dev-stack.sh. Unit loads `.env-secrets` directly. Password auto-hashing added.

## Objects

### DECISION: Remove .env-paseo allowlist, load .env-secrets directly

- **Decision**: The systemd unit loads `.env-secrets` directly instead of a generated `.env-paseo` allowlist.
- **Issue**: R28's allowlist prevented agents from accessing secrets they need (UNIFI_*, GUARDIAN_*, etc.), and the security rationale was wrong for this use case.
- **Positions**:
  - Keep R28 allowlist (security via env filtering)
  - Load `.env-secrets` directly (agents get what they need)
  - Use `.env-override` as escape hatch (user's initial suggestion)
- **Arguments**: The allowlist protected against process-level secret exposure, but the actual threat model is the LLM seeing secrets in context (OWASP LLM02). Env vars in `process.env` are safe — the model can't read them unless something explicitly dumps them into the prompt. Multiple sources (Auth0, Infisical, OWASP, Bitwarden, Sonar) confirm this.
- **Warrant**: We believe that the security boundary is the LLM context window, not the process environment. A secret in `process.env` is fine; a secret in a `.env` file the agent reads as context is not.
- **Qualifier**: in this case
- **Status**: settled

### PATTERN: AI agent secrets management tiers

- **Tier 1**: Runtime env vars injected at spawn time (`paseo run --env KEY=val`). Model never sees them unless code explicitly dumps them. Correct baseline.
- **Tier 2**: Secrets manager with runtime injection (`infisical run --`, `bws run --`). Vault fetches, injects as env vars, never on disk.
- **Tier 3**: Broker/proxy pattern. Agent calls gateway, gateway holds real credential. Agent never receives the secret.
- Scope: universal (transferable across all AI agent deployments)

### INSIGHT: The recursive agent problem

When the orchestrator is also an agent, it can't pass secrets via `--env` because it doesn't have them either. The only solution is a non-agent process (systemd, wrapper script, broker) that holds and injects secrets. This is why Tier 1 (daemon-level injection) is the practical floor for agent-to-agent dispatch.

### SOLUTION: Auto-hash PASEO_PASSWORD in dev-stack.sh

- **What was broken**: If `PASEO_PASSWORD` was set in `.env-secrets` but `daemon.auth.password` was missing from config.json, the daemon would start but reject all connections. Users had to manually run `paseo daemon set-password`.
- **What fixed it**: `require_paseo_password_hash()` and `seed_paseo_config()` now auto-generate a bcrypt hash from `$PASEO_PASSWORD` and write it to `daemon.auth.password` in config.json.
- **Why it works**: Python3 + bcrypt is available on the system. The hash is generated in-process and written atomically via Python JSON manipulation.
- **Caveat**: If bcrypt is not installed (`pip install bcrypt`), the auto-hash fails and falls back to the manual `paseo daemon set-password` suggestion.

## Connections

- D1 —[informed_by]→ I1 (research consensus on agent secrets)
- D1 —[led_to]→ S1 (auto-hash was part of the same commit)
- I1 —[contradicts]→ R28 (the old allowlist rule)
- P1 —[instance_of]→ D1 (Tier 1 is what we implemented)

## Trail Updates

- **paseo-architecture**: Extended with env var loading decision and R28 removal
- **secrets-management**: New trail capturing AI agent secrets patterns
- **ai-agent-security**: New trail capturing the OWASP/research consensus on where secrets belong

## Knowledge Object Types

### ARTIFACT
- `tooling/dev-stack/paseo.service` — updated template, loads `.env-secrets` directly
- `tooling/dev-stack/dev-stack.sh` — removed allowlist logic, added auto-hash

### NEXT_STEP
- Restart daemon when convenient: `systemctl --user restart paseo` (now)
- Verify agents see UNIFI_*, GUARDIAN_* vars after restart
- Consider Tier 2 (Infisical/Bitwarden) if secret rotation becomes important
