# Install Codex CLI

Install or update OpenAI Codex CLI on macOS, Linux, or WSL2 and verify the
local sandbox prerequisite.

The workflow follows the current official OpenAI documentation:

- Codex CLI installer: <https://learn.chatgpt.com/docs/codex/cli>
- Linux sandbox prerequisites: <https://learn.chatgpt.com/docs/sandboxing>

## Safety / Approval Gate

`status` is read-only. Run it without approval.

Before an agent runs `install`, ask the user for approval. Explain that it can:

- use the network to download the official Codex installer;
- install the distribution's `bubblewrap` package with `sudo` on Linux/WSL2;
- on Ubuntu 24.04 only, install and load the packaged AppArmor profile when the
  Bubblewrap user-namespace smoke test fails.

The script does not disable AppArmor's unprivileged-user-namespace restriction
with `sysctl`. That broader fallback requires separate diagnosis and explicit
authorization.

## Check Current State

Run from the repository root:

```bash
bash tooling/machine/install-codex-cli.sh status
```

The check reports:

- the installed Codex CLI version and executable path;
- the installed Bubblewrap version and executable path on Linux/WSL2;
- whether Bubblewrap can create the user namespace Codex needs.

## Install or Update

After approval, run:

```bash
bash tooling/machine/install-codex-cli.sh install
```

On Linux/WSL2, the script installs Bubblewrap before Codex:

- Ubuntu/Debian: `sudo apt-get install -y bubblewrap`
- Fedora: `sudo dnf install -y bubblewrap`

On Ubuntu 24.04, a successful package installation can still leave user
namespaces blocked by AppArmor. The script detects that state with a Bubblewrap
smoke test, installs `apparmor-profiles` and `apparmor-utils`, copies the
packaged `bwrap-userns-restrict` profile into `/etc/apparmor.d`, and loads it
without rebooting. It performs this repair only when the test fails.

The script then runs OpenAI's official standalone installer:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

## Verify and Sign In

The install command verifies Codex and the sandbox before reporting success.
You can rerun the read-only check at any time:

```bash
bash tooling/machine/install-codex-cli.sh status
```

Then open a project directory and start Codex:

```bash
codex
```

Choose **Sign in with ChatGPT** or another available sign-in method during the
first run. Authentication is interactive and is intentionally not automated by
this tooling.

## Troubleshooting

- If `codex` is not found immediately after installation, open a new terminal
  so the installer-added PATH entry is loaded, then rerun `status`.
- If Bubblewrap is installed but the smoke test fails on a distribution other
  than Ubuntu 24.04, stop and diagnose that distribution's user-namespace
  policy. Do not assume Ubuntu's AppArmor repair applies.
- A Bubblewrap error from inside an already constrained container or sandbox
  does not prove the host package is missing. Run `status` on the host before
  installing or changing system packages.
