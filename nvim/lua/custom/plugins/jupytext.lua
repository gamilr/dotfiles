-- Jupytext: open .ipynb files transparently as plain Python with `# %%` cell markers.
-- Saves back to .ipynb on :w, so you can hand the file in unchanged.
-- Requires: pip install jupytext  (in the same venv as molten — see molten.lua)

-- The plugin shells out to bare `jupytext`, so prepend the nvim venv's bin/ to $PATH.
local venv_bin = vim.fn.expand('~/.venvs/nvim/bin')
if not (vim.env.PATH or ''):find(venv_bin, 1, true) then
  vim.env.PATH = venv_bin .. ':' .. (vim.env.PATH or '')
end

-- Compat shim: jupytext.nvim is unmaintained (last commit Apr 2024) and its
-- health.lua still calls vim.health.report_start/ok/error, which Neovim 0.12
-- removed (renamed to vim.health.start/ok/error in 0.10). Without this,
-- `:checkhealth` throws on the jupytext section. Restore the old names if gone.
vim.health.report_start = vim.health.report_start or vim.health.start
vim.health.report_ok = vim.health.report_ok or vim.health.ok
vim.health.report_error = vim.health.report_error or vim.health.error
vim.health.report_warn = vim.health.report_warn or vim.health.warn
vim.health.report_info = vim.health.report_info or vim.health.info

return {
  'GCBallesteros/jupytext.nvim',
  lazy = false, -- needs to register before BufRead on .ipynb
  opts = {
    style = 'percent', -- `# %%` cell markers, the standard ML/data-science format
    output_extension = 'auto',
    force_ft = nil,
    custom_language_formatting = {},
  },
}
