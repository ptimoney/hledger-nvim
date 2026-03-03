local M = {}
local lsp = require("hledger.lsp")
local ui = require("hledger.ui")
local commands = require("hledger.commands")

function M.setup(opts)
  opts = opts or {}

  -- Setup LSP
  lsp.setup(opts)

  -- Create User Commands
  vim.api.nvim_create_user_command("HledgerGraph", ui.show_workspace_graph, {})
  vim.api.nvim_create_user_command("HledgerToggleInlayHints", commands.toggle_inlay_hints, {})
  vim.api.nvim_create_user_command("HledgerToggleCodeLens", commands.toggle_code_lens, {})
  vim.api.nvim_create_user_command("HledgerToggleValidation", commands.toggle_validation, {})

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

-- Expose statusline function for lualine/statusline integration
M.statusline = commands.statusline
M.status = commands.status

return M
