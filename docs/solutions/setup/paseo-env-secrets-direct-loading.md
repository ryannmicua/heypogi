---
title: "Paseo systemd unit loads .env-secrets directly — allowlist pattern was wrong threat model"
date: 2026-09-13
category: setup
module: "tooling/dev-stack (paseo systemd unit)"
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "Paseo agents cannot see env vars set in .env-secrets"
  - "Systemd unit uses .env-paseo allowlist instead of loading .env-secrets"
  - "Deciding how to pass secrets to AI coding agents"
tags: [paseo, env-vars, systemd, secrets-management, ai-agent-security, r28]
---

# Paseo systemd unit loads .env-secrets directly — allowlist pattern was wrong threat model

## Context

The Paseo systemd user unit originally loaded a generated `.env-paseo` allowlist file (carrying only `PASEO_PASSWORD`) instead of `.env-secrets` directly. This was rule R28: "the whole secrets file (with unrelated credentials) is never loaded into the unit environment." The intent was to prevent the daemon process from having credentials it didn't need (FortiGate API keys, UniFi creds, etc.).

This broke agents that needed those credentials at runtime — they inherited the daemon's env and couldn't see `UNIFI_*`, `GUARDIAN_*`, or other vars from `.env-secrets`.

## Guidance

**The security boundary for AI agents is the LLM context window, not the process environment.** A secret in `process.env` is fine — the model can't read it unless code explicitly dumps it into the prompt. The real threat is `.env` files on disk (agents read them as file context) or secrets pasted into prompts/tool schemas.

This is confirmed by multiple independent sources (OWASP LLM02, Auth0, Infisical, Bitwarden, Sonar, Anthropic):

- **Tier 1 (baseline)**: Runtime env vars injected at spawn time. Model never sees them. Correct for most use cases.
- **Tier 2**: Secrets manager with runtime injection (`infisical run --`, `bws run --`). Vault fetches, injects as env vars, never on disk.
- **Tier 3**: Broker/proxy pattern. Agent calls gateway, gateway holds real credential. Agent never receives the secret.

The `.env-paseo` allowlist was solving the wrong problem. It protected against process-level secret exposure, but the actual threat is the LLM seeing secrets in context. Loading `.env-secrets` directly into the systemd unit is the correct approach.

### Key change

In `tooling/dev-stack/paseo.service`, replace:
```
EnvironmentFile=-%h/.config/heypogi/.env-paseo
```
with:
```
EnvironmentFile=-%h/.config/heypogi/.env-secrets
```

In `tooling/dev-stack/dev-stack.sh`, remove `ensure_paseo_env_allowlist()` and all references to `PASEO_ENV_FILE`. The `startup_ensure_allowlist_lines()` function should reconcile `.env-secrets` instead of `.env-paseo`.

### The recursive agent problem

When the orchestrator is also an agent, it can't pass secrets via `paseo run --env` because it doesn't have them either. The only solution is a non-agent process (systemd, wrapper script, broker) that holds and injects secrets. This is why daemon-level injection (Tier 1) is the practical floor for agent-to-agent dispatch.

## Why This Matters

Without this change, agents that need operational credentials (network devices, APIs, services) cannot function. The allowlist was an unnecessary security layer that provided no real protection — the daemon process already has filesystem access to `.env-secrets`, and the Paseo password itself grants full daemon control.

## When to Apply

- When Paseo agents can't see env vars they need
- When designing secrets management for AI agent deployments
- When evaluating security controls — ask "is this protecting the process or the context window?"

## Examples

Before (R28 allowlist):
```bash
# .env-paseo only carries PASEO_PASSWORD
# Agents can't see UNIFI_*, GUARDIAN_*, etc.
EnvironmentFile=-%h/.config/heypogi/.env-paseo
```

After (direct loading):
```bash
# .env-secrets carries all credentials
# Agents inherit everything the daemon has
EnvironmentFile=-%h/.config/heypogi/.env-secrets
```

## Related

- OWASP LLM02 (Sensitive Information Disclosure) — secrets in context window
- OWASP LLM01 (Prompt Injection) — mechanism that extracts secrets from context
- Session digest: `docs/session-digests/2026091301_paseo_env_secrets_architecture_decision.md`
