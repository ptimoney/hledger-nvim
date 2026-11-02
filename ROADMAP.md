# Roadmap

## Next

- Verify external-file-change refresh on a real Linux box (with and without
  `inotifywait`); so far only macOS is tested end-to-end, and Linux paths are
  covered by unit tests with a mocked platform.

## Notes / TODO

- Plugin doesn't pin an hledger-lsp version; README says 0.8.0+ is needed for
  external file changes. Consider a `:checkhealth hledger` that reports the
  server version and the file-watching capability/backend.
- The end-to-end watch check was a throwaway headless script; if it is needed
  again, make it an opt-in test (needs a built hledger-lsp, so not in CI).

## Completed

- Native `vim.lsp.config` setup (no nvim-lspconfig dependency), lspconfig-style
  `root_dir` adapter.
- Workspace graph (`:HledgerGraph`) with fuzzy filtering and preview.
- Unit test suite (busted in headless Neovim).
- External journal edits refresh diagnostics (hledger-lsp 0.8.0, issue #31):
  plugin opts `hledger_lsp` into `didChangeWatchedFiles` on Linux/BSD when
  `inotifywait` is present; README documents per-platform behaviour.
