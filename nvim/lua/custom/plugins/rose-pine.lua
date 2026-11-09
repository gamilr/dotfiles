-- Rose Pine colorscheme (elegant, minimal, soft colors)
-- Variants: main, moon, dawn
-- Switch to it with:  :colorscheme rose-pine
return {
  'rose-pine/neovim',
  name = 'rose-pine',
  lazy = false,
  priority = 1000,
  opts = {
    variant = 'main',
    dim_inactive_windows = true,
  },
}
