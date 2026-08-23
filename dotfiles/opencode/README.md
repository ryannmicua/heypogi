# OpenCode Config

OpenCode config directory managed via `OPENCODE_CONFIG_DIR`.

## Setup

Use the installer script from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/machine/setup-environment.ps1
```

This sets `HEYPOGI_ROOT` and `OPENCODE_CONFIG_DIR` (User scope).

To set it manually, replace `<repo_root>` with the actual path:

```powershell
[Environment]::SetEnvironmentVariable(
  "OPENCODE_CONFIG_DIR",
  "<repo_root>\dotfiles\opencode",
  "User"
)
```

## What goes here

- **opencode.json** — core config (plugins, references, permissions)
- **tui.json** — TUI-specific settings (theme, keybinds)
- **agents/** — custom agent definitions (.md files)
- **commands/** — custom slash commands (.md files)
- **modes/** — operating mode definitions
- **plugins/** — local plugin scripts
- **skills/** — local skill files
- **tools/** — custom tool definitions
- **themes/** — custom UI themes

## Precedence

This config directory is loaded after `~/.config/opencode/` and `.opencode/` directories.
Settings here override global config for conflicting keys. Non-conflicting settings
are merged.

## Related

- Agent/skill/tool source files live in `../../src/` — define them there, reference
  them from this config.
- See https://opencode.ai/docs/config/#custom-directory for details.
