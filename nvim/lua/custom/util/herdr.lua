-- Herdr counterpart to custom/util/tmux.lua, with the same function shapes so
-- anything that took the tmux module (ai_panes, the claudecode provider) works
-- against either multiplexer unchanged. Pick one with custom/util/mux.lua.

local M = {}

local function bin()
  local b = vim.env.HERDR_BIN_PATH
  if b == nil or b == '' then return 'herdr' end
  return b
end

function M.available()
  return vim.env.HERDR_ENV ~= nil and vim.env.HERDR_ENV ~= ''
end

M.in_herdr = M.available

function M.require_herdr()
  if not M.available() then
    vim.notify('Not running inside Herdr - herdr split skipped', vim.log.levels.WARN)
    return false
  end
  return true
end

---Run a herdr CLI command and decode its JSON reply.
---@param args string[]
---@return table|nil decoded, string|nil raw_output
local function cli(args)
  local cmd = { bin() }
  vim.list_extend(cmd, args)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, out
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok then
    return nil, out
  end
  return decoded, out
end

M.cli = cli

-- tmux calls a side-by-side split horizontal; herdr names the resulting
-- placement instead.
local DIRECTION = { h = 'right', v = 'down' }

---Herdr sizes a split by ratio, so '40%' becomes 0.4. Absolute cell counts
---have no equivalent and are ignored.
local function to_ratio(size)
  if type(size) == 'number' then return size end
  if type(size) ~= 'string' then return nil end
  local pct = size:match('^(%d+)%%$')
  return pct and (tonumber(pct) / 100) or nil
end

local SHELLS = { zsh = true, bash = true, sh = true, fish = true, ksh = true, dash = true }

---Program name of a "VAR=val VAR=val prog args" command line: the first word
---that is not an assignment, without its directory.
---@param cmd string
---@return string|nil
local function program_of(cmd)
  for word in cmd:gmatch('%S+') do
    if not word:find('^[%w_]+=') then
      return word:match('([^/]+)$')
    end
  end
  return nil
end

---What the pane's foreground is doing, from `pane process-info`:
---  'prompt'  the shell is at a prompt (or process info is unavailable)
---  'running' `program` already holds the foreground, i.e. the HERDR_AUTORUN
---            guard exec'd it, or the wrapper script that launches it is up
---  'busy'    something else holds the foreground, e.g. direnv evaluating a
---            flake during shell startup
---Unknown process info counts as a prompt: typing an extra line is
---recoverable, never launching the agent is not.
---@param pane string
---@param program string|nil
---@return 'prompt'|'running'|'busy'
function M.foreground_state(pane, program)
  local data = cli({ 'pane', 'process-info', '--pane', pane })
  local info = data and data.result and data.result.process_info
  local procs = info and info.foreground_processes
  if not procs or #procs == 0 then return 'prompt' end
  local shell_pid = info.shell_pid
  local all_shells = true
  for _, proc in ipairs(procs) do
    -- A login shell reports itself as "-zsh".
    local name = tostring(proc.argv0 or proc.name or ''):gsub('^%-', '')
    local is_shell = SHELLS[name] == true
    -- exec keeps the pid, so the shell's own pid running something that is
    -- not a shell means the guard replaced it with the command. This does not
    -- depend on the program's process name (an npm-installed claude runs as
    -- "node", for example).
    if shell_pid and proc.pid == shell_pid and not is_shell then return 'running' end
    if program then
      if name == program then return 'running' end
      -- ~/.local/bin/claude is a bash script that execs the real binary, so
      -- for a moment the foreground is "bash <path>/claude".
      for _, arg in ipairs(proc.argv or {}) do
        if tostring(arg):match('([^/]+)$') == program then return 'running' end
      end
    end
    if not is_shell then all_shells = false end
  end
  return all_shells and 'prompt' or 'busy'
end

---True while the pane's foreground process is still its shell.
---@param pane string
---@return boolean
function M.at_shell_prompt(pane)
  return M.foreground_state(pane, nil) == 'prompt'
