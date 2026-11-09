-- VSCode-style diff, merge and history viewer. Takes over the diff/merge keys
-- that used to run gitsigns diffthis and fugitive :Gvdiffsplit!.
--
-- Inside a CodeDiff tab, ]c / [c and <leader>hs / hr / hu are codediff's own
-- buffer maps (same keys as gitsigns). Codediff snapshots the gitsigns maps
-- and hands them back when the tab closes. g? lists every key in the view.
return {
  'esmuellert/codediff.nvim',
  cmd = 'CodeDiff',
  keys = {
    { '<leader>hd', '<cmd>CodeDiff<cr>', desc = 'git [d]iff: changed files (CodeDiff)' },
    { '<leader>hD', '<cmd>CodeDiff file HEAD<cr>', desc = 'git [D]iff file against last commit (CodeDiff)' },
    {
      '<leader>hgm',
      -- :CodeDiff has its own completion, so % is not expanded on the command line
      function() vim.cmd.CodeDiff({ 'merge', vim.fn.expand('%:p') }) end,
      desc = 'Git [m]erge: open 3-way merge (CodeDiff)',
    },
  },
  opts = {
    keymaps = {
      view = {
        quit = { 'q', '<leader>hgq' },
      },
      -- Keep merge keys under <leader>hg. The defaults (<leader>co, <leader>cb, ...)
      -- would shadow the claudecode <leader>c maps in the merge buffers.
      conflict = {
        accept_current = '<leader>hgo', -- ours (:2, current branch)
        accept_incoming = '<leader>hgi', -- theirs (:3)
        accept_both = '<leader>hgb',
        discard = '<leader>hgx',
        accept_all_current = '<leader>hgO',
        accept_all_incoming = '<leader>hgI',
        accept_all_both = '<leader>hgA',
        discard_all = '<leader>hgX',
      },
    },
  },
}
