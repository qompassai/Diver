#!/usr/bin/env bash
# steps/50-lsp.sh — run the per-language LSP installer scripts.
#
# Dispatches every scripts/lsp/*.sh as an isolated process, continuing past
# optional failures unless DIVER_LSP_STRICT=1. All installers are rootless
# (user-local package installs, no sudo).
#
# Env:
#   DIVER_INSTALL_LSPS  0 to skip (default 1)
#   DIVER_LSP_DIR       override installer dir (default <repo>/scripts/lsp)
#   DIVER_LSP_STRICT    1 to stop at first failure (default 0)

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

INSTALL_LSPS="${DIVER_INSTALL_LSPS:-1}"
LSP_STRICT="${DIVER_LSP_STRICT:-0}"
LSP_INSTALL_DIR="${DIVER_LSP_DIR:-${DIVER_REPO_ROOT:?}/scripts/lsp}"

if [[ $INSTALL_LSPS != 1 ]]; then
  diver_log "skipping LSP installers (DIVER_INSTALL_LSPS=$INSTALL_LSPS)"
  exit 0
fi

if [[ ! -d $LSP_INSTALL_DIR ]]; then
  diver_warn "LSP installer directory not found: $LSP_INSTALL_DIR"
  diver_warn "set DIVER_LSP_DIR to the directory containing the installer scripts"
  exit 0
fi

shopt -s nullglob
installers=("$LSP_INSTALL_DIR"/*.sh)
shopt -u nullglob

if ((${#installers[@]} == 0)); then
  diver_warn "no LSP installer scripts under $LSP_INSTALL_DIR"
  exit 0
fi

diver_log "running ${#installers[@]} LSP installer(s) from $LSP_INSTALL_DIR"

failures=0
for script in "${installers[@]}"; do
  echo
  diver_log "installer: $(basename "$script")"
  if bash "$script"; then
    diver_ok "completed: $(basename "$script")"
  else
    failures=$((failures + 1))
    diver_warn "failed: $(basename "$script")"
    if [[ $LSP_STRICT == 1 ]]; then
      diver_die "stopping because DIVER_LSP_STRICT=1"
    fi
  fi
done

if ((failures > 0)); then
  diver_warn "$failures installer(s) failed — neovim itself is fine; inspect output above"
  diver_warn "re-run one directly: bash $LSP_INSTALL_DIR/<name>.sh"
else
  diver_ok "all LSP installers completed"
fi
