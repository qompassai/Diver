#!/usr/bin/env bash
# /qompassai/Diver/scripts/lsp/idris2.sh
# Qompass AI Diver Idris2 LSP Installer
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
#!/usr/bin/env bash
# /qompassai/Diver/scripts/lsp/idris2.sh

set -euo pipefail

# --- Config -------------------------------------------------------------
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export IDRIS2_PREFIX="${IDRIS2_PREFIX:-$XDG_DATA_HOME/idris2}"   # e.g. ~/.local/share/idris2
REPO_DIR="${REPO_DIR:-$HOME/.GH/idris2-lsp-src}"

mkdir -p "$IDRIS2_PREFIX" "$REPO_DIR"

# --- Clone / update idris2-lsp -----------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone https://github.com/idris-community/idris2-lsp.git "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --ff-only
fi

cd "$REPO_DIR"
git config protocol.https.allow always

# --- Idris2 bootstrap + install ----------------------------------------
git submodule update --init Idris2
cd Idris2

export SCHEME=chez
export IDRIS2_VERSION=0.8.0

# Clean the normal build directory but leave bootstrap-build alone
rm -rf build

# Ask the Makefile to handle bootstrap + build using Chez
make bootstrap SCHEME=chez \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"

make all \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"

make install \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"

make install-with-src-libs \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"

make install-with-src-api  \
  PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"

cd "$REPO_DIR"

# ensure current shell sees idris2
case ":$PATH:" in
  *":$IDRIS2_PREFIX/bin:"*) ;;
  *) export PATH="$IDRIS2_PREFIX/bin:$PATH" ;;
esac

# --- LSP-lib ------------------------------------------------------------
cd "$REPO_DIR"
git submodule update --init LSP-lib
cd LSP-lib
idris2 --install-with-src
cd "$REPO_DIR"

# --- idris2-lsp ---------------------------------------------------------
make install PREFIX="$IDRIS2_PREFIX" IDRIS2_PREFIX="$IDRIS2_PREFIX"

echo "idris2 & idris2-lsp installed to $IDRIS2_PREFIX/bin"
echo "Add this to your shell config (e.g. ~/.bashrc, ~/.zshrc):"
echo "    export XDG_DATA_HOME=\"\${XDG_DATA_HOME:-\$HOME/.local/share}\""
echo "    export IDRIS2_PREFIX=\"\${IDRIS2_PREFIX:-\$XDG_DATA_HOME/idris2}\""
echo "    export PATH=\"\$IDRIS2_PREFIX/bin:\$PATH\""