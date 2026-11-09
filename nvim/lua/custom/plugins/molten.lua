-- Molten.nvim: run Jupyter cells inside Neovim with inline plots.
-- Pairs with jupytext.lua to open .ipynb files as plain Python with `# %%` cell markers.
--
-- System deps already installed:
--   macOS: imagemagick, cairo, python@3.12
--   Linux: imagemagick + cairo from the distro package manager
--   venv: ~/.venvs/nvim with pynvim, jupyter_client, ipykernel, cairosvg,
--         pnglatex, plotly, kaleido, pyperclip, nbformat, jupytext

-- Point Neovim's remote plugins at the dedicated venv.
vim.g.python3_host_prog = vim.fn.expand('~/.venvs/nvim/bin/python')

-- On macOS, cairosvg may need Homebrew's libcairo path. Linux resolves libcairo
-- through the system dynamic linker, so do not inject a macOS path there.
if vim.uv.os_uname().sysname == 'Darwin' and vim.fn.isdirectory('/opt/homebrew/lib') == 1 then
  local existing = vim.env.DYLD_FALLBACK_LIBRARY_PATH or ''
  if not existing:find('/opt/homebrew/lib', 1, true) then
    vim.env.DYLD_FALLBACK_LIBRARY_PATH = '/opt/homebrew/lib'
      .. (existing ~= '' and (':' .. existing) or '')
  end
end

return {
  {
    '3rd/image.nvim',
    build = false, -- using magick CLI instead of luarocks
    dependencies = { 'leafo/magick' },
    opts = {
      backend = 'kitty', -- Ghostty implements the kitty image protocol
      processor = 'magick_cli', -- avoids luarocks; needs ImageMagick on PATH
      integrations = {
        markdown = {
          enabled = false, -- macOS magick+font issue; Molten plots still work
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { 'markdown', 'vimwiki', 'quarto' },
        },
        neorg = { enabled = false },
      },
      max_width = 300,
      max_height = 60,
      max_height_window_percentage = 85,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { 'cmp_menu', 'cmp_docs', 'snacks_notif', 'scrollview', 'scrollview_sign' },
    },
  },
  {
    'benlubas/molten-nvim',
    version = '^1.0.0',
    build = ':UpdateRemotePlugins',
    dependencies = { '3rd/image.nvim' },
    ft = { 'python', 'markdown', 'quarto' },
    init = function()
      vim.g.molten_image_provider = 'image.nvim'
      vim.g.molten_output_win_max_height = 60
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_use_border_highlights = true
    end,
    keys = {
      { '<leader>m', '', desc = '[M]olten / Jupyter' },
      { '<leader>mi', '<cmd>MoltenInit<cr>', desc = '[M]olten [I]nit kernel' },
      { '<leader>md', '<cmd>MoltenDelete<cr>', desc = '[M]olten [D]elete cell output' },
      { '<leader>mD', '<cmd>MoltenDeinit<cr>', desc = '[M]olten [D]einit kernel' },
      { '<leader>mt', function()
          vim.g.molten_virt_text_output = not vim.g.molten_virt_text_output
          pcall(vim.fn.MoltenUpdateInterface)
          vim.notify('Inline output: ' .. tostring(vim.g.molten_virt_text_output))
        end, desc = '[M]olten [T]oggle inline output' },
      { '<leader>mr', '<cmd>MoltenReevaluateCell<cr>', desc = '[M]olten [R]e-eval cell' },
      { '<leader>ml', '<cmd>MoltenEvaluateLine<cr>', desc = '[M]olten eval [L]ine' },
      { '<leader>me', '<cmd>MoltenEvaluateOperator<cr>', desc = '[M]olten [E]val operator' },
      { '<leader>mc', function()
          -- Eval the whole cell, defined by # %% markers (NOT blank lines)
          local cur = vim.fn.line('.')
          local last = vim.fn.line('$')
          local start, stop = 1, last
          for i = cur, 1, -1 do
            if vim.fn.getline(i):match('^# %%%%') then
              start = i + 1
              break
            end
          end
          for i = start, last do
            if vim.fn.getline(i):match('^# %%%%') then
              stop = i - 1
              break
            end
          end
          -- Trim trailing blank lines so output anchors below the last real code line
          while stop > start and vim.fn.getline(stop):match('^%s*$') do
            stop = stop - 1
          end
          vim.fn.MoltenEvaluateRange(start, stop)
        end, desc = '[M]olten eval [C]ell' },
      { '<leader>mC', 'o# %%<CR>', desc = '[M]olten new [C]ode cell below' },
      { '<leader>mM', 'o# %% [markdown]<CR># ', desc = '[M]olten new [M]arkdown cell below' },
      { '<leader>mv', ':<C-u>MoltenEvaluateVisual<cr>gv', mode = 'v', desc = '[M]olten eval [V]isual' },
      { '<leader>mo', '<cmd>MoltenShowOutput<cr>', desc = '[M]olten show [O]utput' },
      { '<leader>mh', '<cmd>MoltenHideOutput<cr>', desc = '[M]olten [H]ide output' },
      { '<leader>mO', '<cmd>noautocmd MoltenEnterOutput<cr>', desc = '[M]olten enter [O]utput window' },
      { '<leader>mI', '<cmd>MoltenImagePopup<cr>', desc = '[M]olten [I]mage popup (full size)' },
      { '<leader>mx', '<cmd>MoltenInterrupt<cr>', desc = '[M]olten interrupt (e[X]it)' },
      { '<leader>mR', '<cmd>MoltenRestart!<cr>', desc = '[M]olten [R]estart kernel' },
      { '<leader>mn', '<cmd>MoltenNext<cr>', desc = '[M]olten [N]ext cell' },
      { '<leader>mp', '<cmd>MoltenPrev<cr>', desc = '[M]olten [P]rev cell' },
    },
  },
}

-- Quick reference once installed:
--   :MoltenInit               start a kernel for the current buffer
--   <leader>ml                run the current line
--   <leader>meip              run the current paragraph (cell)
--   <leader>mr                re-run the cell that produced output under cursor
--   <leader>mo / <leader>mh   show / hide output window
--   <leader>mx                interrupt a long-running cell
