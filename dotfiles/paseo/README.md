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
- `agent-profiles.json` — shared profile names and initial delegation notes
  for newly added profiles. Apply it to the local Paseo instance with
  `tooling/dev-stack/dev-stack.sh sync-profiles` or
  `tooling/dev-stack/dev-stack.ps1 sync-profiles`. By default, sync only adds
  missing profiles. Use `--overwrite` / `-Overwrite` to update existing
  profiles' catalog name and notes. Use `--force` / `-Force` to skip
  confirmation, and `--dry-run` / `-DryRun` to preview.

The shared catalog does not specify providers or models. Sync matches profiles
by name (case-insensitively). By default, it only adds catalog profiles that
are missing and leaves existing profiles unchanged. With `--overwrite` /
`-Overwrite`, it updates only matching names and notes from the catalog;
provider, model, launch settings, and profile order stay local. A missing
profile copies launch settings from the local `Default` profile, or the first
local profile with a provider; its name and initial notes come from the
catalog. A local profile with a provider is required only when profiles need
to be added. Local profiles outside the catalog remain unchanged.

Unlike `dotfiles/opencode` (which OpenCode reads directly via
`OPENCODE_CONFIG_DIR`, so it can be symlinked straight from the repo), these
are one-time seed templates, not a live symlinked config directory — `~/.paseo`
also holds runtime state (daemon logs, the real password hash) that must
never be committed.
