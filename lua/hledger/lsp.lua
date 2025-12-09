local M = {}
local lspconfig = require("lspconfig")
local util = require("lspconfig.util")
local configs = require("lspconfig.configs")

function M.setup(opts)
  opts = opts or {}
  
  -- Default configuration
  local default_cmd = { "hledger-lsp", "--stdio" }
  if opts.cmd then
    default_cmd = opts.cmd
  end

  -- Define hledger_lsp as a custom server if not already defined
  if not configs.hledger_lsp then
    configs.hledger_lsp = {
      default_config = {
        cmd = default_cmd,
        filetypes = { "hledger", "journal" },
        root_dir = function(fname)
          return util.root_pattern(".hledger-lsp.json", "main.journal", "all.journal", ".git")(fname)
            or vim.fs.dirname(fname)
        end,
        single_file_support = true,
        settings = {
          hledgerLanguageServer = {
            inlayHints = {
              showInferredAmounts = true,
              showRunningBalances = true,
              showCostConversions = true,
            },
            codeLens = {
              showRunningBalances = false,
              showTransactionCounts = false,
            },
          },
        },
      },
    }
  end

  -- Merge user options with default config
  local setup_opts = vim.tbl_deep_extend("force", {
    on_attach = opts.on_attach,
    capabilities = opts.capabilities,
    settings = opts.settings,
  }, opts.lsp_opts or {})

  lspconfig.hledger_lsp.setup(setup_opts)

  -- Attach to any already-open buffers (for first file open)
  vim.schedule(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
        if ft == "hledger" or ft == "journal" then
          local clients = vim.lsp.get_clients({ bufnr = buf, name = "hledger_lsp" })
          if #clients == 0 then
            lspconfig.hledger_lsp.manager:try_add_wrapper(buf)
          end
        end
      end
    end
  end)

  -- Note: Inlay hint refresh is now handled by the language server
  -- The server sends workspace/inlayHint/refresh notifications when documents change,
  -- which Neovim's LSP client automatically responds to.
  -- No BufEnter workaround needed.
end

return M