end

-- direnv's `use flake` can hold a fresh shell for a long time on a cold
-- evaluation, so the prompt wait polls with a generous budget.
local PROMPT_POLL_MS = 500
local PROMPT_TIMEOUT_MS = 120000

---Fallback for a pane whose shell ignored HERDR_AUTORUN - no guard in the
---shell rc, a shell that does not read it, or an exec that failed. Waits for
---the prompt, then types the command in. `pane split` returns as soon as the
---pane exists, so text sent immediately can land before the shell is reading,
---and startup hooks (direnv) can keep the shell busy well past its first line
---of output, so this polls rather than checking once. Stops silently as soon
---as the guard is seen to have exec'd the command. Async, so the fast path
---never blocks nvim on any of this.
---@param pane string
---@param cmd string
function M.run(pane, cmd)
  local program = program_of(cmd)
  local waited = 0
  local function poll()
    if not M.pane_alive(pane) then return end
    local state = M.foreground_state(pane, program)
    if state == 'running' then return end
    if state == 'prompt' then
      vim.system({ bin(), 'pane', 'run', pane, cmd })
      return
    end
    waited = waited + PROMPT_POLL_MS
    if waited >= PROMPT_TIMEOUT_MS then
      vim.notify(
        string.format('herdr pane %s never reached a prompt; run this there by hand: %s', pane, cmd),
        vim.log.levels.WARN
      )
      return
    end
    vim.defer_fn(poll, PROMPT_POLL_MS)
  end
  vim.system(
    { bin(), 'pane', 'wait-output', pane, '--regex', '\\S', '--timeout', '5000' },
    {},
    -- on_exit lands in a fast-event context, where spawning is dropped
    -- silently, so hop back to the main loop before polling.
    vim.schedule_wrap(poll)
  )
end

---@param opts { direction?: 'h'|'v', size?: string|number, cmd?: string, cwd?: string, focus?: boolean, before?: boolean, target?: string, env?: table<string,string> }
---  before=true puts the new pane LEFT of the source (h) or ABOVE it (v).
---  target=<pane_id> splits THAT pane instead of the calling one.
---@return string|nil pane_id of the new pane, or nil on failure
function M.split(opts)
  if not M.require_herdr() then return nil end
  opts = opts or {}
  local direction = DIRECTION[opts.direction or 'h'] or 'right'

  -- Address the source pane by id rather than --current. `pane split --current`
  -- honours the caller's $HERDR_PANE_ID, but `pane swap --current` acts on the
  -- UI-focused pane instead, which silently swaps whichever pane the user is
  -- looking at (herdr 0.8.2). An explicit id behaves the same for both.
  local source = opts.target
  if not source or source == '' then
    source = vim.env.HERDR_PANE_ID
  end
  local function target_args(list)
    if source and source ~= '' then
      vim.list_extend(list, { '--pane', source })
    else
      table.insert(list, '--current')
    end
    return list
  end

  local args = target_args({ 'pane', 'split', '--direction', direction })
  local ratio = to_ratio(opts.size)
  if ratio then
    vim.list_extend(args, { '--ratio', tostring(ratio) })
  end
  -- No --cwd means herdr applies its own new_cwd policy, which is set to
  -- "follow" in config.toml and matches tmux's -c "#{pane_current_path}".
  if opts.cwd then
    vim.list_extend(args, { '--cwd', opts.cwd })
  end
  for k, v in pairs(opts.env or {}) do
    vim.list_extend(args, { '--env', string.format('%s=%s', k, tostring(v)) })
  end
  -- Herdr has no `pane split --command`, so the command travels as an env var
  -- that the HERDR_AUTORUN guard in the shell rc (~/.zshenv, ~/.bashrc) execs before the rest of the rc
  -- runs. That is the whole speed difference against tmux's
  -- `split-window '<cmd>'`: no shell startup, no prompt wait, no typing.
  -- M.run below still covers the case where the guard is not there.
  if opts.cmd then
    vim.list_extend(args, { '--env', 'HERDR_AUTORUN=' .. opts.cmd })
  end
  table.insert(args, opts.focus == false and '--no-focus' or '--focus')

  local data, raw = cli(args)
  local pane = data and data.result and data.result.pane and data.result.pane.pane_id
  if not pane then
    vim.notify('herdr pane split failed: ' .. tostring(raw), vim.log.levels.ERROR)
    return nil
  end

  -- Herdr only splits right and down, so tmux's -b is a split followed by a
  -- swap of the source pane with its new neighbour. Same trick smart-splits
  -- uses in lua/smart-splits/mux/herdr.lua.
  if opts.before then
    cli(target_args({ 'pane', 'swap', '--direction', direction }))
  end

  if opts.cmd then
    M.run(pane, opts.cmd)
  end

  return pane
