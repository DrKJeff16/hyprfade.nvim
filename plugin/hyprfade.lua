if vim.g.hyprfade_loaded then
  return
end
vim.g.hyprfade_loaded = true

require("hyprfade").setup()
