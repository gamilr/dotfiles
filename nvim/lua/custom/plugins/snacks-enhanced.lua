return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- Automatically handle big files by disabling heavy features
    bigfile = { enabled = true },

    -- Beautiful notifications instead of default vim.notify
    notifier = {
      enabled = true,
      timeout = 3000,
      width = { min = 40, max = 0.4 },
      height = { min = 1, max = 0.6 },
      margin = { top = 0, right = 1, bottom = 0 },
      style = 'compact',
    },

    -- Better status column with git signs, diagnostics, folds
    statuscolumn = {
      enabled = true,
      left = { 'mark', 'sign' },
      right = { 'fold', 'git' },
      folds = {
        open = true,
        git_hl = false,
      },
      git = {
        patterns = { 'GitSign', 'MiniDiffSign' },
      },
      refresh = 50,
    },

    -- Quick file loading optimization
    quickfile = { enabled = true },

    -- Smart indent guides
    indent = {
      enabled = true,
      animate = {
        enabled = false, -- Disable animation for performance
      },
    },

    -- Smooth scrolling
    scroll = {
      enabled = true,
      animate = {
        duration = { step = 15, total = 150 },
        easing = 'linear',
      },
    },

    -- LSP reference highlighting under cursor
    words = {
      enabled = true,
      debounce = 100,
      modes = { 'n' },
    },

    -- Better input prompts
    input = { enabled = true },

    -- Treesitter-based scope detection
    scope = { enabled = true },

    -- LazyGit integration with proper colorscheme support
    lazygit = {
      enabled = true,
      configure = true, -- auto-configure lazygit theme
      win = {
        style = 'lazygit',
      },
    },

    -- Git browsing (open files/commits in GitHub/GitLab)
    gitbrowse = {
      enabled = true,
      url_patterns = {
        ['github.com'] = {
          branch = '/tree/{branch}',
          file = '/blob/{branch}/{file}#L{line_start}-L{line_end}',
          commit = '/commit/{commit}',
        },
      },
    },

    -- Scratch buffers for quick notes
    scratch = {
      enabled = true,
      name = 'scratch',
      ft = 'markdown',
      icon = '󱓧',
      root = vim.fn.stdpath('data') .. '/scratch',
      autowrite = true,
      filekey = {
        cwd = true,
        branch = false,
        count = false,
      },
      win = { style = 'scratch' },
      win_by_ft = {
        lua = { width = 0.4, border = 'rounded' },
      },
    },

    -- Zen mode for focused coding
    zen = {
      enabled = true,
      toggles = {
        dim = true,
        git_signs = false,
        mini_diff_signs = false,
        diagnostics = false,
        inlay_hints = false,
      },
      zoom = {
        win = { backdrop = false },
        toggles = { git_signs = true },
      },
      win = { style = 'zen' },
    },

    -- Buffer deletion without messing up layout
    bufdelete = { enabled = true },

    -- File renaming with LSP integration
    rename = { enabled = true },

    -- Terminal management moved to tmux (see lua/custom/util/tmux.lua)

    -- Picker (recommended for opencode.nvim select())
    picker = { enabled = true },

    -- Window styles for various snacks features
    styles = {
      notification = {
        border = 'rounded',
        wo = {
          winblend = 0,
          wrap = true,
          conceallevel = 2,
        },
      },
      scratch = {
        border = 'rounded',
        width = 100,
        height = 30,
        backdrop = 60,
        zindex = 20,
        wo = { winhighlight = 'NormalFloat:Normal' },
      },
      zen = {
        backdrop = { bg = 'zen' },
        enter = true,
        fixbuf = false,
        minimal = false,
        width = 120,
        wo = {
          winhighlight = 'NormalFloat:Normal',
        },
      },
      lazygit = {
        position = 'left',
        border = 'rounded',
        width = 0.4,
      },
    },
  },

  keys = {
    -- Notifications
    {
      '<leader>un',
      function()
        require('snacks').notifier.hide()
      end,
      desc = 'Dismiss All Notifications',
    },
    {
      '<leader>nh',
      function()
        require('snacks').notifier.show_history()
      end,
      desc = 'Notification History',
    },

    -- LazyGit (replaces your current lazygit.nvim)
    {
      '<leader>lg',
      function()
        require('snacks').lazygit()
      end,
      desc = 'LazyGit (snacks)',
    },
    {
      '<leader>lf',
      function()
        require('snacks').lazygit.log_file()
      end,
      desc = 'LazyGit Current File History',
    },
    {
      '<leader>ll',
      function()
        require('snacks').lazygit.log()
      end,
      desc = 'LazyGit Log (cwd)',
    },

    -- Git Browse (open in GitHub/GitLab)
    {
      '<leader>gB',
      function()
        require('snacks').gitbrowse()
      end,
      desc = 'Git Browse (open in browser)',
      mode = { 'n', 'v' },
    },

    -- Scratch buffers
    {
      '<leader>.',
      function()
        require('snacks').scratch()
      end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader>S',
      function()
        require('snacks').scratch.select()
      end,
      desc = 'Select Scratch Buffer',
    },

    -- Zen mode
    {
      '<leader>z',
      function()
        require('snacks').zen()
      end,
      desc = 'Toggle Zen Mode',
    },
    {
      '<leader>Z',
      function()
        require('snacks').zen.zoom()
      end,
      desc = 'Toggle Zoom',
    },

    -- Buffer management
    {
      '<leader>bd',
      function()
        require('snacks').bufdelete()
      end,
      desc = 'Delete Buffer (keep layout)',
    },
    {
      '<leader>bD',
      function()
        require('snacks').bufdelete.all()
      end,
      desc = 'Delete All Buffers',
    },
    {
      '<leader>bo',
      function()
        require('snacks').bufdelete.other()
      end,
      desc = 'Delete Other Buffers',
    },

    -- File rename with LSP
    {
      '<leader>cr',
      function()
        require('snacks').rename.rename_file()
      end,
      desc = 'Rename File (LSP)',
    },

    -- Two flavors of terminal split, deliberately kept separate:
    --   <leader>stb / <leader>sts  → native :terminal inside the nvim window
    --                                 (lives within nvim, closes with nvim)
    --   prefix + - / prefix + \    → real tmux pane (survives nvim, perfect rendering)
    {
      '<leader>stb',
      '<cmd>split | terminal<cr>i',
      desc = 'Nvim terminal below',
    },
    {
      '<leader>sts',
      '<cmd>vsplit | terminal<cr>i',
      desc = 'Nvim terminal right',
    },

    -- Word references navigation (jumping between LSP references)
    {
      ']]',
      function()
        require('snacks').words.jump(vim.v.count1)
      end,
      desc = 'Next Reference',
      mode = { 'n', 't' },
    },
    {
      '[[',
      function()
        require('snacks').words.jump(-vim.v.count1)
      end,
      desc = 'Prev Reference',
      mode = { 'n', 't' },
    },

    -- Neovim News (fun feature!)
    {
      '<leader>N',
      function()
        require('snacks').win({
          file = vim.api.nvim_get_runtime_file('doc/news.txt', false)[1],
          width = 0.8,
          height = 0.8,
          wo = {
            spell = false,
            wrap = false,
            signcolumn = 'yes',
            statuscolumn = ' ',
            conceallevel = 3,
          },
        })
      end,
      desc = 'Neovim News',
    },
  },

  init = function()
    -- Setup debugging helpers when lazy-loaded
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Global debugging functions
        _G.dd = function(...)
          require('snacks').debug.inspect(...)
        end
        _G.bt = function()
          require('snacks').debug.backtrace()
        end

        -- Override vim.print for better debugging
        if vim.fn.has('nvim-0.11') == 1 then
          vim._print = function(_, ...)
            dd(...)
          end
        else
          vim.print = _G.dd
        end

        -- Useful toggle mappings
        local toggle = require('snacks').toggle
        toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
        toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
        toggle.option('relativenumber', { name = 'Relative Number' }):map '<leader>uL'
        toggle.diagnostics():map '<leader>ud'
        toggle.line_number():map '<leader>ul'
        toggle
          .option('conceallevel', {
            off = 0,
            on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
          })
          :map '<leader>uc'
        toggle.treesitter():map '<leader>uT'
        toggle.option('background', { off = 'light', on = 'dark', name = 'Dark Background' }):map '<leader>ub'
        toggle.inlay_hints():map '<leader>uh'
        toggle.indent():map '<leader>ug'
        toggle.dim():map '<leader>uD'
        toggle.zen():map '<leader>uz'
        toggle.scroll():map '<leader>uS'

        -- Autocomplete (blink.cmp) — flips a flag the plugin's enabled() reads
        Snacks.toggle({
          name = 'Autocomplete',
          get = function() return not vim.g.cmp_disabled end,
          set = function(state) vim.g.cmp_disabled = not state end,
        }):map '<leader>ua'
      end,
    })
  end,
}
