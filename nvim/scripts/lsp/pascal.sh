#!/usr/bin/env bash
# /qompassai/Diver/scripts/pascal.sh
# Qompass AI Diver Pascal Script
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
set -euo pipefail
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
FPC_PREFIX="${XDG_DATA_HOME}/fpc"
LAZ_PREFIX="${XDG_DATA_HOME}/lazarus"
PAS_PREFIX="$XDG_DATA_HOME/pascal-language-server"
PAS_BIN="$FPC_PREFIX/bin"
mkdir -p "$FPC_PREFIX/bin" "$LAZ_PREFIX" "$PAS_PREFIX"
if [ ! -d "$LAZ_PREFIX/.git" ]; then
  git clone https://gitlab.com/freepascal.org/lazarus/lazarus.git --recursive "$LAZ_PREFIX"
fi
export PATH="$PAS_BIN:$PATH"
(
  cd "$LAZ_PREFIX"
  if [ ! -x "$LAZ_PREFIX/lazbuild" ]; then
    make all
  fi
)
if [ ! -d "$PAS_PREFIX/.git" ]; then
  git clone https://github.com/genericptr/pascal-language-server.git --recursive "$PAS_PREFIX"
fi
(
  cd "$PAS_PREFIX"
  "$LAZ_PREFIX/lazbuild" \
    --lazarusdir="$LAZ_PREFIX" \
    src/protocol/lspprotocol.lpk
  "$LAZ_PREFIX/lazbuild" \
    --lazarusdir="$LAZ_PREFIX" \
    src/serverprotocol/lspserver.lpk
  "$LAZ_PREFIX/lazbuild" \
    --lazarusdir="$LAZ_PREFIX" \
    src/standard/pasls.lpi
)
cp "$PAS_PREFIX/src/standard/pasls" "$PAS_BIN/"
add_line_if_missing() {
  local file="$1"
  local line="$2"
  [ -f "$file" ] || touch "$file"
  if ! grep -Fq "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
  fi
}
BASHRC="$HOME/.bashrc"
BASH_LINE="export XDG_DATA_HOME=(${XDG_DATA_HOME:-$HOME/.local/share}); export PATH=(${XDG_DATA_HOME}/fpc/bin:${PATH})"
add_line_if_missing "$BASHRC" "$BASH_LINE"
ZSHRC="$HOME/.zshrc"
ZSH_LINE="export XDG_DATA_HOME=(${XDG_DATA_HOME:-$HOME/.local/share}); export PATH=($XDG_DATA_HOME/fpc/bin:$PATH)"
add_line_if_missing "$ZSHRC" "$ZSH_LINE"
FISH_CONF_DIR="${XDG_CONFIG_HOME}/fish/conf.d"
FISH_SNIPPET="$FISH_CONF_DIR/pascal.fish"
mkdir -p "$FISH_CONF_DIR"
if [ ! -f "$FISH_SNIPPET" ]; then
  cat > "$FISH_SNIPPET" <<'EOF'
if not set -q XDG_DATA_HOME
    set -x XDG_DATA_HOME "$HOME/.local/share"
end
if not contains "${XDG_DATA_HOME}/fpc/bin" $PATH
    set -x PATH "$XDG_DATA_HOME/fpc/bin" $PATH
end
EOF
else
  if ! grep -Fq 'XDG_DATA_HOME' "${FISH_SNIPPET}"; then
    printf '%s\n' 'if not set -q XDG_DATA_HOME' >> "${FISH_SNIPPET}"
    printf '%s\n' "    set -x XDG_DATA_HOME (${HOME}/.local/share)" >> "$FISH_SNIPPET"
    printf '%s\n' 'end' >> "$FISH_SNIPPET"
  fi
  if ! grep -Fq 'fpc/bin' "$FISH_SNIPPET"; then
    printf '%s\n' "if not contains (${XDG_DATA_HOME}/fpc/bin) ${PATH}" >> "$FISH_SNIPPET"
    printf '%s\n' "    set -x PATH (${XDG_DATA_HOME}/fpc/bin) ${PATH}" >> "${FISH_SNIPPET}"
    printf '%s\n' 'end' >> "${FISH_SNIPPET}"
  fi
fi
printf 'pasls installed at: %s/pasls\n' "${PAS_BIN}"