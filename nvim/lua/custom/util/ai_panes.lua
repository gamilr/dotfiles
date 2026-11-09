-- Shared registry of AI tmux pane IDs (claude, opencode, etc.).
-- Lets each AI plugin discover the others so they can stack as a left column
-- instead of fighting for the same slot.

local M = {}
M.panes = {}

function M.register(id)
  if not id or id == "" then return end
  for _, pid in ipairs(M.panes) do
    if pid == id then return end
  end
  table.insert(M.panes, id)
end

function M.unregister(id)
  for i, pid in ipairs(M.panes) do
    if pid == id then
      table.remove(M.panes, i)
      return
    end
  end
end

--- Returns the first registered pane that's still alive in tmux.
--- Prunes dead panes as a side effect.
---@param tmux table  the tmux helper module (must have pane_alive)
---@return string|nil pane_id, or nil if no AI panes are alive
function M.first_alive(tmux)
  for i = #M.panes, 1, -1 do
    if not tmux.pane_alive(M.panes[i]) then
      table.remove(M.panes, i)
    end
  end
  return M.panes[1]
end

return M
