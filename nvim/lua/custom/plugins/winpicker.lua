return {
  's1n7ax/nvim-window-picker',
  name = 'window-picker',
  event = 'VeryLazy',
  version = '2.*',
  config = function()
    require('window-picker').setup {
      highlights = {
        statusline = {
          focused = { fg = '#D8DEE9', bg = '#81A1C1', bold = true },
          unfocused = { fg = '#D8DEE9', bg = '#4C566A', bold = true },
        },
        winbar = {
          focused = { fg = '#D8DEE9', bg = '#81A1C1', bold = true },
          unfocused = { fg = '#D8DEE9', bg = '#4C566A', bold = true },
        },
      },
    }
  end,
}
