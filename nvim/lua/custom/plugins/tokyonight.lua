-- TokyoNight colorscheme (clean Tokyo-inspired theme)
-- Styles: night, storm, day, moon
-- Switch to it with:  :colorscheme tokyonight
return {
  'folke/tokyonight.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    style = 'night',
    dim_inactive = true,
  },
}
