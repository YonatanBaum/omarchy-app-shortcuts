# App Shortcuts

An Omarchy shell plugin that shows the keyboard shortcuts for the app you're
using. Press **Super + Shift + K** and a cheat sheet opens for the focused
window, with a second tab for your Hyprland keybindings.

It works out what the focused window really is:

- **Web apps** are recognised by site, so X, YouTube or Teams show that site's
  shortcuts rather than Chromium's.
- **Terminals** show the shortcuts of the program in the foreground (nvim,
  lazygit, btop, claude…), or the terminal's own when you're at a prompt.
- **Everything else** is matched to its installed app by window class.

## The shortcut library

The plugin keeps an inventory of every installed app and one shortcut file per
app. When an app has no shortcuts yet, it asks the Claude CLI once and stores
the answer, so opening the sheet afterwards is instant and offline.

- At shell start, and whenever a `.desktop` file is added, changed or removed
  (pacman, flatpak, `omarchy-webapp-install`…), the service rescans installed
  apps and looks up any new ones.
- An app you focus that has no `.desktop` entry (a terminal program, say) is
  added to the inventory and looked up the first time you open the sheet.
- **Neovim** isn't looked up: its keymaps are read from Neovim itself, so
  the sheet shows your LazyVim/plugin/custom mappings grouped by their
  which-key groups. They're re-read whenever `~/.config/nvim` or your installed
  plugins change.
- **Other terminal programs** are often too new or niche for the model to
  know, so their lookup is grounded: the helper collects the program's
  `--help` output, its man page and any config files under `~/.config/<name>/`
  that mention keys or bindings (lines that look like secrets are removed), and
  Claude may read the project's docs and source on the web. Bindings changed in
  your config win over the defaults, and the lookup runs again when those files
  change.
- Failed lookups are retried after a day. **Ctrl + R** in the sheet looks the
  current app up again.

Files live in `~/.local/share/funcoder-app-shortcuts/`:

| Path | Contents |
| --- | --- |
| `apps.json` | Inventory of installed and discovered apps |
| `shortcuts/<key>.json` | Shortcuts for one app. Edit freely; set `"source": "user"` so it's never replaced |
| `config.json` | Model, concurrency, timeout, ignore patterns |
| `lookup.log` | Lookup failures |

App keys look like `web:x.com`, `tui:nvim` or `app:spotify`.

### Settings (`config.json`)

| Key | Default | Meaning |
| --- | --- | --- |
| `model` | `claude-sonnet-5` | Model used for lookups |
| `concurrency` | `3` | Lookups run at once during a sync |
| `timeoutSeconds` | `180` | Per-lookup timeout |
| `retryFailedHours` | `24` | Wait before retrying a failed lookup |
| `claudePath` | `""` | Path to `claude` when it isn't on the shell's `PATH` |
| `ignore` | helper entries | Desktop file names (glob) never looked up |

Lookups run `claude -p` with no MCP servers and no settings files. Web and
desktop apps get no tools, so each is a single answer from the model's
knowledge; terminal programs get WebFetch and WebSearch only.

## Install

```bash
./deploy-local.sh                              # copy into ~/.config/omarchy/plugins and validate
omarchy plugin enable funcoder.app-shortcuts
```

Then bind a key in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + K", "App shortcuts", "omarchy-shell shell toggle funcoder.app-shortcuts '{}'")
```

Re-run `./deploy-local.sh` after editing. The shell hot-reloads the copy.

## Command line

```bash
H=~/.config/omarchy/plugins/funcoder.app-shortcuts/shortcuts.py
$H current                 # shortcuts for the focused window
$H list                    # inventory with lookup status
$H show web:x.com          # one app
$H lookup tui:nvim --force # look an app up again now
$H sync                    # rescan and look up anything missing
```
