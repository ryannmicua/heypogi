# How to Install opencode-learn

Install the plugin so it runs automatically in every OpenCode session.

## Permanent Installation

### 1. Place the Plugin

```bash
# From the heypogi repo
cp -r src/plugins/opencode-learn ~/.opencode/plugins/
```

Or link it so updates track the repo:

```bash
ln -s "$PWD/src/plugins/opencode-learn" ~/.opencode/plugins/opencode-learn
```

### 2. Register with OpenCode

Edit `~/.config/opencode/opencode.json`:

```json
{
  "plugins": [
    "~/.opencode/plugins/opencode-learn"
  ]
}
```

If you already have other plugins listed, add it to the array:

```json
{
  "plugins": [
    "some-other-plugin",
    "~/.opencode/plugins/opencode-learn"
  ]
}
```

### 3. Verify

```bash
sqlite3 ~/.local/share/opencode-learn/learn.db ".tables"
```

You should see 13 tables. If not, check OpenCode's logs for plugin load errors.

## Configuration

The plugin has no configuration. It collects everything automatically.

**Database location:** `~/.local/share/opencode-learn/learn.db`

## Uninstallation

1. Remove the plugin from `opencode.json`
2. Delete the plugin directory: `rm -rf ~/.opencode/plugins/opencode-learn`
3. The database remains at `~/.local/share/opencode-learn/learn.db` — delete it separately if desired

## Troubleshooting

**Problem:** Plugin not loading
**Solution:** Check OpenCode's plugin loading errors in the TUI or run with `opencode --verbose`

**Problem:** Database file not created
**Solution:** Ensure `~/.local/share/opencode-learn/` is writable and has enough disk space

**Problem:** Data not appearing
**Solution:** The plugin only captures data during active OpenCode sessions. Run a few prompts and check again.

