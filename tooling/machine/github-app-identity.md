---
description: Give agents on this machine a first-class GitHub identity — a GitHub App whose short-lived installation tokens drive gh CLI and git push/pull over HTTPS, with commits attributed to the app's bot user
---

# How to Set Up a GitHub App as the Agent Identity

This wires a GitHub App into the machine so agent sessions authenticate to
GitHub as the app (`<slug>[bot]`) instead of as you: `gh` API calls use
short-lived installation tokens, `git push/pull` over HTTPS works through a
credential helper with no stored passwords, and commits are attributed to the
app's bot user.

The whole setup is scripted and idempotent:
[`tooling/machine/github-app-identity.sh`](github-app-identity.sh).

## Prerequisites

- A registered GitHub App (github.com → Settings → Developer settings →
  GitHub Apps) with **Contents: read & write** (and whatever else agents need)
- The app's private key downloaded as a `.pem`
- The app installed at least once (personal account and/or an org)
- On the machine: `git`, `openssl`, `curl`, `jq`, and `~/.local/bin` on `$PATH`
- Optional but recommended: GitHub CLI (`gh`) — lets the installer drop a
  `gh` shim so **every** `gh` call (Paseo daemon and its agents included)
  acts as the bot with no per-session `GH_TOKEN` export

## Inputs to collect

| Input | Where to find it | This machine (rijam-dev) |
|-------|------------------|--------------------------|
| App ID (numeric) | App settings page → About | `4689979` |
| Client ID | Same place — starts with `Iv`; recorded as a comment only | `Iv23liGhzMjMIqbOhDIM` |
| Slug | App settings URL; bot user becomes `<slug>[bot]` | `rijam-dev` |
| Private key `.pem` | Generated on the app settings page | `/opt/rijam/secrets/rijam-dev.2026-08-23.private-key.pem` |
| Installation IDs | Personal: `https://github.com/settings/installations/<ID>` · Org: `https://github.com/organizations/<org>/settings/installations/<ID>` | `ryannmicua=155890008`, `adventistasia=155890365` |

Name installations after their org/login so tools can auto-select them from
the repo path (`adventistasia/org-repo` → installation `adventistasia`).
The **first** one listed is the fallback default when nothing matches.

## Run the installer

```bash
bash tooling/machine/github-app-identity.sh \
  --app-id 4689979 \
  --slug rijam-dev \
  --key /opt/rijam/secrets/rijam-dev.2026-08-23.private-key.pem \
  --installation ryannmicua=155890008 \
  --installation adventistasia=155890365 \
  --client-id Iv23liGhzMjMIqbOhDIM \
  --set-global-identity \
  --test-repo https://github.com/ryannmicua/<some-repo>.git
```

Omit flags and it prompts for them interactively instead. Useful flags:

| Flag | Effect |
|------|--------|
| `--copy-key` | Copy the `.pem` into the config dir instead of symlinking (default keeps a single secret copy in `/opt/rijam/secrets/`) |
| `--set-global-identity` | Set git **global** `user.name`/`user.email` to the bot attribution (commits by humans on this box will also show as the bot) |
| `--verify-only` | Re-run live verification without touching anything |

It ends with a verification pass and prints `ALL VERIFIED` when live.

## What it installs

| File / setting | Source | Role |
|----------------|--------|------|
| `~/.config/github-app/app.conf` (600) | [`tooling/machine/github-app.app.conf.template`](github-app.app.conf.template) | App ID, slug, named installations |
| `~/.config/github-app/private-key.pem` | symlink or copy of your `.pem` | JWT signing key |
| `~/.local/bin/gh-app-token` | [`tooling/machine/gh-app-token`](gh-app-token) | Mint/cache installation tokens (1h TTL, refreshed 5 min early) |
| `~/.local/bin/git-credential-gh-app` | [`tooling/bin/git-credential-gh-app`](git-credential-gh-app) | Git credential helper for `https://github.com` only |
| `~/.local/bin/gh` | [`tooling/machine/gh.shim.template`](gh.shim.template) | Shim: injects an installation token into every `gh` call, so gh acts as `<slug>[bot]`. Passes through your own `GH_TOKEN`/`GITHUB_TOKEN`; skipped if no real `gh` exists outside `~/.local/bin` |
| `git config --global credential.https://github.com.helper` | wired by script | Routes github.com HTTPS auth through the helper |
| `~/.cache/github-app/tokens/` (700) | created on demand | Token cache keyed by installation name |

