local M = {}

--- Command set via setup()'s `cmd` option, read by lsp/hledger_lsp.lua.
---@type string[]|nil
M.cmd_override = nil

--- Adapt an nvim-lspconfig style root_dir(fname) to native root_dir(bufnr, on_dir).
---@param root_dir function
---@return function
local function adapt_root_dir(root_dir)
  local info = debug.getinfo(root_dir, "u")
  if not info or info.isvararg or info.nparams ~= 1 then
    return root_dir
  end
  return function(bufnr, on_dir)
    on_dir(root_dir(vim.api.nvim_buf_get_name(bufnr)))
  end
end

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

  if type(config.root_dir) == "function" then
    config.root_dir = adapt_root_dir(config.root_dir)
  end

  vim.lsp.config("hledger_lsp", config)

  -- Attaches to matching buffers, including any that are already open.
  vim.lsp.enable("hledger_lsp")
end

return M
