-- Prevent LSP from attaching to fugitive:// virtual buffers. Their names aren't
-- valid file:// URIs, so language servers reject the didOpen with errors like:
--   "Expected scheme-specific part at index 5: file:"
-- We block attachment at three layers to cover every code path:
--   1. Wrap vim.lsp.start (the modern lspconfig path)
--   2. LspAttach detach (backup if something attaches anyway)
--   3. Suppress the specific RPC error in vim.notify (in case it leaks through)
local function is_fugitive_buf(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name:match("^fugitive://") ~= nil
end

-- Layer 1: block vim.lsp.start before any didOpen is sent
if not vim.g._fugitive_lsp_start_wrapped then
  vim.g._fugitive_lsp_start_wrapped = true
  local orig_start = vim.lsp.start
  vim.lsp.start = function(config, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    if is_fugitive_buf(bufnr) then
      return nil
    end
    return orig_start(config, opts)
  end
end

-- Layer 2: belt-and-suspenders detach if something gets past layer 1
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("FugitiveDetachLsp", { clear = true }),
  callback = function(args)
    if is_fugitive_buf(args.buf) then
      vim.schedule(function()
        pcall(vim.lsp.buf_detach_client, args.buf, args.data.client_id)
      end)
    end
  end,
})

-- Layer 3: swallow the specific RPC error if it ever fires from a fugitive URI
if not vim.g._fugitive_lsp_notify_wrapped then
  vim.g._fugitive_lsp_notify_wrapped = true
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if type(msg) == "string"
       and msg:match("Expected scheme%-specific part at index 5: file:") then
      return
    end
    return orig_notify(msg, level, opts)
  end
end

return {
  "tpope/vim-fugitive",
  cmd = { "Git", "Gvdiffsplit", "Gdiffsplit", "Gread", "Gwrite", "Gblame" },
  keys = {
    -- 3-way merge (<leader>hgm/hgo/hgi/hgq) moved to custom/plugins/codediff.lua.
    -- :Gvdiffsplit! still works by hand.
    { "<leader>hga", "<cmd>Git add %<cr>",    desc = "Git [a]dd current file" },
    -- General fugitive entrypoints
    { "<leader>hgs", "<cmd>Git<cr>",          desc = "Git [s]tatus (fugitive)" },
    { "<leader>hgB", "<cmd>Git blame<cr>",    desc = "Git [B]lame (buffer-wide, fugitive)" },
  },
}
