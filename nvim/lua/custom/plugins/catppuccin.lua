-- Catppuccin colorscheme (warm pastel theme)
-- Flavors: latte, frappe, macchiato, mocha
-- Switch to it with:  :colorscheme catppuccin
return {
  'catppuccin/nvim',
  name = 'catppuccin',
  lazy = false,
  priority = 1000,
  opts = {
    flavour = 'mocha',
    dim_inactive = {
      enabled = true,
    },
  },
}
