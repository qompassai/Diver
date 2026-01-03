#!/usr/bin/env bash
# /qompassai/Diver/lsp/cargo.sh
# Qompass AI Diver LSP Cargo Script
# Copyright (C) 2025 Qompass AI, All rights reserved
# ----------------------------------------
cargo install --features lsp --locked taplo-cli
cargo install --git https://github.com/wgsl-analyzer/wgsl-analyzer wgsl-analyzer
cargo install --git https://github.com/kitten/prosemd-lsp prosemd-lsp
cargo install --git https://github.com/digama0/mm0 --locked mm0-rs
cargo install --git https://github.com/pest-parser/pest-ide-tools