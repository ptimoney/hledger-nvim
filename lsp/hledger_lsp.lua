--- Default hledger-lsp configuration, resolved from the runtimepath by Neovim
--- >= 0.11. Override via after/lsp/hledger_lsp.lua, vim.lsp.config(), or
--- setup()'s lsp_opts.

-- Marker files used to locate the workspace root.
local root_markers = { ".hledger-lsp.json", "main.journal", "all.journal", ".git" }

-- setup()'s cmd is applied here because vim.lsp.config() merges element-wise
-- and cannot shorten this default. pcall: the file also works standalone.
local ok, plugin = pcall(require, "hledger.lsp")
local cmd = (ok and plugin.cmd_override) or { "hledger-lsp", "--stdio" }

-- hledger-lsp watches included journals through workspace/didChangeWatchedFiles,
-- so edits made outside Neovim refresh diagnostics. Neovim only advertises that
-- on macOS and Windows; elsewhere, opt this one client in when inotifywait (the
-- recursive backend Neovim picks) is available. Journal trees are small.
local capabilities
local sysname = vim.uv.os_uname().sysname
if sysname ~= "Darwin" and sysname ~= "Windows_NT" and vim.fn.executable("inotifywait") == 1 then
  capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } }
end

---@type vim.lsp.Config
return {
  cmd = cmd,
  capabilities = capabilities,
  filetypes = { "hledger", "journal" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname == "" then
      on_dir(vim.fn.getcwd())
      return
    end
    on_dir(vim.fs.root(fname, root_markers) or vim.fs.dirname(fname))
  end,
  settings = {
    hledgerLanguageServer = {
      inlayHints = {
        showInferredAmounts = true,
        -- Off by default: can get very busy.
        showRunningBalances = false,
        showCostConversions = true,
      },
      codeLens = {
        showRunningBalances = false,
        showTransactionCounts = false,
      },
    },
  },
}
