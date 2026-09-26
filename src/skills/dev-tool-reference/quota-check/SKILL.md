---
name: quota-check
description: >-
  Check local AI-provider quotas and usage windows with quota-axi. Use when
  asked to check provider quota, remaining usage, limits, resets, quota status,
  or which configured provider has capacity. Do not use for billing-cost
  estimates or changing provider credentials.
---

# Provider Quota Check

Use `quota-axi` to read current local quota evidence for configured AI
providers. Report what the command returns; do not infer missing quota data.

## Check quotas

Run the default report without delegated credential refresh:

```bash
npx -y quota-axi --no-credential-refresh
```

This avoids asking a provider CLI to renew an expired session during a routine
check. The command still reads available local provider state to obtain quota
data. Never print or expose credential values.

If the user asks for specific providers, pass their IDs with `--provider`:

```bash
npx -y quota-axi --provider codex,claude --no-credential-refresh
```

For more detailed quota windows, pacing, or account evidence, add `--full` only
when requested or needed to answer the question. Use `--json` when structured
output is useful for follow-up processing. Use `--tui` only when the user asks
for an interactive terminal view.

The user may explicitly request a fresh credential-backed check. In that case,
explain that quota-axi may delegate an expired session's renewal to the
provider's own CLI, then run without `--no-credential-refresh`. Do not use
`--allow-keychain-prompt` unless the user explicitly authorizes a Keychain
prompt.

## Interpret and report

- State when the report was generated if `generatedAt` is present.
- Summarize each reported provider's remaining percentage, quota scope/window,
  reset time, runway, and limiting window when available.
- Distinguish an exhausted quota from missing credentials, unavailable
  providers, and unresolved quota windows. These are not equivalent states.
- Treat `attention` entries as diagnostic status, not as proof that a provider
  has zero quota.
- Preserve the command's confidence and uncertainty. If a field is absent or
  unknown, say so rather than estimating it.
- If the user asks which provider to use, compare only the available evidence
  (such as runway and reset time) and make clear that quota is not a measure of
  model quality or task suitability.
- If the command fails, report the error and any clear prerequisite, such as
  missing `npx`, network access, provider sign-in, or unavailable provider CLI.
  Do not attempt sign-in or credential repair unless asked.

## Supported provider IDs

The CLI currently documents these IDs: `claude`, `codex`, `cursor`, `copilot`,
`grok`, `kimi`, `zai`, `agy`, `alibaba`, `opencode-go`, `commandcode`,
`minimax`, `mimo`, `deepseek`, `openrouter`, and `elevenlabs`. The installed
CLI's `--help` output is authoritative if this list changes.
