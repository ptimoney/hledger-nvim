local M = {}

--- Command set via setup()'s `cmd` option, read by lsp/hledger_lsp.lua.
---@type string[]|nil
M.cmd_override = nil

--- Layer the user's overrides onto lsp/hledger_lsp.lua and enable the server.
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}

  if not vim.lsp.config then
    vim.notify(
      "hledger-nvim: LSP setup requires Neovim 0.11+ (vim.lsp.config)",
      vim.log.levels.ERROR
    )
    return
  end

  local config = vim.tbl_deep_extend("force", {
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    settings = opts.settings,
  }, opts.lsp_opts or {})

  -- Applied via cmd_override so it replaces the default instead of merging.
  M.cmd_override = config.cmd or opts.cmd
  config.cmd = nil

  vim.lsp.config("hledger_lsp", config)

  -- Attaches to matching buffers, including any that are already open.
  vim.lsp.enable("hledger_lsp")
end

return M
