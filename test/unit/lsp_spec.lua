-- Tests for the native (vim.lsp.config) server setup.
-- Busted runs from the plugin root, so that is also the runtimepath entry that
-- makes Neovim resolve lsp/hledger_lsp.lua.
local plugin_root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(plugin_root)

local lsp = require("hledger.lsp")

--- The defaults exactly as shipped in lsp/hledger_lsp.lua.
local function defaults()
  return dofile(plugin_root .. "/lsp/hledger_lsp.lua")
end

--- Normalize away symlinks (macOS temp dirs live under /private/var) so paths
--- built by hand compare equal to the ones Neovim resolves for a buffer.
local function realpath(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

--- Root directory the shipped root_dir() function resolves for a file path.
local function resolve_root(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = ""
  if path then
    vim.api.nvim_buf_set_name(buf, path)
  end
  local got
  defaults().root_dir(buf, function(dir)
    got = dir
  end)
  vim.api.nvim_buf_delete(buf, { force = true })
  return got
end

describe("lsp defaults", function()
  it("starts hledger-lsp over stdio", function()
    assert.same({ "hledger-lsp", "--stdio" }, defaults().cmd)
  end)

  it("applies to hledger and journal filetypes", function()
    assert.same({ "hledger", "journal" }, defaults().filetypes)
  end)

  it("enables inferred amount and cost conversion hints", function()
    local hints = defaults().settings.hledgerLanguageServer.inlayHints
    assert.equal(true, hints.showInferredAmounts)
    assert.equal(true, hints.showCostConversions)
  end)

  it("leaves running balance hints off", function()
    assert.equal(false, defaults().settings.hledgerLanguageServer.inlayHints.showRunningBalances)
  end)

  it("leaves code lens off", function()
    local lens = defaults().settings.hledgerLanguageServer.codeLens
    assert.equal(false, lens.showRunningBalances)
    assert.equal(false, lens.showTransactionCounts)
  end)
end)

describe("lsp root_dir", function()
  it("finds the directory holding a marker file", function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir .. "/sub", "p")
    vim.fn.writefile({}, dir .. "/main.journal")

    assert.equal(realpath(dir), realpath(resolve_root(dir .. "/sub/2026.journal")))
  end)

  it("falls back to the file's own directory when no marker is found", function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")

    assert.equal(realpath(dir), realpath(resolve_root(dir .. "/2026.journal")))
  end)

  it("falls back to the cwd for an unnamed buffer", function()
    assert.equal(realpath(vim.fn.getcwd()), realpath(resolve_root(nil)))
  end)
end)

describe("lsp.setup", function()
  after_each(function()
    vim.lsp.enable("hledger_lsp", false)
    vim.lsp.config("hledger_lsp", {})
    lsp.cmd_override = nil
  end)

  it("enables the hledger_lsp config", function()
    lsp.setup({})
    assert.equal(true, vim.lsp.is_enabled("hledger_lsp"))
  end)

  it("keeps the shipped defaults when no options are given", function()
    lsp.setup({})
    local config = vim.lsp.config["hledger_lsp"]
    assert.same({ "hledger-lsp", "--stdio" }, config.cmd)
    assert.equal(true, config.settings.hledgerLanguageServer.inlayHints.showInferredAmounts)
  end)

  it("overrides cmd", function()
    lsp.setup({ cmd = { "/opt/bin/hledger-lsp", "--stdio" } })
    assert.same({ "/opt/bin/hledger-lsp", "--stdio" }, vim.lsp.config["hledger_lsp"].cmd)
  end)

  it("accepts a wrapper command with extra arguments", function()
    lsp.setup({ cmd = { "npx", "hledger-lsp", "--stdio" } })
    assert.same({ "npx", "hledger-lsp", "--stdio" }, vim.lsp.config["hledger_lsp"].cmd)
  end)

  it("replaces the default cmd instead of merging into it", function()
    lsp.setup({ cmd = { "hledger-lsp-wrapper" } })
    assert.same({ "hledger-lsp-wrapper" }, vim.lsp.config["hledger_lsp"].cmd)
  end)

  it("replaces the default cmd given via lsp_opts too", function()
    lsp.setup({ lsp_opts = { cmd = { "hledger-lsp-wrapper" } } })
    assert.same({ "hledger-lsp-wrapper" }, vim.lsp.config["hledger_lsp"].cmd)
  end)

  it("restores the default cmd when a later setup() omits it", function()
    lsp.setup({ cmd = { "hledger-lsp-wrapper" } })
    lsp.setup({})
    assert.same({ "hledger-lsp", "--stdio" }, vim.lsp.config["hledger_lsp"].cmd)
  end)

  it("merges lsp_opts.settings over the defaults", function()
    lsp.setup({
      lsp_opts = {
        settings = {
          hledgerLanguageServer = {
            inlayHints = { showRunningBalances = false },
            validation = { undeclaredPayees = true },
          },
        },
      },
    })

    local hls = vim.lsp.config["hledger_lsp"].settings.hledgerLanguageServer
    assert.equal(false, hls.inlayHints.showRunningBalances)
    -- untouched sibling default survives the merge
    assert.equal(true, hls.inlayHints.showInferredAmounts)
    assert.equal(true, hls.validation.undeclaredPayees)
  end)

  it("passes on_attach and capabilities through", function()
    local on_attach = function() end
    lsp.setup({ on_attach = on_attach, capabilities = { foo = true } })

    local config = vim.lsp.config["hledger_lsp"]
    assert.equal(on_attach, config.on_attach)
    assert.equal(true, config.capabilities.foo)
  end)

  it("lets lsp_opts win over the top-level shorthands", function()
    lsp.setup({
      cmd = { "ignored" },
      lsp_opts = { cmd = { "wins" } },
    })
    assert.same({ "wins" }, vim.lsp.config["hledger_lsp"].cmd)
  end)
end)
