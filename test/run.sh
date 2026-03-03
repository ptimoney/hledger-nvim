#!/bin/sh
# Run all hledger-nvim tests.
# Usage: cd hledger-nvim && ./test/run.sh
set -e

cd "$(dirname "$0")/.."

# Set up luarocks paths. Try --lua-version 5.1 first (multi-version installs),
# then fall back to plain luarocks path (CI / single-version installs).
eval "$(luarocks --lua-version 5.1 path --bin 2>/dev/null || luarocks path --bin)"
busted
