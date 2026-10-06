#!/usr/bin/env bash
# /qompassai/Diver/scripts/quickstart.sh
# Qompass AI Diver Quickstart Script
# Copyright (C) 2025 Qompass AI, All rights reserved
#####################################################
#
# NOTE: quickstart.sh is now a thin wrapper around scripts/install.sh,
# which runs the same work as a cascade of numbered steps under
# scripts/install/steps/ (prereqs → neovim → config → toolchains → lsp →
# formatters → linters → dap → treesitter → hosts → finish).
#
# The old environment knobs keep working:
#   DIVER_INSTALL_LSPS=0   skip the LSP installer step
#   DIVER_LSP_DIR=...      override the LSP installer directory
#   DIVER_LSP_STRICT=1     stop at the first failed LSP installer
#   BUILD_DIR=...          neovim source checkout (with --source)
#
# Old default built Neovim from source; the cascade installs the prebuilt
# nightly by default. Pass --source (or DIVER_NVIM_SOURCE=1) for the
# from-source build.

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

echo "note: quickstart.sh now delegates to scripts/install.sh (same env knobs apply)" >&2
exec bash "$SCRIPT_DIR/install.sh" "$@"
