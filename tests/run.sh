#!/usr/bin/env bash
# Run the headless test suite.
set -euo pipefail
cd "$(dirname "$0")/.."
exec nvim --headless -u NONE -l tests/test_startinator.lua
