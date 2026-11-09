-- Herdr back-end for smart-splits.nvim.
--
-- Upstream smart-splits only ships tmux / wezterm / kitty / zellij back-ends,
-- and `smart-splits.mux` resolves one by `require('smart-splits.mux.<name>')`.
-- ~/.config/nvim comes before the lazy plugin dir on the runtimepath, so this
-- file is what that require finds for 'herdr'. Delete it if upstream ever
-- ships its own.
--
-- Selected in custom/plugins/smart-splits.lua by setting
-- vim.g.smart_splits_multiplexer_integration = 'herdr' when $HERDR_ENV is set.
--
-- Contract: the SmartSplitsMultiplexer class in smart-splits/types.lua.
-- Counterpart on the Herdr side: ~/.config/herdr/scripts/nav.sh forwards
-- C-h/j/k/l into this nvim when a pane is running vim, the same branch the
-- vim-tmux-navigator stanza does in tmux.conf.

local types = require('smart-splits.types')
local Direction = types.Direction

local function bin()
  local b = vim.env.HERDR_BIN_PATH
  if b == nil or b == '' then
    return 'herdr'
  end
  return b
end

---This nvim's own pane, not the focused one: a keypress reaches us only in the
---focused pane, and addressing by id avoids racing the UI.
---@return string|nil
local function own_pane()
  local p = vim.env.HERDR_PANE_ID
  if p == nil or p == '' then
    return nil
  end
  return p
end

---Run a herdr CLI command and decode its JSON reply.
---@param args string[]
---@return table|nil
local function cli(args)
  local cmd = { bin() }
  vim.list_extend(cmd, args)
  local ok, res = pcall(function()
    return vim.system(cmd, { text = true }):wait(1000)
  end)
  if not ok or res == nil or res.code ~= 0 then
    return nil
  end
  local decoded_ok, decoded = pcall(vim.json.decode, res.stdout or '')
  if not decoded_ok then
    return nil
  end
  return decoded
end

-- `pane edges` answers three interface questions in one round trip: which
-- sides of the layout this pane touches, which pane currently has focus, and
-- whether the tab is zoomed. One move_pane asks for all of those plus a focus
-- call, so the reply is memoised briefly and dropped the moment focus moves.
local cache = { edges = nil, at = 0 }
local CACHE_MS = 40

local function invalidate()
  cache.edges = nil
  cache.at = 0
end

---@return table|nil
local function edges()
  local now = vim.uv.now()
  if cache.edges ~= nil and (now - cache.at) < CACHE_MS then
    return cache.edges
  end
  local pane = own_pane()
  if not pane then
    return nil
  end
  local data = cli({ 'pane', 'edges', '--pane', pane })
  cache.edges = data and data.result and data.result.edges or nil
  cache.at = now
  return cache.edges
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = 'herdr' ---@diagnostic disable-line: assign-type-mismatch

function M.is_in_session()
  return vim.env.HERDR_ENV ~= nil and vim.env.HERDR_ENV ~= '' and own_pane() ~= nil
end

---The focused pane, not this one: smart-splits calls this before and after
---next_pane and treats an unchanged id as "the multiplexer did not move".
---@return string|nil
function M.current_pane_id()
  local e = edges()
  if not e or not e.layout then
    return nil
  end
  return e.layout.focused_pane_id
end

---True when nothing of ours lies further in that direction.
---@param direction SmartSplitsDirection
function M.current_pane_at_edge(direction)
  local e = edges()
  if not e then
    return false
  end
  return e[direction] == true
end

function M.current_pane_is_zoomed()
  local e = edges()
  return (e and e.layout and e.layout.zoomed) == true
end

---@param direction SmartSplitsDirection
function M.next_pane(direction)
  local pane = own_pane()
  if not pane then
    return false
  end
  local data = cli({ 'pane', 'focus', '--direction', direction, '--pane', pane })
  invalidate()
  if not data or not data.result or not data.result.focus then
    return false
  end
  -- Herdr exits 0 with changed=false and reason="no_neighbor" at the edge.
  return data.result.focus.changed == true
end

---Herdr sizes splits by ratio of the tab area; smart-splits counts cells.
---@param amount number cells
---@param direction SmartSplitsDirection
---@return number|nil ratio
local function cells_to_ratio(amount, direction)
  local e = edges()
  if not e or not e.layout or not e.layout.area then
    return nil
  end
  local span = (direction == Direction.left or direction == Direction.right) and e.layout.area.width
    or e.layout.area.height
  if not span or span <= 0 then
    return nil
  end
  return amount / span
end

---@param direction SmartSplitsDirection
---@param amount number
function M.resize_pane(direction, amount)
  local pane = own_pane()
  local ratio = pane and cells_to_ratio(amount, direction) or nil
  if not ratio then
    return false
  end
  local data = cli({
    'pane',
    'resize',
    '--direction',
    direction,
    '--amount',
    string.format('%.4f', ratio),
    '--pane',
    pane,
  })
  invalidate()
  return data ~= nil
end

---@param direction SmartSplitsDirection
---@param size number|nil cells
function M.split_pane(direction, size)
  local pane = own_pane()
  if not pane then
    return false
  end
  -- Herdr only splits right and down, so left/up is a split followed by a swap
  -- of this pane with the one it just created.
  local placement = (direction == Direction.left or direction == Direction.right) and 'right' or 'down'
  local args = { 'pane', 'split', '--direction', placement, '--pane', pane }
  local ratio = size and cells_to_ratio(size, direction) or nil
  if ratio then
    vim.list_extend(args, { '--ratio', string.format('%.4f', ratio) })
  end
  local data = cli(args)
  if not data then
    return false
  end
  if direction == Direction.left or direction == Direction.up then
    cli({ 'pane', 'swap', '--direction', placement, '--pane', pane })
  end
  invalidate()
  return true
end

function M.update_mux_layout_details()
  invalidate()
end

return M
