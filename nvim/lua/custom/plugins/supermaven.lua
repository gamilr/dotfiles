-- Supermaven completes from its own servers, so buffer contents leave the
-- machine. Off unless NVIM_SUPERMAVEN=1, which keeps work code local by default.
return {
  "supermaven-inc/supermaven-nvim",
  cond = vim.env.NVIM_SUPERMAVEN == "1",
  event = "InsertEnter",
  config = function()
    require("supermaven-nvim").setup({})
  end,
}
