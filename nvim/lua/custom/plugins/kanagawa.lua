-- Kanagawa colorscheme (Japanese wave art aesthetic)
-- Themes: wave (dark), dragon (darker), lotus (light)
-- Switch to it with:  :colorscheme kanagawa
return {
  'rebelot/kanagawa.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    theme = 'wave',
    dimInactive = true,
  },
}
