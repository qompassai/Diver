#!/usr/bin/env bash
# steps/30-config.sh — install the Diver config itself, rootlessly.
#
# Ensures $XDG_CONFIG_HOME/nvim holds this Diver checkout:
#   - already this repo      → verify + optionally pull latest
#   - missing                → clone (if this repo has a remote) or copy
#   - something else         → back it up to nvim.bak-<timestamp>, then install
#
# Never deletes without a backup. Safe to re-run.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

REPO_ROOT="${DIVER_REPO_ROOT:?}"
TARGET="$XDG_CONFIG_HOME/nvim"

resolve() { # resolve <path> — canonical path, no symlink chasing failures
  cd -- "$1" >/dev/null 2>&1 && pwd -P || printf '%s' "$1"
}

CANON_REPO="$(resolve "$REPO_ROOT")"

if [[ -e $TARGET ]]; then
  CANON_TARGET="$(resolve "$TARGET")"
else
  CANON_TARGET=""
fi

if [[ -n $CANON_TARGET && $CANON_TARGET == "$CANON_REPO" ]]; then
  diver_log "config already installed at $TARGET (this checkout)"
  if [[ -d $TARGET/.git ]]; then
    remote="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
    if [[ -n $remote ]]; then
      diver_log "pulling latest from $remote"
      git -C "$TARGET" pull --ff-only || diver_warn "pull failed — keeping local state"
    fi
  fi
  diver_ok "config in place"
  exit 0
fi

repo_remote=""
if [[ -d $REPO_ROOT/.git ]]; then
  repo_remote="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
fi

if [[ -e $TARGET ]]; then
  backup="$XDG_CONFIG_HOME/nvim.bak-$(date +%Y%m%d-%H%M%S)"
  diver_warn "existing config at $TARGET is not this Diver checkout"
  diver_log "backing up → $backup"
  mv "$TARGET" "$backup"
fi

if [[ -n $repo_remote ]]; then
  diver_log "cloning $repo_remote → $TARGET"
  git clone "$repo_remote" "$TARGET" || diver_die "clone failed"
else
  diver_log "copying $REPO_ROOT → $TARGET"
  cp -a "$REPO_ROOT" "$TARGET" || diver_die "copy failed"
fi

diver_ok "Diver config installed at $TARGET"
