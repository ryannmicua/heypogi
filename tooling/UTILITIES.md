# Personal Utilities

Utilities installed separately from heypogi's managed setup. This is an
install and maintenance reference; it does not imply a utility is provisioned
by the bootstrap scripts.

## Codex Switch

[codex-switch](https://github.com/xjoker/codex-switch) manages local OpenAI
Codex CLI accounts, displays quota, and can select an account for the next
session.

Install using one of the upstream options:

- macOS / Linux: `curl -fsSL https://github.com/xjoker/codex-switch/releases/latest/download/install.sh | bash`
- Windows PowerShell: `irm https://github.com/xjoker/codex-switch/releases/latest/download/install.ps1 | iex`
- Homebrew: `brew install xjoker/tap/codex-switch`

Update a direct install with `codex-switch self-update --stable`. The upstream
self-updater requires GitHub CLI (`gh`) to verify build provenance. The tool
manages local authentication files; keep profiles, `auth.json`, tokens, and
proxy credentials private.
