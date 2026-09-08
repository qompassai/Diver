#!/usr/bin/env bash
# /qompassai/Diver/lsp/cargo.sh
# Qompass AI Diver LSP Cargo Script
# Copyright (C) 2025 Qompass AI, All rights reserved
# ----------------------------------------
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export XDG_BIN_HOME="$XDG_DATA_HOME/bin"
export PATH="$XDG_BIN_HOME:$CARGO_HOME/bin:$PATH"
rustup install nightly-2025-08-01 && \
  cargo +nightly-2025-08-01 install --git https://github.com/facebook/buck2.git buck2
cargo install --git https://github.com/0x2a-42/lelwel lelwel \
  --features "clap,cli,lsp,wasm"
cargo install --git https://github.com/digama0/mm0 --locked mm0-rs
cargo install --git https://github.com/errata-ai/vale-ls vale-ls
cargo install --git https://github.com/google/gn-language-server gn-language-server
cargo install --git https://github.com/igor-prusov/dts-lsp dts-lsp
cargo install --git https://github.com/ink-analyzer/ink-analyzer.git ink-analyzer
cargo install --git https://github.com/kitten/prosemd-lsp prosemd-lsp
cargo install --git https://github.com/kbwo/testing-language-server testing-ls-adapter
cargo install --git https://github.com/kbwo/testing-language-server testing-language-server
cargo install --git https://github.com/neocmakelsp/neocmakelsp neocmakelsp
cargo install --git https://github.com/pest-parser/pest-ide-tools pest-language-server
cargo install --git https://github.com/rvben/rumdl rumdl
cargo install --git https://github.com/tamasfe/taplo taplo-cli --features lsp
cargo install --git https://github.com/tamasfe/taplo test-gen
cargo install --git https://github.com/tekumara/typos-lsp typos-lsp
cargo install --git https://github.com/uiua-lang/uiua uiua -F full
cargo install --git https://github.com/wgsl-analyzer/wgsl-analyzer wgsl-analyzer
cargo install --git https://git.sr.ht/~rrc/pbls pbls