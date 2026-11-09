local M = {}

function M.in_tmux()
  return vim.env.TMUX ~= nil and vim.env.TMUX ~= ''
end

function M.require_tmux()
  if not M.in_tmux() then
    vim.notify('Not running inside tmux — tmux split skipped', vim.log.levels.WARN)
    return false
  end
  return true
end

---@param opts { direction?: 'h'|'v', size?: string, cmd?: string, cwd?: string, focus?: boolean, before?: boolean, target?: string }
---  before=true puts the new pane LEFT of the current (horizontal split) or ABOVE (vertical).
---  target=<pane_id> splits THAT pane instead of the current one.
---@return string|nil pane_id of the new pane, or nil on failure
function M.split(opts)
  if not M.require_tmux() then return nil end
  opts = opts or {}
  local direction = opts.direction == 'v' and '-v' or '-h'
  local size = opts.size and (' -l ' .. opts.size) or ''
  local cwd = opts.cwd
      and (' -c ' .. vim.fn.shellescape(opts.cwd))
      or ' -c "#{pane_current_path}"'
  local focus = opts.focus == false and ' -d' or ''
  local before = opts.before and ' -b' or ''
  local target = opts.target and (' -t ' .. opts.target) or ''
  local cmd_arg = opts.cmd and (' ' .. vim.fn.shellescape(opts.cmd)) or ''
  local full = string.format(
    "tmux split-window %s%s%s%s%s%s -P -F '#{pane_id}'%s",
    direction, before, target, size, cwd, focus, cmd_arg
  )
  local out = vim.fn.system(full)
  if vim.v.shell_error ~= 0 then
    vim.notify('tmux split-window failed: ' .. out, vim.log.levels.ERROR)
    return nil
  end
  return vim.trim(out)
end

---@param pane_id string|nil
function M.pane_alive(pane_id)
  if not pane_id or pane_id == '' then return false end
  local out = vim.fn.system('tmux list-panes -a -F "#{pane_id}" 2>/dev/null')
  if vim.v.shell_error ~= 0 then return false end
  for line in out:gmatch('[^\r\n]+') do
    if line == pane_id then return true end
  end
  return false
end

---@param pane_id string|nil
function M.kill_pane(pane_id)
  if M.pane_alive(pane_id) then
    vim.fn.system('tmux kill-pane -t ' .. pane_id)
  end
end

---Panes in this tmux session whose foreground command is `kind`, current
---window first. Matches herdr.agent_panes. tmux has no agent detection, so
---this goes by process name only.
---@param kind string
---@return { pane_id: string, label: string, cwd: string|nil }[]
function M.agent_panes(kind)
  if not M.in_tmux() then return {} end
  local out = vim.fn.system(
    "tmux list-panes -s -F '#{pane_id}\t#{window_active}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}' 2>/dev/null"
  )
  if vim.v.shell_error ~= 0 then return {} end
  local same_window, other = {}, {}
  for line in out:gmatch('[^\r\n]+') do
    local id, active, cmd, path, title = line:match('^(%S+)\t(%d)\t([^\t]*)\t([^\t]*)\t(.*)$')
    if id and cmd == kind and id ~= vim.env.TMUX_PANE then
      local entry = { pane_id = id, label = string.format('%s  %s', id, title ~= '' and title or path), cwd = path }
      table.insert(active == '1' and same_window or other, entry)
    end
  end
  return vim.list_extend(same_window, other)
end

---Matches herdr.send_text. paste-buffer -p uses bracketed paste when the app
---asked for it, and -r keeps LF so multi-line text does not submit early.
---@param pane_id string
---@param text string
---@param submit boolean|nil
---@return boolean
function M.send_text(pane_id, text, submit)
  if not M.pane_alive(pane_id) then return false end
  vim.fn.system({ 'tmux', 'load-buffer', '-b', 'claude-prompt', '-' }, text)
  if vim.v.shell_error ~= 0 then return false end
  vim.fn.system({ 'tmux', 'paste-buffer', '-p', '-r', '-d', '-b', 'claude-prompt', '-t', pane_id })
  if vim.v.shell_error ~= 0 then return false end
  if submit then
    vim.fn.system({ 'tmux', 'send-keys', '-t', pane_id, 'Enter' })
  end
  return vim.v.shell_error == 0
end

---Matches custom/util/herdr.lua so callers can use either backend.
---@param pane_id string|nil
---@return boolean
function M.focus_pane(pane_id)
  if not M.pane_alive(pane_id) then return false end
  vim.fn.system('tmux select-pane -t ' .. pane_id)
  return vim.v.shell_error == 0
end

return M
