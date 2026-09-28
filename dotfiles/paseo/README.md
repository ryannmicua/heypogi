# dotfiles/paseo

Tracked Paseo configuration inputs. `config.json` is the seed template copied
to `~/.paseo/config.json` by `bootstrap/bootstrap.sh`; `agent-profiles.json`
is read by the explicit profile sync command.

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
- `agent-profiles.json` — shared profile names, delegation notes, and model
  lineups. Apply it to the local Paseo instance with
  `tooling/dev-stack/dev-stack.sh sync-profiles` or
  `tooling/dev-stack/dev-stack.ps1 sync-profiles`. The lineups are `default`
  (the current mixed-provider setup), `codex-only`, and `opencode-only`.
  Use `--lineup` / `-Lineup` to choose a lineup; without it, sync applies
  `default`. Use `--overwrite` / `-Overwrite` to also update existing
  profiles' names and notes. Use `--force` / `-Force` to skip confirmation,
  and `--dry-run` / `-DryRun` to preview.

Sync matches profiles by name, case-insensitively. It applies provider, model,
and thinking effort from the selected lineup to catalog profiles, while
preserving profile IDs, modes, feature settings, order, and local profiles
outside the catalog. A `null` `thinkingOptionId` clears any previous effort
setting for models that do not expose effort choices. Missing profiles copy
launch settings from local `Default` (or the first profile with a provider),
then receive the selected lineup settings. Sync is explicit and does not run
as part of install or fix.

Unlike `dotfiles/opencode` (which OpenCode reads directly via
`OPENCODE_CONFIG_DIR`, so it can be symlinked straight from the repo), these
are one-time seed templates, not a live symlinked config directory — `~/.paseo`
also holds runtime state (daemon logs, the real password hash) that must
never be committed.
