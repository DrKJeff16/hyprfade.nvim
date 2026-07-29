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
  lazy = false,
  priority = 1000,
  opts = {
    opacity = 0.7,              -- normal editing opacity
    term_names = {               -- process names to recognise as terminals
      "kitty", "alacritty", "foot", "wezterm",
    },
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
  opacity = 0.7,              -- normal editing opacity
  term_names = {                -- process names to recognise as terminals
    "kitty", "alacritty", "foot", "wezterm",
  },
})
```

| Option       | Type   | Default                                        | Description                  |
| ------------ | ------ | ----------------------------------------------- | ----------------------------- |
| `opacity`    | number | `0.85`                                          | Opacity value applied automatically |
| `term_names` | table  | `{ "kitty", "alacritty", "foot", "wezterm" }`  | Process names to recognise    |

Opacity is always applied as soon as `setup()` runs, and always reset to
fully opaque on `VimLeavePre` — these aren't configurable. If `hyprctl` isn't
on `PATH` or the terminal pid can't be resolved, every entry point
(`setup()`, `HyprFade`, `HyprFadeToggle`, `HyprFadeReset`) no-ops and warns
via `vim.notify` rather than erroring, so it's safe to load the plugin
unconditionally even outside a Hyprland session (e.g. nvim over SSH, or on
X11/another compositor).

## Commands

| Command            | Description                             |
| ------------------ | --------------------------------------- |
| `HyprFade [value]` | Set opacity to a specific value (0–1)   |
| `HyprFadeToggle`   | Toggle between invisible (0) and normal |
| `HyprFadeReset`    | Reset to fully opaque and unlocked      |

## How opacity is actually applied

Hyprland 0.55 (May 2026) replaced the classic `hyprctl dispatch <name>
<args...>` calling convention with a Lua expression API — the old
space-separated `dispatch setprop pid:X opacity 0.5` form is rejected
outright with a Lua syntax error on 0.55+. The plugin uses the current
typed form instead, batched into a single `hyprctl eval` call:

```lua
hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_override", value = 1, window = "pid:<pid>" }))
hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity", value = <value>, window = "pid:<pid>" }))
hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_inactive_override", value = 1, window = "pid:<pid>" }))
hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_inactive", value = <value>, window = "pid:<pid>" }))
```

Both `opacity` and `opacity_inactive` are set (not just `opacity`), because
Hyprland resets opacity to `1.0` the moment the window loses focus if only
the active-state prop is overridden. Each value requires its matching
`*_override` flag set to `1`, or Hyprland ignores it. `reset()` clears both
`*_override` flags back to `0` so window rules/defaults take back over once
Neovim exits.

Opacity is applied immediately when `setup()` runs, rather than waiting for
a `VimEnter` autocmd. This matters for lazy-loaded installs: lazy.nvim's
`VeryLazy` event (used in the install snippet above) fires _after_
`VimEnter` has already completed for the session, so a `VimEnter` autocmd
registered inside `setup()` would never fire.

## Known limitations

PID resolution walks the `/proc` tree upwards from Neovim's PID through the
parent chain. If the ancestor chain reparents to PID 1 before hitting a known
terminal name (e.g. some detached spawn paths), resolution fails and a
warning is logged via `vim.notify`.
