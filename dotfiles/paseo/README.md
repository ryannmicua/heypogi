# dotfiles/paseo

Tracked templates for `~/.paseo/`, seeded onto a machine by
`bootstrap/bootstrap.sh` (Step 5).

- `config.json` — daemon settings (listen address, CORS, relay, MCP/terminal
  profiles, provider/agent toggles, features). **Never add `daemon.auth.password`
  here.** This repo is public, and Paseo stores the auth password's bcrypt hash
  inline in this same file, so the live, password-bearing file must never be
  the tracked one. Bootstrap copies this template to `~/.paseo/config.json`
  only when that file doesn't already exist, so an already-set password is
  never overwritten. If the listen address ever drifts from the live daemon
  (e.g. someone hand-edits `~/.paseo/config.json`), reconcile it with
  `dev-stack.sh fix`, which patches the `listen` key in place via `sed`
  without ever touching `auth.password`. Any placeholder credential fields
  (e.g. a provider `apiKey`) must stay obvious placeholders, never real keys.
- `orchestration-preferences.json` — Paseo orchestrator role/model mapping.
  No secrets; safe to copy or symlink as-is.

Unlike `dotfiles/opencode` (which OpenCode reads directly via
`OPENCODE_CONFIG_DIR`, so it can be symlinked straight from the repo), these
are one-time seed templates, not a live symlinked config directory — `~/.paseo`
also holds runtime state (daemon logs, the real password hash) that must
never be committed.
