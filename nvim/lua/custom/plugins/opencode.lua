-- Module-level state: shared across start/stop/toggle calls.
local opencode_pane = nil

local function start()
  -- custom/util/mux.lua returns the Herdr or tmux backend, whichever this nvim
  -- is running under. Both expose the same split/pane_alive/kill_pane shape.
  local mux, name = require('custom.util.mux').get()
  local ai = require('custom.util.ai_panes')

  if not mux then
    vim.notify('opencode requires Herdr or tmux. Start nvim inside a session.', vim.log.levels.ERROR)
    return
  end
  if mux.pane_alive(opencode_pane) then return end

  -- If another AI pane (claude) is already alive, stack below it on the left.
  -- Otherwise split nvim and open on the left.
  -- Plain `opencode`: v2 dropped `--port` (it now exits with the help text).
  -- The TUI attaches to the shared background service, which opencode.nvim
  -- discovers on its own.
  local existing = ai.first_alive(mux)
  if existing then
    opencode_pane = mux.split({
      direction = 'v',
      target = existing,
      size = '50%',
      cmd = 'opencode',
      focus = false,
    })
  else
    opencode_pane = mux.split({
      direction = 'h',
      before = true,
      size = '40%',
      cmd = 'opencode',
      focus = false,
    })
  end

  if not opencode_pane then
    vim.notify('Failed to open an opencode pane in ' .. name, vim.log.levels.ERROR)
    return
  end
  ai.register(opencode_pane)
end

local function stop()
  local mux = require('custom.util.mux').get()
  local ai = require('custom.util.ai_panes')
  if opencode_pane then ai.unregister(opencode_pane) end
  if mux then mux.kill_pane(opencode_pane) end
  opencode_pane = nil
end

local function toggle()
  local mux = require('custom.util.mux').get()
  if mux and mux.pane_alive(opencode_pane) then
    stop()
  else
    start()
  end
end

return {
  -- `main` targets OpenCode v2 (background service, no `--port`). Its latest
  -- release tag still targets v1, so do not pin `version` here.
  'NickvanDyke/opencode.nvim',
  dependencies = {
    'folke/snacks.nvim', -- still used for input/picker enhancements
  },

  -- IMPORTANT: vim.g.opencode_opts must be set BEFORE opencode.nvim loads its
  -- defaults. `init` runs at nvim startup; `config` runs only after the plugin
  -- has already loaded with whatever was in g.opencode_opts at the time.
  init = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- `start` runs when the plugin finds no running OpenCode service. The
      -- plugin has no stop/toggle hook, so those live purely in our keymaps.
      server = {
        start = start,
      },
    }
    vim.o.autoread = true -- required for opts.events.reload
  end,

  config = function()
    -- v2 always sends complete messages, so ask() no longer takes a submit flag.
    vim.keymap.set({ 'n', 'x' }, '<leader>at', function()
      require('opencode').ask('@this: ')
    end, { desc = 'Ask opencode' })

    vim.keymap.set({ 'n', 'x' }, '<leader>as', function()
      require('opencode').select()
    end, { desc = 'Execute opencode action…' })

    -- NOT require('opencode').toggle(): the plugin has no such function. Its
    -- public API is ask/select/prompt/command/operator only. The multiplexer
    -- pane is driven by the local toggle() defined at the top of this file.
    vim.keymap.set({ 'n', 't' }, '<leader>aa', function()
      toggle()
    end, { desc = 'Toggle opencode' })

    vim.keymap.set({ 'n', 'x' }, '<leader>ar', function()
      return require('opencode').operator('@this ')
    end, { expr = true, desc = 'Add range to opencode' })

    vim.keymap.set('n', '<leader>al', function()
      return require('opencode').operator('@this ') .. '_'
    end, { expr = true, desc = 'Add line to opencode' })

    -- No TUI scroll maps: v2 removed the /tui/* control endpoints, and
    -- command() now runs OpenCode slash commands, not TUI actions.
  end,
}
