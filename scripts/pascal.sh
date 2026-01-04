#!/usr/bin/env bash
# /qompassai/Diver/scripts/pascal.sh
# Qompass AI Diver Pascal Script
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
cd || "${XDG_DATA_HOME}"/pascal-language-server
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
LAZ_PREFIX="$XDG_DATA_HOME/lazarus"
cd || "$XDG_DATA_HOME/pascal-language-server"
"$LAZ_PREFIX/lazbuild" \
  --lazarusdir="$LAZ_PREFIX" \
  src/protocol/lspprotocol.lpk
"$LAZ_PREFIX/lazbuild" \
  --lazarusdir="$LAZ_PREFIX" \
  src/serverprotocol/lspserver.lpk
"$LAZ_PREFIX/lazbuild" \
  --lazarusdir="$LAZ_PREFIX" \
  src/standard/pasls.lpi