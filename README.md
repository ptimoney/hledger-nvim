# hledger-nvim

A Neovim plugin for hledger, providing LSP integration and a workspace graph visualization.

## Features

- **LSP Integration**: Automatically sets up `hledger-lsp` with `nvim-lspconfig`.
- **Workspace Graph**: Visualize your journal file dependencies with `:HledgerGraph`.
- **Inlay Hints**: Support for inferred amounts, running balances, and cost conversions.

## Prerequisites

You must have the `hledger-lsp` language server installed. You can install it
globally via npm:

```bash
npm install -g hledger-lsp
```

Ensure `hledger-lsp` is in your PATH. You can verify this by running
`hledger-lsp --version`.

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

- `cmd`: (table) The command to start the LSP server. Defaults to
`{ "hledger-lsp", "--stdio" }`.
- `lsp_opts`: (table) Options passed to `lspconfig.hledger_lsp.setup()`. Use
this to set `on_attach`, `capabilities`, and `settings`.

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

For a complete list of available settings (validation, formatting, etc.), please
refer to the [hledger-lsp Server Documentation](https://github.com/ptimoney/hledger-lsp/tree/main/server#user-configuration).

### Default Settings Reference

Here's a complete configuration showing all available settings with their
defaults. Copy and modify as needed:

```lua
{
  "ptimoney/hledger-nvim",
  ft = { "hledger", "journal" },
  dependencies = { "neovim/nvim-lspconfig" },
  opts = {
    lsp_opts = {
      settings = {
        hledgerLanguageServer = {
          validation = {
            balance = true,
            missingAmounts = true,
            undeclaredAccounts = true,
            undeclaredPayees = false,
            undeclaredCommodities = true,
            undeclaredTags = false,
            dateOrdering = true,
            balanceAssertions = true,
            emptyTransactions = true,
            invalidDates = true,
            futureDates = true,
            emptyDescriptions = true,
            formatMismatch = true,
            includeFiles = true,
            circularIncludes = true,
            markAllUndeclaredInstances = true,
          },
          
          -- Severity levels for undeclared items 
          --   "error" | "warning" | "information" | "hint" 
          severity = {
            undeclaredAccounts = "warning", 
            undeclaredPayees = "warning",
            undeclaredCommodities = "warning",
            undeclaredTags = "information",
          },
          
          -- Include directive behavior
          include = {
            followIncludes = true,
            maxDepth = 10,
          },
          
          -- Workspace settings
          workspace = {
            enabled = true,
            eagerParsing = true,
            autoDetectRoot = true,
          },
          
          -- Completion filtering (only show declared items)
          completion = {
            onlyDeclaredAccounts = true,
            onlyDeclaredPayees = true,
            onlyDeclaredCommodities = true,
            onlyDeclaredTags = true,
          },
          
          -- Formatting options
          formatting = {
            indentation = 4,
            maxCommodityWidth = 4,
            maxAmountIntegerWidth = 12,
            maxAmountDecimalWidth = 3,
            minSpacing = 2,
            decimalAlignColumn = 52,
            assertionDecimalAlignColumn = 70,
            signPosition = "after-symbol",
            showPositivesSign = false,
          },
          
          -- Inlay hints (show Running Balances is turned off by default as 
          --              otherwise it can be very busy)
          inlayHints = {
            showInferredAmounts = true,
            showRunningBalances = false,
            showCostConversions = true,
          },
          
          -- Code lens (default to false)
          codeLens = {
            showTransactionCounts = false,
          },
          
          -- General settings
          maxNumberOfProblems = 1000,
          hledgerPath = "hledger",  -- Path to hledger executable
        },
      },
    },
  },
  config = function(_, opts)
    require("hledger").setup(opts)
  end,
}
```

## Commands

- `:HledgerGraph`: Opens a floating window showing the workspace graph.
  - `Enter`: Open selected file
  - `/`: Filter files
  - `za`: Toggle fold
  - `q` / `Esc`: Close window

## Requirements

- Neovim >= 0.9.0
- `hledger-lsp` installed (see Prerequisites)
