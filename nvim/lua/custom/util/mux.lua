-- Picks the multiplexer this nvim is actually running under. Both backends
-- expose the same split/pane_alive/kill_pane/focus_pane shape, so callers do
-- not branch on which one came back.

local M = {}

---@return table|nil module, string|nil name
function M.get()
  local herdr = require('custom.util.herdr')
  if herdr.available() then
    return herdr, 'herdr'
  end

  local tmux = require('custom.util.tmux')
  if tmux.in_tmux() then
    return tmux, 'tmux'
  end

  return nil, nil
end

return M
