-- Everforest colorscheme (nature-inspired, easy on the eyes)
-- Backgrounds: hard, medium, soft
-- Switch to it with:  :colorscheme everforest
return {
  'sainnhe/everforest',
  lazy = false,
  priority = 1000,
  config = function()
    vim.g.everforest_background = 'hard'
    vim.g.everforest_better_performance = 1
    -- Brighter line numbers, indent lines, and other UI chrome
    vim.g.everforest_ui_contrast = 'high'
    -- Darken both panes; active is darkest, inactive slightly lighter
    vim.api.nvim_create_autocmd('ColorScheme', {
      pattern = 'everforest',
      group = vim.api.nvim_create_augroup('everforest-dim-panes', { clear = true }),
      callback = function()
        local normal = vim.api.nvim_get_hl(0, { name = 'Normal' })
        local bg = normal.bg
        if not bg then
          return
        end
        local function scale(color, factor)
          local r = math.floor(bit.rshift(bit.band(color, 0xFF0000), 16) * factor)
          local g = math.floor(bit.rshift(bit.band(color, 0x00FF00), 8) * factor)
          local b = math.floor(bit.band(color, 0x0000FF) * factor)
          return string.format('#%02x%02x%02x', r, g, b)
        end
        vim.api.nvim_set_hl(0, 'Normal', { fg = normal.fg, bg = scale(bg, 0.80) })
        vim.api.nvim_set_hl(0, 'NormalNC', { bg = scale(bg, 0.90) })
      end,
    })
  end,
}
