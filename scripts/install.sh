#!/usr/bin/env bash
# scripts/install.sh — Diver rootless installer (cascade orchestrator).
#
# Installs the Diver Neovim config and its full tooling without root:
# everything lands under $HOME/.local (Linux/WSL) or $PREFIX (Termux).
#
# Usage:
#   bash scripts/install.sh [options]
#
# Options:
#   --only 10,20,30     run only these steps (by number or name fragment)
#   --skip 50,60        skip these steps
#   --list              list steps and exit
#   --source            build Neovim from source (default; kept for compatibility)
#   --prebuilt          use the prebuilt Neovim nightly instead of building
#   -h, --help          this help
#
# Environment (all optional):
#   PREFIX              install prefix (default ~/.local, or $PREFIX on Termux)
#   BUILD_DIR           neovim source checkout dir (default ~/src/neovim-nightly)
#   DIVER_INSTALL_LSPS  0 to skip the LSP step (default 1)
#   DIVER_INSTALL_DAP   0 to skip the DAP step (default 1)
#   DIVER_LSP_DIR       override the LSP installer directory
#   DIVER_LSP_STRICT    1 to stop at the first failed LSP installer (default 0)
#   DIVER_NVIM_SOURCE   1 builds from source (default 1); 0 takes the prebuilt
#   DIVER_NVIM_PREBUILT 1 takes the prebuilt nightly (same as --prebuilt)
#   DIVER_NVIM_BUILD_TYPE
#                       Release (default) | RelWithDebInfo | Debug
#   DIVER_NVIM_CFLAGS   extra C/C++ flags (default "-O3 -march=native")
#   DIVER_NVIM_LTO      1 enables link-time optimization (default 0)
#   DIVER_NVIM_DRY_RUN  1 validates clone + cmake configure, skips the build
#
# Each step is a separate bash process, so one step's failure never
# corrupts another's shell state. Steps are idempotent — re-running the
# installer only fills gaps.
#
# Fresh machine:
#   git clone https://github.com/qompassai/diver ~/.config/nvim
#   bash ~/.config/nvim/scripts/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
STEPS_DIR="$SCRIPT_DIR/install/steps"
LIB_DIR="$SCRIPT_DIR/install/lib"

# shellcheck source=install/lib/common.sh
source "$LIB_DIR/common.sh"

export DIVER_REPO_ROOT="$REPO_ROOT"
export DIVER_SCRIPT_DIR="$SCRIPT_DIR"

DIVER_TMP_DIR="${TMPDIR:-/tmp}/diver-install-$$"
mkdir -p "$DIVER_TMP_DIR"
export DIVER_TMP_DIR

cleanup() {
  rm -rf "$DIVER_TMP_DIR"
}
trap cleanup EXIT

ONLY=()
SKIP=()

usage() {
  sed -n '2,/^$/p' "$SCRIPT_DIR/install.sh" | sed 's/^# \{0,1\}//'
}

list_steps() {
  local f base
  for f in "$STEPS_DIR"/[0-9]*.sh; do
    [[ -f $f ]] || continue
    base="$(basename "$f" .sh)"
    printf '%s\n' "$base"
  done | sort
}

step_matches() {
  # step_matches <step-base> <patterns...> — true if base matches any pattern
  # (pattern may be a number prefix like "20" or a name fragment like "lsp").
  local base=$1 pat
  shift
  for pat in "$@"; do
    if [[ $base == "$pat"* ]] || [[ $base == *"$pat"* ]]; then
      return 0
    fi
  done
  return 1
}

while (($# > 0)); do
  case "$1" in
    --only)
      IFS=',' read -ra ONLY <<<"$2"
      shift 2
      ;;
    --skip)
      IFS=',' read -ra SKIP <<<"$2"
      shift 2
      ;;
    --list)
      list_steps
      exit 0
      ;;
    --source)
      export DIVER_NVIM_SOURCE=1 # default; kept for compatibility
      shift
      ;;
    --prebuilt)
      export DIVER_NVIM_PREBUILT=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      diver_err "unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
done

diver_detect_platform

diver_step "Diver rootless installer"
diver_log "repo:   $REPO_ROOT"
diver_log "prefix: $PREFIX"
diver_log "platform: $DIVER_OS/$DIVER_ARCH (wsl=$IS_WSL termux=$IS_TERMUX)"

failures=()
ran=0

for step in $(list_steps); do
  if ((${#ONLY[@]} > 0)); then
    step_matches "$step" "${ONLY[@]}" || continue
  fi
  if ((${#SKIP[@]} > 0)); then
    if step_matches "$step" "${SKIP[@]}"; then
      diver_log "skipping step $step"
      continue
    fi
  fi

  diver_step "step $step"
  ran=$((ran + 1))
  if bash "$STEPS_DIR/$step.sh"; then
    diver_ok "step $step complete"
  else
    diver_err "step $step FAILED"
    failures+=("$step")
  fi
done

echo
if ((${#failures[@]} > 0)); then
  diver_err "${#failures[@]} step(s) failed: ${failures[*]}"
  diver_err "Re-run with --only to retry, e.g.: bash scripts/install.sh --only ${failures[0]}"
  exit 1
fi

if ((ran == 0)); then
  diver_warn "no steps ran — check --only/--skip filters"
  exit 0
fi

diver_ok "all $ran step(s) complete — restart your shell (or: export PATH=\"$BIN_DIR:\$PATH\")"
