# hledger-nvim

[hledger](https://hledger.org/) plain text accounting support for Neovim &mdash; powered by the [hledger language server](https://github.com/ptimoney/hledger-lsp).

Automatic LSP setup, workspace graph visualization, and full IDE features including completion, validation, formatting, navigation, and inlay hints.

Also available for [VS Code](https://marketplace.visualstudio.com/items?itemName=patrickt.hledger-lsp-vscode).

## Features

All features are provided by the [hledger-lsp](https://github.com/ptimoney/hledger-lsp) language server. This plugin handles setup and provides Neovim-specific UI:

- **LSP Integration** &mdash; automatic `hledger-lsp` configuration via Neovim's built-in LSP client
- **Completion** &mdash; accounts, payees, commodities, tags, and context-aware suggestions
- **Validation** &mdash; 15+ configurable rules (balance, undeclared items, date ordering, etc.)
- **Formatting** &mdash; decimal-point alignment, commodity formatting, configurable indentation
- **Navigation** &mdash; go to definition, find references, document/workspace symbols
- **Inlay Hints** &mdash; inferred amounts, running balances, and cost conversions
- **Workspace Graph** &mdash; `:HledgerGraph` floating window with fuzzy filtering and file preview

## Prerequisites

Install the [hledger-lsp](https://github.com/ptimoney/hledger-lsp) language server:

```bash
npm install -g hledger-lsp
```

Verify it is in your PATH: `hledger-lsp --version`

## Installation

### lazy.nvim

```lua
{
  "ptimoney/hledger-nvim",
  ft = { "hledger", "journal" },
  config = function(_, opts)
    require("hledger").setup(opts)
  end,
}
```

### Filetype detection

`*.journal` and `*.hledger` map to the `hledger` filetype (Neovim's own default
for `*.journal` is `ledger`). Outside lazy.nvim, load the plugin eagerly or
register the filetype yourself so it applies before your first journal opens:

```lua
vim.filetype.add({
  extension = { journal = "hledger", hledger = "hledger" },
})
```

To keep journals on the `ledger` filetype instead, point the server at it:

```lua
vim.lsp.config("hledger_lsp", { filetypes = { "hledger", "journal", "ledger" } })
```

### Without setup()

The server config ships as `lsp/hledger_lsp.lua` on the runtimepath, so you can
skip `setup()` and enable it yourself:

```lua
vim.lsp.enable("hledger_lsp")
```

Drop the `ft = { ... }` lazy-loading if you do &mdash; the plugin must be on the
runtimepath when this runs. Overrides go in `after/lsp/hledger_lsp.lua`.
`:HledgerGraph`, the toggle commands, and the keymap need `setup()`.

## Configuration

The `setup` function accepts a table with the following keys:

- `cmd`: (table) The command to start the LSP server. Defaults to
`{ "hledger-lsp", "--stdio" }`.
- `lsp_opts`: (table) Options merged into `vim.lsp.config("hledger_lsp", ...)`.
Use this to set `on_attach`, `capabilities`, and `settings`.
- `keymap`: (string|false) Keybinding for `:HledgerGraph`. Defaults to
`"<leader>hg"`. Set to `false` to disable the default keybinding.

### Example Configuration

```lua
{
  "ptimoney/hledger-nvim",
  ft = { "hledger", "journal" },
  opts = {
    -- Keymap for :HledgerGraph (default: "<leader>hg")
    -- Set to false to disable, or customize to your preference
    keymap = "<leader>hg",  -- or false to disable, or "<C-g>" etc.

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

For a complete list of available settings (validation, formatting, completion, etc.), see the [language server configuration guide](https://github.com/ptimoney/hledger-lsp#configuration).

### Default Settings Reference

<details>
<summary>Full configuration with all defaults (click to expand)</summary>

```lua
{
  "ptimoney/hledger-nvim",
  ft = { "hledger", "journal" },
  opts = {
    -- Keymap configuration
    keymap = "<leader>hg",  -- Default: opens workspace graph with <leader>hg
                            -- Set to false to disable default keybinding

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

          -- Inlay hints (showRunningBalances is off by default as
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

</details>

## Commands and Keybindings

### Commands

| Command | Description |
|---------|-------------|
| `:HledgerGraph` | Open the workspace graph in a floating window |

### Default Keybindings

| Key | Description |
|-----|-------------|
| `<leader>hg` | Open workspace graph (customizable via `keymap` option) |

### Workspace Graph Window

| Key | Action |
|-----|--------|
| `Enter` | Open selected file |
| `/` | Filter files (fuzzy search) |
| `za` | Toggle fold |
| `q` / `Esc` | Close window |

## Requirements

- Neovim >= 0.11 (for `vim.lsp.config()` / `vim.lsp.enable()`)
- [hledger-lsp](https://github.com/ptimoney/hledger-lsp) installed and in PATH

## Related Projects

| Project | Description |
|---------|-------------|
| [hledger-lsp](https://github.com/ptimoney/hledger-lsp) | Language server powering this plugin |
| [hledger-vscode](https://github.com/ptimoney/hledger-vscode) | VS Code extension with the same language server |
| [hledger](https://hledger.org/) | The plain text accounting tool |

## Contributing

Found a bug or have a feature request?

- **Plugin issues** (Neovim UI, setup, keybindings): [hledger-nvim issues](https://github.com/ptimoney/hledger-nvim/issues)
- **Server issues** (parsing, validation, formatting, completion): [hledger-lsp issues](https://github.com/ptimoney/hledger-lsp/issues)

Contributions are welcome &mdash; please feel free to submit a Pull Request.

## License

MIT
