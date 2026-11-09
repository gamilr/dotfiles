-- render-markdown.nvim -- renders markdown inside the buffer itself: headings,
-- tables, code blocks, lists, callouts.
--
-- Chosen over a browser preview because it has no Node dependency and no build
-- step, so it cannot end up in the state markdown-preview.nvim was in, where the
-- plugin is installed but its `yarn install` never ran and the failure is silent.
-- Both are kept: this one for reading in place, :MarkdownPreview for a browser.
--
-- Renders automatically on any markdown buffer, and on LSP hover popups, which
-- are markdown too. <leader>tm toggles it off when you need the raw source.

return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  -- 'markdown' covers .md files. LSP hover sets filetype=markdown on its float
  -- buffer (see vim/lsp/util.lua), which fires FileType and loads us there too,
  -- so pressing K in a .cpp file gets rendered documentation.
  ft = { 'markdown' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    enabled = true,

    -- Un-render the line the cursor is on, so editing always shows real source
    -- while the rest of the buffer stays formatted.
    anti_conceal = { enabled = true },

    heading = {
      -- No icons. Heading level is carried entirely by colour: the per-level
      -- background bar (RenderMarkdownH1Bg..H6Bg) and text colour
      -- (RenderMarkdownH1..H6). Nothing is inserted into the text, so headings
      -- stay the width they are on disk.
      icons = {},
      sign = false,
    },

    code = {
      -- Background block only as wide as the code, not the window, so the ASCII
      -- diagrams in docs/ keep their alignment inside the fence.
      width = 'block',
      right_pad = 2,
      language_name = true,
    },

    pipe_table = { preset = 'round' },

    -- Hover popups and other scratch buffers.
    overrides = {
      buftype = {
        nofile = {
          -- A float uses NormalFloat (#374145 in everforest) while the code
          -- background is #2e383c, darker, so anything filled reads as a shadow
          -- inside the popup. 'language' means disable_background = true, which
          -- kills the block fill; border = 'none' also kills the top/bottom bar,
          -- which is drawn from a separate highlight and survives 'language'.
          code = { style = 'language', border = 'none', width = 'full', right_pad = 0 },
          heading = { width = 'full', left_pad = 0, right_pad = 0 },
          sign = { enabled = false },
        },
      },
    },
  },
  config = function(_, opts)
    require('render-markdown').setup(opts)

    -- Everforest links RenderMarkdownBullet to Normal, so it carries the editor
    -- background (#1f2428). Drawn inside an LSP hover, whose background is
    -- NormalFloat (#374145), every bullet becomes a visibly darker square. A
    -- bullet has no business owning a background at all, so clear it and let it
    -- inherit whichever window it lands in.
    local function clear_backgrounds()
      for _, group in ipairs({ 'RenderMarkdownBullet', 'RenderMarkdownDash' }) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        vim.api.nvim_set_hl(0, group, { fg = hl.fg, bold = hl.bold, bg = 'NONE' })
      end
    end

    clear_backgrounds()
    vim.api.nvim_create_autocmd('ColorScheme', {
      desc = 'Keep render-markdown bullets background-free across themes',
      callback = clear_backgrounds,
    })
  end,
  keys = {
    {
      '<leader>tm',
      function()
        require('render-markdown').toggle()
      end,
      desc = '[T]oggle [m]arkdown render',
    },
  },
}
