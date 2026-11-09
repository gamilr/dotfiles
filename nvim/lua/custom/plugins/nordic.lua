-- Nordic colorscheme (Nord, but warmer and darker)
-- Switch to it with:  :colorscheme nordic
return {
  'AlexvZyl/nordic.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    bold_keywords = false,
    italic_comments = true,
    transparent = {
      bg = false,
      float = false,
    },
    bright_border = false,
    reduced_blue = true,
    swap_backgrounds = false,
    cursorline = {
      bold = false,
      bold_number = true,
      theme = 'dark',
      blend = 0.85,
    },
    telescope = {
      style = 'flat',
    },
    ts_context = {
      dark_background = true,
    },
  },
}
