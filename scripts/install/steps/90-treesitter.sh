#!/usr/bin/env bash
# steps/90-treesitter.sh — install tree-sitter parsers, headlessly.
#
# Uses the freshly installed nvim to install the parsers Diver declares
# (via nvim-treesitter's :TSInstallSync). Parser compilation needs a C
# compiler (cc/gcc/clang) on PATH — verified up front, not assumed.
#
# Env:
#   DIVER_TS_PARSERS  space-separated parser list override
#                     (default: the config's ensure_installed list)

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

diver_have nvim || diver_die "nvim not on PATH — run step 20 first"

# nvim-treesitter compiles parsers locally: a C compiler is mandatory.
if ! diver_have cc && ! diver_have gcc && ! diver_have clang; then
  diver_warn "no C compiler (cc/gcc/clang) on PATH — tree-sitter parsers cannot build"
  diver_warn "install a compiler and re-run: bash scripts/install.sh --only 90-treesitter"
  exit 0
fi

# Try to read the parser list straight out of the installed config so this
# step tracks Diver instead of a hardcoded list.
PARSERS="${DIVER_TS_PARSERS:-}"
if [[ -z $PARSERS ]]; then
  cfg="$XDG_CONFIG_HOME/nvim"
  # Common spots: lua/plugins/treesitter.lua, lua/treesitter.lua, plugin specs.
  PARSERS="$(rg -No --no-filename "ensure_installed\s*=\s*\{[^}]*\}" "$cfg/lua" 2>/dev/null \
    | rg -o "'[a-z0-9_+-]+'|\"[a-z0-9_+-]+\"" \
    | tr -d "'\"" | sort -u | tr '\n' ' ' || true)"
fi

if [[ -z $PARSERS ]]; then
  diver_warn "could not find an ensure_installed list in the config"
  diver_warn "install parsers manually: nvim -c 'TSInstallSync <langs>'"
  exit 0
fi

count="$(printf '%s' "$PARSERS" | wc -w)"
diver_log "installing $count tree-sitter parsers (headless)"

# TSInstallSync blocks until done; --headless with +q exits cleanly.
if nvim --headless -c "TSInstallSync $PARSERS" -c 'q' 2>"$DIVER_TMP_DIR/ts.log"; then
  diver_ok "tree-sitter parsers installed"
else
  diver_warn "parser install reported errors — see $DIVER_TMP_DIR/ts.log"
  tail -20 "$DIVER_TMP_DIR/ts.log" >&2 || true
fi
