-- Smart pane navigation and resizing via smart-splits.nvim
-- Navigation: C-h/j/k/l | Resize: C-b + h/j/k/l
return {
  'mrjones2014/smart-splits.nvim',
  event = 'VeryLazy',
  -- Multiplexer back-end. tmux/wezterm/kitty/zellij are auto-detected by the
  -- plugin; Herdr is not one it knows about, so point it at the local back-end
  -- in lua/smart-splits/mux/herdr.lua. It has to be a vim.g and not a setup()
  -- key: plugin/smart-splits.lua reads the setting and registers its autocmds
  -- when the plugin loads, which is before config() runs.
  init = function()
    if vim.env.HERDR_ENV ~= nil and vim.env.HERDR_ENV ~= '' then
      vim.g.smart_splits_multiplexer_integration = 'herdr'
    end
  end,
  config = function()
    local ss = require('smart-splits')

    ss.setup({
      default_amount = 10,
      -- 'stop' only applies once the multiplexer has declined the move:
      -- mux.move_pane runs first, so C-h/j/k/l still leave nvim for the
      -- neighbouring Herdr/tmux pane and only stop at the outer edge.
      at_edge = 'stop',
      ignored_buftypes = { 'nofile', 'quickfix', 'prompt' },
      ignored_filetypes = { 'NvimTree', 'neo-tree' },
    })

    -- Navigation: C-h/j/k/l (normal mode)
    vim.keymap.set('n', '<C-h>', ss.move_cursor_left, { desc = 'Move focus left' })
    vim.keymap.set('n', '<C-j>', ss.move_cursor_down, { desc = 'Move focus down' })
    vim.keymap.set('n', '<C-k>', ss.move_cursor_up, { desc = 'Move focus up' })
    vim.keymap.set('n', '<C-l>', ss.move_cursor_right, { desc = 'Move focus right' })

    -- Navigation: C-h/j/k/l (terminal mode — exit terminal first)
    vim.keymap.set('t', '<C-h>', function()
      vim.cmd('stopinsert')
      ss.move_cursor_left()
    end, { desc = 'Move focus left' })
    vim.keymap.set('t', '<C-j>', function()
      vim.cmd('stopinsert')
      ss.move_cursor_down()
    end, { desc = 'Move focus down' })
    vim.keymap.set('t', '<C-k>', function()
      vim.cmd('stopinsert')
      ss.move_cursor_up()
    end, { desc = 'Move focus up' })
    vim.keymap.set('t', '<C-l>', function()
      vim.cmd('stopinsert')
      ss.move_cursor_right()
    end, { desc = 'Move focus right' })

    -- Resize: C-b + h/j/k/l (normal mode)
    vim.keymap.set('n', '<C-b>h', ss.resize_left, { desc = 'Resize pane left' })
    vim.keymap.set('n', '<C-b>j', ss.resize_down, { desc = 'Resize pane down' })
    vim.keymap.set('n', '<C-b>k', ss.resize_up, { desc = 'Resize pane up' })
    vim.keymap.set('n', '<C-b>l', ss.resize_right, { desc = 'Resize pane right' })

    -- Resize: C-b + h/j/k/l (terminal mode)
    vim.keymap.set('t', '<C-b>h', function()
      vim.cmd('stopinsert')
      ss.resize_left()
    end, { desc = 'Resize pane left' })
    vim.keymap.set('t', '<C-b>j', function()
      vim.cmd('stopinsert')
      ss.resize_down()
    end, { desc = 'Resize pane down' })
    vim.keymap.set('t', '<C-b>k', function()
      vim.cmd('stopinsert')
      ss.resize_up()
    end, { desc = 'Resize pane up' })
    vim.keymap.set('t', '<C-b>l', function()
      vim.cmd('stopinsert')
      ss.resize_right()
    end, { desc = 'Resize pane right' })
  end,
}
