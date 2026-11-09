-- claudecode.nvim keeps the MCP server, diffs and send commands inside nvim,
-- but runs the CLI itself in a multiplexer pane beside the editor.
--
-- This is a custom terminal provider rather than provider = "none" plus a
-- keymap: the plugin hands a provider table the command string and the env it
-- expects (ENABLE_IDE_INTEGRATION, FORCE_CODE_TERMINAL, CLAUDE_CODE_SSE_PORT),
-- so :ClaudeCode, :ClaudeCodeFocus, :ClaudeCodeClose and the arg-taking forms
-- all work instead of being no-ops. custom/util/mux.lua picks Herdr or tmux.

local ai = function() return require('custom.util.ai_panes') end
local state = function() return require('custom.util.claude_state') end

---The plugin passes env as a table; both backends take a command line, so fold
---it into a prefix. Sorted for a stable, readable command in the pane.
---@param env table<string,string>|nil
---@return string
local function env_prefix(env)
  local parts = {}
  for k, v in pairs(env or {}) do
    parts[#parts + 1] = string.format('%s=%s', k, vim.fn.shellescape(tostring(v)))
  end
  table.sort(parts)
  return #parts > 0 and (table.concat(parts, ' ') .. ' ') or ''
end

local provider = {}

function provider.setup(_) end

function provider.is_available()
  return require('custom.util.mux').get() ~= nil
end

-- Claude runs outside nvim, so there is no buffer to hand back. The plugin
-- treats nil as "not an in-editor provider".
function provider.get_active_bufnr()
  return nil
end

---@param cmd_string string
---@param env_table table<string,string>
---@param _effective_config table
---@param focus boolean|nil
function provider.open(cmd_string, env_table, _effective_config, focus)
  local mux, name = require('custom.util.mux').get()
  if not mux then
    vim.notify('No multiplexer detected - run `claude` manually to connect', vim.log.levels.WARN)
    return
  end

  local st = state()
  if mux.pane_alive(st.pane) then
    if focus ~= false then mux.focus_pane(st.pane) end
    return
  end

  local cmd = env_prefix(env_table) .. cmd_string

  -- Stack below an AI pane that is already open, otherwise take a column to
  -- the left of nvim.
  local existing = ai().first_alive(mux)
  local opts = { cmd = cmd, focus = focus == true }
  if existing then
    opts.direction, opts.target, opts.size = 'v', existing, '50%'
  else
    opts.direction, opts.before, opts.size = 'h', true, '40%'
  end

  st.pane = mux.split(opts)
  if not st.pane then
    vim.notify('Failed to open a Claude pane in ' .. name, vim.log.levels.ERROR)
    return
  end
  ai().register(st.pane)
end

function provider.close()
  local mux = require('custom.util.mux').get()
  local st = state()
  if not mux or not st.pane then return end
  mux.kill_pane(st.pane)
  ai().unregister(st.pane)
  st.pane = nil
end

function provider.simple_toggle(cmd_string, env_table, effective_config)
  local mux = require('custom.util.mux').get()
  if mux and mux.pane_alive(state().pane) then
    provider.close()
  else
    provider.open(cmd_string, env_table, effective_config, true)
  end
end

---Point the provider at a Claude pane started outside nvim, so focus, toggle
---and close act on it instead of spawning a second session. The MCP link is
---separate: that session connects itself (autoConnectIde, or /ide).
local function adopt()
  local mux, name = require('custom.util.mux').get()
  if not mux then
    vim.notify('No multiplexer detected - nothing to adopt', vim.log.levels.WARN)
    return
  end
  local st = state()

  local function take(pane)
    if st.pane and st.pane ~= pane.pane_id then ai().unregister(st.pane) end
    st.pane = pane.pane_id
    ai().register(pane.pane_id)
    vim.notify('Claude pane adopted: ' .. pane.label)
    -- Adopting only moves the pane keys. Sends and @-mentions need that
    -- session's own WebSocket link, which it makes at startup (missed if nvim
    -- came up after it) or via /ide.
    local ok, cc = pcall(require, 'claudecode')
    if ok and not cc.is_claude_connected() then
      vim.notify('No Claude session is linked to this nvim - run /ide in ' .. pane.pane_id .. ' and pick Neovim',
        vim.log.levels.WARN)
    end
  end

  local panes = mux.agent_panes('claude')
  if #panes == 0 then
    vim.notify('No Claude pane found in this ' .. name .. ' workspace', vim.log.levels.WARN)
  elseif #panes == 1 then
    take(panes[1])
  else
    vim.ui.select(panes, {
      prompt = 'Adopt Claude pane',
      format_item = function(p) return (p.pane_id == st.pane and '* ' or '  ') .. p.label end,
    }, function(choice)
      if choice then take(choice) end
    end)
  end
end

vim.api.nvim_create_user_command('ClaudeCodeAdopt', adopt, { desc = 'Adopt a running Claude pane' })

-- Focus rather than close when the pane is already up, which is what the old
-- tmux keymap did.
function provider.focus_toggle(cmd_string, env_table, effective_config)
  local mux = require('custom.util.mux').get()
  local st = state()
  if mux and mux.pane_alive(st.pane) then
    mux.focus_pane(st.pane)
  else
    provider.open(cmd_string, env_table, effective_config, true)
  end
end

return {
  'coder/claudecode.nvim',
  -- Load at startup, not on the first <leader>c key: the IDE server only runs
  -- once the plugin loads, and a Claude started before that cannot link.
  event = 'VeryLazy',
  opts = {
    terminal = {
      provider = provider,
    },
  },
  keys = {
    { '<leader>c', nil, desc = 'AI/Claude Code' },
    { '<leader>cc', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
    { '<leader>cR', '<cmd>ClaudeCode --resume<cr>', desc = 'Resume Claude' },
    { '<leader>cC', '<cmd>ClaudeCode --continue<cr>', desc = 'Continue Claude' },
    { '<leader>cf', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
    { '<leader>cq', '<cmd>ClaudeCodeClose<cr>', desc = 'Close Claude pane' },
    { '<leader>cl', '<cmd>ClaudeCodeAdopt<cr>', desc = 'Link existing Claude pane' },
    -- opencode's <leader>at / <leader>ar|al: @this = cursor line, or the selection.
    {
      '<leader>ct',
      function() require('custom.util.claude_prompt').ask() end,
      mode = { 'n', 'x' },
      desc = 'Ask Claude about @this',
    },
    {
      '<leader>ci',
      function() require('custom.util.claude_prompt').append() end,
      mode = { 'n', 'x' },
      desc = 'Append @this to Claude prompt',
    },
    { '<leader>cm', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'Select Claude model' },
    { '<leader>cb', '<cmd>ClaudeCodeAdd %<cr>', desc = 'Add current buffer' },
    { '<leader>cs', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
    { '<leader>ca', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept diff' },
    { '<leader>cd', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny diff' },
    -- File-tree-scoped: only active in those buffers, so it doesn't collide with opencode's <leader>as
    {
      '<leader>as',
      '<cmd>ClaudeCodeTreeAdd<cr>',
      desc = 'Add file to Claude (tree)',
      ft = { 'NvimTree', 'neo-tree', 'oil', 'minifiles', 'netrw' },
    },
  },
}
