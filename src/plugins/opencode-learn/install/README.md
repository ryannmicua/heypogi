# Installing opencode-learn

Registers the plugin in your global OpenCode config so it runs in every session.

## Quick Install

From the plugin's `install/` directory, run:

```powershell
./install.ps1
```

## What the Script Does

1. **Detects the plugin directory** — auto-derives it from the script's own location
2. **Reads `~/.config/opencode/opencode.json`** — your global OpenCode config
3. **Backs up the existing config** — creates `opencode.json.bak.<timestamp>`
4. **Adds the plugin path** to the `"plugin"` array if not already present
5. **Verifies** the plugin directory looks correct before modifying anything

## Manual Install

If you prefer to edit the config by hand:

1. Open `C:\Users\<you>\.config\opencode\opencode.json`
2. Add the plugin path to the `"plugin"` array:

```json
{
  "plugin": [
    "...existing plugins...",
    "C:/Users/rmicua/myrepo/heypogi/src/plugins/opencode-learn"
  ]
}
```

Use **forward slashes** — OpenCode normalizes paths internally.

## Verify After Restart

1. Restart OpenCode
2. Run a few prompts
3. Check the database exists:

```powershell
sqlite3 "$env:LOCALAPPDATA\..\Local\share\opencode-learn\learn.db" ".tables"
```

You should see 13 tables.

## Uninstall

1. Remove the plugin path from `~/.config/opencode/opencode.json`
2. Delete the database if desired: `rm ~/.local/share/opencode-learn/learn.db`

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script can't find plugin | Pass the path explicitly: `./install.ps1 -PluginDir "C:/path/to/opencode-learn"` |
| Config parse error | Script backs up and recreates the config automatically |
| Plugin not loading | Check OpenCode's startup logs for plugin load errors |

