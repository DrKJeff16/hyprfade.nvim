# hyprfade.nvim

Seamlessly fade the terminal window hosting Neovim on Hyprland by setting its
window opacity via `hyprctl dispatch setprop pid:<pid> alpha`.

## Why

Hyprland window rules based on `class` or `title` can miss the terminal window
when Neovim is launched from a file manager like yazi, because the window's
class hasn't been resolved yet. Matching on `pid:` sidesteps this entirely.

## Requirements

- Hyprland
- `hyprctl` on `PATH`
- A supported terminal emulator (kitty, alacritty, foot, wezterm)

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourname/hyprfade.nvim",
  event = "VeryLazy",
  opts = {
    opacity = 0.85,
  },
  keys = {
    { "<leader>uo", "<cmd>HyprFadeToggle<cr>", desc = "Toggle window opacity" },
  },
}
```

## Configuration

Calling `require("hyprfade").setup()` is optional; the plugin auto-initialises
from `plugin/hyprfade.lua`. Pass opts to customise:

```lua
require("hyprfade").setup({
  opacity = 0.85,              -- normal editing opacity
  term_names = {               -- process names to recognise as terminals
    "kitty", "alacritty", "foot", "wezterm",
  },
  set_on_enter = true,         -- apply opacity on VimEnter
  reset_on_leave = true,       -- reset to fully opaque on VimLeavePre
})
```

| Option          | Type    | Default                                                   | Description                         |
|-----------------|---------|-----------------------------------------------------------|-------------------------------------|
| `opacity`       | number  | `0.85`                                                    | Opacity value applied automatically |
| `term_names`    | table   | `{ "kitty", "alacritty", "foot", "wezterm" }`            | Process names to recognise          |
| `set_on_enter`  | boolean | `true`                                                    | Apply opacity on VimEnter           |
| `reset_on_leave`| boolean | `true`                                                    | Reset on VimLeavePre                |

## Commands

| Command             | Description                             |
|---------------------|-----------------------------------------|
| `HyprFade [value]`  | Set opacity to a specific value (0–1)   |
| `HyprFadeToggle`    | Toggle between invisible (0) and normal |
| `HyprFadeReset`     | Reset to fully opaque and unlocked      |

## Known limitations

PID resolution walks the `/proc` tree upwards from Neovim's PID through the
parent chain. If the ancestor chain reparents to PID 1 before hitting a known
terminal name (e.g. some detached spawn paths), resolution fails. A warning is
logged via `vim.notify`.
