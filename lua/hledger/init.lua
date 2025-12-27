local M = {}
local lsp = require("hledger.lsp")
local ui = require("hledger.ui")

function M.setup(opts)
  opts = opts or {}

  -- Setup LSP
  lsp.setup(opts)

  -- Create User Command
  vim.api.nvim_create_user_command("HledgerGraph", ui.show_workspace_graph, {})

  -- Setup keybinding
  -- Default to "<leader>hg", can be customized or disabled with false
  local keymap = opts.keymap
  if keymap == nil then
    keymap = "<leader>hg"
  end

  if keymap then
    vim.keymap.set("n", keymap, ui.show_workspace_graph, {
      desc = "Show hledger workspace graph",
      silent = true
    })
  end
end

return M