Canonical copies of the tools live in this repo in this folder (`tooling/machine/`); edit
there and re-run the installer to update a machine.

## Verify

```bash
gh-app-token --whoami          # app slug, bot user id, attribution hint
gh-app-token --list            # installations visible to the app (live API)
git ls-remote https://github.com/ryannmicua/Pogidude-Hybrid.git HEAD
```

`ls-remote` succeeding proves the credential helper end-to-end (it fetches a
token behind the scenes). Or re-run the installer with `--verify-only`.

## Daily use by agents

```bash
# gh CLI just works as the bot via the ~/.local/bin/gh shim — no export needed:
gh pr list -R ryannmicua/heypogi
gh auth status                 # -> Logged in to github.com account <slug>[bot] (GH_TOKEN)

# git over HTTPS just works (helper mints/caches tokens automatically):
git pull && git push

# target a specific installation for one command:
GH_APP_INSTALLATION=adventistasia gh api installation/repositories --jq '.total_count'

# act as yourself for one command (escape hatch):
GH_TOKEN=<your-user-token> gh api user
```

Commit attribution is per-repo config (global was set here via
`--set-global-identity`):

```bash
git config user.name 'rijam-dev[bot]'
git config user.email '320131804+rijam-dev[bot]@users.noreply.github.com'
```

The email is GitHub's canonical noreply format —
`<bot-user-id>+<slug>[bot]@users.noreply.github.com` — which makes GitHub
display the commit as the app. It receives no mail; notifications are not a
thing for bot accounts (apps consume events via webhooks instead).

## Troubleshooting

**401 "Bad credentials" from API calls** — the token cache may hold a stale or
corrupted entry: `gh-app-token --clear`, then retry. If minting itself fails,
check system clock skew (`date -u` vs GitHub's `Date:` response header) and
that `~/.config/github-app/private-key.pem` matches the current key for the
App ID in `app.conf` (keys stop working if regenerated on GitHub).

**Push rejected on org repos** — the org installation is usually
*selected repos*: add the repo under the installation's *Repository access*,
and confirm the app has Contents read/write.

**`gh` complains about missing scopes** — expected sometimes: installation
tokens are scoped by app permissions, not OAuth scopes. Repo/API operations
covered by the app's permissions work fine (e.g. `GET /user` 403s by design;
repo/PR endpoints are what tools like Paseo need).

**`gh` shim not taking effect for a tool** — the caller must resolve `gh`
via `$PATH` with `~/.local/bin` first (`type -a gh` to check). Tools pinned
to `/usr/bin/gh` bypass the shim; restart the Paseo daemon after installing
the shim so fresh agent processes pick it up.

**Helper not used for a remote** — it only answers for `https://github.com`.
SSH remotes bypass it entirely (by design).

## Uninstall

```bash
git config --global --remove-section credential.https://github.com 2>/dev/null || true
rm -rf ~/.config/github-app ~/.cache/github-app ~/.local/bin/gh-app-token ~/.local/bin/git-credential-gh-app
rm -f ~/.local/bin/gh   # only if you never kept your own gh there
```

## Related docs in this folder

- [`README.md`](README.md) — dev stack overview and setup order
- [`paseo-headless-setup.md`](paseo-headless-setup.md) — headless Paseo daemon identity for the same machines
