local M = {}

local defaults = {
  opacity = 0.85,
  term_names = { "kitty", "alacritty", "foot", "wezterm" },
  set_on_enter = true,
  reset_on_leave = true,
  notify_on_missing = true,
}

local opts = {}
local current = nil
local terminal_pid = nil

local function warn(msg)
  if opts.notify_on_missing ~= false then
    vim.notify("hyprfade: " .. msg, vim.log.levels.WARN)
  end
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

local function set_opacity(value, lock)
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
  local lock_suffix = (lock ~= false) and " lock" or ""

  local cmds = {
    ("dispatch setprop %s opacity_override 1"):format(selector),
    ("dispatch setprop %s opacity %s%s"):format(selector, tostring(value), lock_suffix),
    ("dispatch setprop %s opacity_inactive_override 1"):format(selector),
    ("dispatch setprop %s opacity_inactive %s%s"):format(selector, tostring(value), lock_suffix),
  }

  vim.system({ "hyprctl", "--batch", table.concat(cmds, " ; ") }, nil, function() end)
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
  local cmds = {
    ("dispatch setprop %s opacity_override 0"):format(selector),
    ("dispatch setprop %s opacity_inactive_override 0"):format(selector),
  }
  vim.system({ "hyprctl", "--batch", table.concat(cmds, " ; ") }, nil, function() end)
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

  -- NOTE: set_on_enter used to hook VimEnter. That breaks under lazy
  -- loading (e.g. `event = "VeryLazy"`), because VeryLazy fires *after*
  -- VimEnter has already completed for this session — by the time
  -- setup() runs and registers the autocmd, VimEnter has already fired
  -- and won't fire again, so opacity was never applied on startup.
  -- setup() being called at all (eager or lazy) is itself the "the
  -- plugin is now active" signal, so just apply immediately here.
  local group = vim.api.nvim_create_augroup("hyprfade", { clear = true })

  if opts.set_on_enter then
    set_opacity(opts.opacity)
  end

  if opts.reset_on_leave then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      callback = function()
        reset()
      end,
    })
  end
end

return M
