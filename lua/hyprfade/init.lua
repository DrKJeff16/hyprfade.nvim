local M = {}

local defaults = {
  opacity = 0.85,
  term_names = { "kitty", "alacritty", "foot", "wezterm" },
  set_on_enter = true,
  reset_on_leave = true,
}

local opts = {}
local current = nil
local terminal_pid = nil

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
    vim.notify("hyprfade: hyprctl not found on PATH", vim.log.levels.WARN)
    return
  end

  local pid = find_terminal_pid()
  if not pid then
    vim.notify("hyprfade: could not resolve terminal PID", vim.log.levels.WARN)
    return
  end

  local args = {
    "dispatch", "setprop",
    ("pid:%d"):format(pid),
    "alpha", tostring(value),
  }
  if lock ~= false then
    table.insert(args, "lock")
  end

  vim.system({ "hyprctl", unpack(args) }, nil, function() end)
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
    vim.notify("hyprfade: hyprctl not found on PATH", vim.log.levels.WARN)
    return
  end

  local pid = find_terminal_pid()
  if not pid then
    vim.notify("hyprfade: could not resolve terminal PID", vim.log.levels.WARN)
    return
  end

  vim.system({
    "hyprctl", "dispatch", "setprop",
    ("pid:%d"):format(pid),
    "alpha", "1.0",
  }, nil, function() end)
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

  if opts.set_on_enter then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("hyprfade", { clear = true }),
      callback = function()
        set_opacity(opts.opacity)
      end,
    })
  end

  if opts.reset_on_leave then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("hyprfade", { clear = true }),
      callback = function()
        reset()
      end,
    })
  end
end

return M
