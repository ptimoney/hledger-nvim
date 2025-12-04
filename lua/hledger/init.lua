local M = {}
local lsp = require("hledger.lsp")
local ui = require("hledger.ui")

function M.setup(opts)
  opts = opts or {}
  
  -- Setup LSP
  lsp.setup(opts)
  
  -- Create User Command
  vim.api.nvim_create_user_command("HledgerGraph", ui.show_workspace_graph, {})
end

return M
