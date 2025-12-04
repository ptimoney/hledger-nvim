# hledger-nvim

A Neovim plugin for hledger, providing LSP integration and a workspace graph visualization.

## Features

- **LSP Integration**: Automatically sets up `hledger-lsp` with `nvim-lspconfig`.
- **Workspace Graph**: Visualize your journal file dependencies with `:HledgerGraph`.
- **Inlay Hints**: Support for inferred amounts, running balances, and cost conversions.

## Prerequisites

You must have the `hledger-lsp` language server installed. You can install it globally via npm:

```bash
npm install -g hledger-lsp
```

Ensure `hledger-lsp` is in your PATH. You can verify this by running `hledger-lsp --version`.

## Installation

### lazy.nvim

```lua
{
  "ptimoney/hledger-nvim",
  ft = { "hledger", "journal" },
  dependencies = {
    "neovim/nvim-lspconfig",
  },
  config = function(_, opts)
    require("hledger").setup(opts)
  end,
}
```

## Configuration

The `setup` function accepts a table with the following keys:

- `cmd`: (table) The command to start the LSP server. Defaults to `{ "hledger-lsp", "--stdio" }`.
- `lsp_opts`: (table) Options passed to `lspconfig.hledger_lsp.setup()`. Use this to set `on_attach`, `capabilities`, and `settings`.

### Example Configuration

```lua
{
  "ptimoney/hledger-nvim",
  ft = { "hledger", "journal" },
  dependencies = { "neovim/nvim-lspconfig" },
  opts = {
    lsp_opts = {
      settings = {
        hledgerLanguageServer = {
          inlayHints = {
            showInferredAmounts = true,
            showRunningBalances = true,
          },
          validation = {
            undeclaredAccounts = true,
          },
        },
      },
    },
  },
  config = function(_, opts)
    require("hledger").setup(opts)
  end,
}
```

For a complete list of available settings (validation, formatting, etc.), please refer to the [hledger-lsp Server Documentation](https://github.com/ptimoney/hledger-lsp/tree/main/server#user-configuration).

## Commands

- `:HledgerGraph`: Opens a floating window showing the workspace graph.
  - `Enter`: Open selected file
  - `/`: Filter files
  - `za`: Toggle fold
  - `q` / `Esc`: Close window

## Requirements

- Neovim >= 0.9.0
- `hledger-lsp` installed (see Prerequisites)
