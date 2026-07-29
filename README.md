# hyprfade.nvim

Seamlessly fade the terminal window hosting Neovim on Hyprland by setting its
window opacity via `hyprctl dispatch setprop pid:<pid> opacity`.

## Why

Hyprland window rules based on `class` or `title` can miss the terminal window
when Neovim is launched from a file manager like yazi, because the window's
class hasn't been resolved yet. Matching on `pid:` sidesteps this entirely.

## Requirements

- Hyprland 0.53.0+ (uses the `opacity` / `opacity_inactive` setprop props;
  older Hyprland versions used `alpha` / `alphainactive` instead and aren't
  supported)
- `hyprctl` on `PATH`
- A supported terminal emulator (kitty, alacritty, foot, wezterm)

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Senal-D-A-Gunaratna/hyprfade.nvim",
  event = "VeryLazy",
  opts = {
    opacity = 0.85,              -- normal editing opacity
    term_names = {               -- process names to recognise as terminals
      "kitty", "alacritty", "foot", "wezterm",
    },
    set_on_enter = true,         -- apply opacity on VimEnter, if available
    reset_on_leave = true,       -- reset to fully opaque on VimLeavePre, if available
    notify_on_missing = true,    -- warn via vim.notify when hyprctl/pid isn't available
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
  set_on_enter = true,         -- apply opacity on VimEnter, if available
  reset_on_leave = true,       -- reset to fully opaque on VimLeavePre, if available
  notify_on_missing = true,    -- warn via vim.notify when hyprctl/pid isn't available
})
```

| Option              | Type    | Default                                       | Description                                                             |
|---------------------|---------|------------------------------------------------|---------------------------------------------------------------------------|
| `opacity`           | number  | `0.85`                                          | Opacity value applied automatically                                     |
| `term_names`        | table   | `{ "kitty", "alacritty", "foot", "wezterm" }`  | Process names to recognise                                              |
| `set_on_enter`      | boolean | `true`                                          | Apply opacity on `VimEnter`, if `hyprctl` and the terminal pid are available |
| `reset_on_leave`    | boolean | `true`                                          | Reset on `VimLeavePre`, if available                                    |
| `notify_on_missing` | boolean | `true`                                          | Whether to `vim.notify` a warning when `hyprctl` isn't on `PATH` or the terminal pid can't be resolved. Set to `false` to fail silently (e.g. on a non-Hyprland machine) |

**"If not available" behaviour:** every entry point (`set_on_enter`,
`reset_on_leave`, `HyprFade`, `HyprFadeToggle`, `HyprFadeReset`) checks for
`hyprctl` on `PATH` and a resolvable terminal pid before doing anything. If
either is missing, the call is a no-op — nothing errors, opacity just isn't
applied. This makes it safe to load the plugin unconditionally even outside
a Hyprland session (e.g. nvim over SSH, or on X11/another compositor); set
`notify_on_missing = false` if you don't want the warning in that case.

## Commands

| Command             | Description                             |
|---------------------|-----------------------------------------|
| `HyprFade [value]`  | Set opacity to a specific value (0–1)   |
| `HyprFadeToggle`    | Toggle between invisible (0) and normal |
| `HyprFadeReset`     | Reset to fully opaque and unlocked      |

## How opacity is actually applied

Hyprland 0.53.0 removed the old `alpha` / `alphainactive` setprop props.
The plugin now issues (via `hyprctl --batch`, in one round trip):

```
dispatch setprop pid:<pid> opacity_override 1
dispatch setprop pid:<pid> opacity <value> lock
dispatch setprop pid:<pid> opacity_inactive_override 1
dispatch setprop pid:<pid> opacity_inactive <value> lock
```

Both `opacity` and `opacity_inactive` are set (not just `opacity`), because
Hyprland resets opacity to `1.0` the moment the window loses focus if only
the active-state prop is overridden. `lock` prevents a window rule from
overriding the value afterwards; `reset()` clears both `*_override` flags
(and unlocks) so rules/defaults take back over once Neovim exits.

## Known limitations

PID resolution walks the `/proc` tree upwards from Neovim's PID through the
parent chain. If the ancestor chain reparents to PID 1 before hitting a known
terminal name (e.g. some detached spawn paths), resolution fails. A warning is
logged via `vim.notify` unless `notify_on_missing = false`.
