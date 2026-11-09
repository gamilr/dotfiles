-- Gruvbox colorscheme
-- Switch to it with:  :colorscheme gruvbox
return {
  'ellisonleao/gruvbox.nvim',
  priority = 1000,
  opts = {
    undercurl = true,
    underline = true,
    bold = false,
    strikethrough = true,
    invert_selection = false,
    invert_signs = false,
    invert_tabline = false,
    invert_intend_guides = false,
    inverse = true,
    contrast = 'hard',
    palette_overrides = {},
    overrides = {},
    dim_inactive = true,
    transparent_mode = false,
  },
}