end

---@param pane_id string|nil
function M.pane_alive(pane_id)
  if not pane_id or pane_id == '' then return false end
  if not M.available() then return false end
  local data = cli({ 'pane', 'list' })
  if not data or not data.result or not data.result.panes then return false end
  for _, pane in ipairs(data.result.panes) do
    if pane.pane_id == pane_id then return true end
  end
  return false
end

---@param pane_id string|nil
function M.kill_pane(pane_id)
  if M.pane_alive(pane_id) then
    cli({ 'pane', 'close', pane_id })
  end
end

---Panes in this nvim's workspace that herdr recognises as hosting `kind`
---(claude, opencode, ...), same-tab panes first. Lets a session started by
---hand be adopted instead of spawning a second one.
---@param kind string
---@return { pane_id: string, label: string, cwd: string|nil }[]
function M.agent_panes(kind)
  if not M.available() then return {} end
  local data = cli({ 'agent', 'list' })
  local agents = data and data.result and data.result.agents or {}
  local workspace, tab = vim.env.HERDR_WORKSPACE_ID, vim.env.HERDR_TAB_ID
  local same_tab, other = {}, {}
  for _, a in ipairs(agents) do
    if a.agent == kind and a.pane_id ~= vim.env.HERDR_PANE_ID
        and (not workspace or workspace == '' or a.workspace_id == workspace) then
      local entry = {
        pane_id = a.pane_id,
        label = string.format('%s  %s', a.pane_id, a.terminal_title_stripped or a.cwd or ''),
        cwd = a.cwd,
      }
      table.insert(a.tab_id == tab and same_tab or other, entry)
    end
  end
  return vim.list_extend(same_tab, other)
end

---Type `text` into the pane as if at its prompt; `submit` adds Enter.
---Multi-line text goes in as one bracketed paste so newlines do not submit
---early (`pane send-text` passes escape bytes through untouched).
---@param pane_id string
---@param text string
---@param submit boolean|nil
---@return boolean
function M.send_text(pane_id, text, submit)
  if not M.pane_alive(pane_id) then return false end
  local payload = (text:gsub('\r\n', '\n'):gsub('\r', '\n'))
  if payload:find('\n', 1, true) then
    payload = '\27[200~' .. payload .. '\27[201~'
  end
  vim.fn.system({ bin(), 'pane', 'send-text', pane_id, payload })
  if vim.v.shell_error ~= 0 then return false end
  if submit then
    vim.fn.system({ bin(), 'pane', 'send-keys', pane_id, 'Enter' })
  end
  return vim.v.shell_error == 0
end

---Herdr has no "focus this exact pane" call - `pane focus` is directional.
---`agent focus` does accept a pane id, but only while a recognised agent
---occupies it, which holds for the AI panes this module manages.
---@param pane_id string|nil
---@return boolean
function M.focus_pane(pane_id)
  if not M.pane_alive(pane_id) then return false end
  local data = cli({ 'agent', 'focus', pane_id })
  return data ~= nil and data.result ~= nil
end

return M
