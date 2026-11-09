-- opencode.nvim's ask('@this: ') and operator('@this ') for Claude Code.
--
-- Claude's IDE link can push @-mentions but cannot write prompt text, so this
-- types into the Claude pane through the multiplexer instead: `@this` becomes
-- the same `@path#Lstart-end` reference the IDE inserts for a selection.

local M = {}

local state = function() return require('custom.util.claude_state') end

---Cursor line in normal mode, the selected lines in visual mode. Leaves
---visual mode, since the input float would otherwise inherit it. `path` is
---nil when the buffer is not a file (empty buffer, file tree, terminal).
---@return { path: string|nil, first: integer, last: integer }
local function capture()
  local first, last
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    first, last = vim.fn.line('v'), vim.fn.line('.')
    if first > last then first, last = last, first end
    vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
  else
    first = vim.fn.line('.')
    last = first
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' or vim.bo.buftype ~= '' then
    return { first = first, last = last }
  end
  -- Relative to nvim's cwd, which is the Claude pane's directory; absolute
  -- when the file sits outside it.
  return { path = vim.fn.fnamemodify(name, ':.'), first = first, last = last }
end

---@param ctx { path: string, first: integer, last: integer }
---@return string
local function reference(ctx)
  if ctx.first == ctx.last then
    return string.format('@%s#L%d', ctx.path, ctx.first)
  end
  return string.format('@%s#L%d-%d', ctx.path, ctx.first, ctx.last)
end

---The tracked Claude pane, or the only one in this workspace (adopted on the
---way). Several candidates need an explicit <leader>cl.
---@return table|nil mux, string|nil pane, 'none'|nil missing
local function target()
  local mux = require('custom.util.mux').get()
  if not mux then
    vim.notify('No multiplexer detected - cannot reach Claude', vim.log.levels.WARN)
    return nil
  end
  local st = state()
  if mux.pane_alive(st.pane) then return mux, st.pane end
  local panes = mux.agent_panes('claude')
  if #panes == 1 then
    st.pane = panes[1].pane_id
    require('custom.util.ai_panes').register(st.pane)
    return mux, st.pane
  end
  if #panes == 0 then return nil, nil, 'none' end
  vim.notify('Several Claude panes - pick one with <leader>cl', vim.log.levels.WARN)
  return nil
end

---Claude sessions that finished the WebSocket handshake with this nvim.
---@return integer
local function linked_clients()
  local ok, server = pcall(require, 'claudecode.server.init')
  if not ok then return 0 end
  local n = 0
  for _, client in ipairs(server.get_status().clients or {}) do
    if client.handshake_complete then n = n + 1 end
  end
  return n
end

local START_TIMEOUT_MS = 30000
local START_POLL_MS = 200
-- The link comes up while the TUI is still drawing; give the prompt a moment.
local START_SETTLE_MS = 500

---Open Claude the way <leader>cc does, without focus, and call `cb` once the
---new session has linked back to this nvim. Text typed before that point can
---land in a TUI that is not reading yet and get lost.
---@param cb fun(mux: table|nil, pane: string|nil)
local function start_then(cb)
  local before = linked_clients()
  require('claudecode.terminal').open()
  local mux = require('custom.util.mux').get()
  local waited = 0
  local function poll()
    local pane = state().pane
    if pane and mux.pane_alive(pane) and linked_clients() > before then
      vim.defer_fn(function() cb(mux, pane) end, START_SETTLE_MS)
      return
    end
    waited = waited + START_POLL_MS
    if waited >= START_TIMEOUT_MS then return cb(nil, nil) end
    vim.defer_fn(poll, START_POLL_MS)
  end
  vim.defer_fn(poll, START_POLL_MS)
end

---Send to the Claude pane, starting one first when the workspace has none.
---@param text string
---@param submit boolean
local function send(text, submit)
  local function deliver(mux, pane)
    if not mux.send_text(pane, text, submit) then
      vim.notify('Failed to send to Claude pane ' .. pane, vim.log.levels.ERROR)
      return
    end
    if not submit then mux.focus_pane(pane) end
  end

  local mux, pane, missing = target()
  if mux then return deliver(mux, pane) end
  if missing ~= 'none' then return end

  vim.notify('Starting Claude...')
  start_then(function(m, p)
    if not m then
      vim.fn.setreg('"', text)
      vim.notify('Claude did not link to nvim within 30s - the prompt is in register "', vim.log.levels.WARN)
      return
    end
    deliver(m, p)
  end)
end

---Prompt for a message with `@this` prefilled, expand it, and submit. Outside
---a file there is nothing for `@this` to point at, so the prompt starts empty.
---@param default string|nil
function M.ask(default)
  local ctx = capture()
  local opts = { prompt = 'Ask Claude: ', default = default or (ctx.path and '@this: ' or '') }
  -- Same placement as opencode.nvim's ask: a float just above the cursor.
  -- snacks.input reads these at the root; native vim.ui.input errors on them.
  -- Called directly: snacks only swaps vim.ui.input in on UIEnter.
  local input_fn = vim.ui.input
  local ok, snacks = pcall(require, 'snacks')
  if ok and snacks.config.get('input', {}).enabled then
    opts.icon = '󰚩 '
    opts.win = { title_pos = 'left', relative = 'cursor', row = -3, col = 0 }
    input_fn = snacks.input.input
  end
  input_fn(opts, function(input)
    if not input or vim.trim(input) == '' then return end
    if ctx.path then
      input = input:gsub('@this', function() return reference(ctx) end)
    elseif input:find('@this', 1, true) then
      vim.notify('@this needs a file buffer - not sent', vim.log.levels.WARN)
      return
    end
    send(input, true)
  end)
end

---Append `@this` to Claude's prompt without submitting, then focus the pane
---to keep typing there.
function M.append()
  local ctx = capture()
  if not ctx.path then
    vim.notify('@this needs a file buffer', vim.log.levels.WARN)
    return
  end
  send(reference(ctx) .. ' ', false)
end

return M
