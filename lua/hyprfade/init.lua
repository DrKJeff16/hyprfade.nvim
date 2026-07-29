local M = {}

local defaults = {
  opacity = 0.85,
  term_names = { "kitty", "alacritty", "foot", "wezterm" },
}

local opts = {}
local current = nil
local terminal_pid = nil

local function warn(msg)
  vim.notify("hyprfade: " .. msg, vim.log.levels.WARN)
end

local function find_terminal_pid()
  if terminal_pid then
    return terminal_pid
  end

  local pid = vim.fn.getpid()
  local max_hops = 25

  for _ = 1, max_hops do
    local status_file = "/proc/" .. pid .. "/status"
    local ok, lines = pcall(vim.fn.readfile, status_file)
    if not ok or not lines then
      break
    end

    local name = nil
    local ppid = nil
    for _, line in ipairs(lines) do
      if line:match("^Name:") then
        name = line:match("^Name:%s+(.+)$")
      elseif line:match("^PPid:") then
        ppid = tonumber(line:match("^PPid:%s+(%d+)$"))
      end
    end

    if name then
      for _, term_name in ipairs(opts.term_names) do
        if name == term_name then
          terminal_pid = pid
          return pid
        end
      end
    end

    if ppid and ppid > 1 then
      pid = ppid
    else
      break
    end
  end

  return nil
end

-- Hyprland 0.55 (May 2026) replaced the classic `hyprctl dispatch <name>
-- <args...>` calling convention with a Lua expression API: `hyprctl
-- dispatch` now wraps its argument as `hl.dispatch(<your text>)` and runs
-- it through the Lua VM, so old space-separated args like
-- `dispatch setprop pid:X opacity 0.5` are rejected outright with a Lua
-- syntax error. This affects every dispatcher, not just setprop.
-- Ref: https://github.com/hyprwm/Hyprland/discussions/14255
--
-- The confirmed working form (from the Hyprland forum and the Window
-- Rules wiki page's own set_prop examples) is a typed table:
--   hl.dsp.window.set_prop({ prop = "...", value = ..., window = "..." })
--
-- `hyprctl eval '<lua>'` runs one or more semicolon-separated Lua
-- statements in a single round trip, so we chain all the set_prop calls
-- needed (override flag + value, for both active and inactive) into one
-- eval instead of several separate hyprctl invocations.
local function set_opacity(value)
  if vim.fn.executable("hyprctl") == 0 then
    warn("hyprctl not found on PATH")
    return
  end

  local pid = find_terminal_pid()
  if not pid then
    warn("could not resolve terminal PID")
    return
  end

  local selector = ("pid:%d"):format(pid)
  local function set_prop(prop, val)
    return ('hl.dispatch(hl.dsp.window.set_prop({ prop = "%s", value = %s, window = "%s" }))')
      :format(prop, tostring(val), selector)
  end

  local statements = {
    set_prop("opacity_override", 1),
    set_prop("opacity", value),
    set_prop("opacity_inactive_override", 1),
    set_prop("opacity_inactive", value),
  }

  vim.system({ "hyprctl", "eval", table.concat(statements, "; ") }, nil, function() end)
  current = value
end

local function toggle()
  if current == 0 then
    set_opacity(opts.opacity)
  else
    set_opacity(0)
  end
end

local function reset()
  if vim.fn.executable("hyprctl") == 0 then
    warn("hyprctl not found on PATH")
    return
  end

  local pid = find_terminal_pid()
  if not pid then
    warn("could not resolve terminal PID")
    return
  end

  local selector = ("pid:%d"):format(pid)
  local function set_prop(prop, val)
    return ('hl.dispatch(hl.dsp.window.set_prop({ prop = "%s", value = %s, window = "%s" }))')
      :format(prop, tostring(val), selector)
  end

  local statements = {
    set_prop("opacity_override", 0),
    set_prop("opacity", 1),
    set_prop("opacity_inactive_override", 0),
    set_prop("opacity_inactive", 1),
  }
  vim.fn.system({ "hyprctl", "eval", table.concat(statements, "; ") })
  current = nil
end

function M.setup(user_opts)
  opts = vim.tbl_deep_extend("keep", user_opts or {}, defaults)
  current = nil
  terminal_pid = nil

  vim.api.nvim_create_user_command("HyprFade", function(input)
    local val = tonumber(input.args)
    if val then
      set_opacity(val)
    else
      vim.notify("hyprfade: usage HyprFade <opacity>", vim.log.levels.ERROR)
    end
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("HyprFadeToggle", function()
    toggle()
  end, {})

  vim.api.nvim_create_user_command("HyprFadeReset", function()
    reset()
  end, {})

  -- NOTE: applying on setup() (rather than hooking VimEnter) matters for
  -- lazy loading: lazy.nvim's VeryLazy event fires *after* VimEnter has
  -- already completed for the session, so a VimEnter autocmd registered
  -- inside setup() would never fire. setup() being called at all (eager
  -- or lazy) is itself the "the plugin is now active" signal.
  set_opacity(opts.opacity)

  local group = vim.api.nvim_create_augroup("hyprfade", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      reset()
    end,
  })
end

return M
