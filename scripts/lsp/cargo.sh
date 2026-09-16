#!/usr/bin/env bash
# /qompassai/Diver/lsp/cargo.sh
# Qompass AI Diver Rust/Cargo LSP installer
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
CARGO_BIN="$CARGO_HOME/bin"
export XDG_DATA_HOME CARGO_HOME
export PATH="$CARGO_BIN:$PATH"
STRICT="${DIVER_LSP_STRICT:-0}"
FAILURES=0
is_termux=0
if [[ ${PREFIX-} == *com.termux* ]] || [[ ${TERMUX_VERSION-} != '' ]]; then
  is_termux=1
fi

run_install()
{
  local label=$1
  shift

  printf '→ Installing %s\n' "$label"

  if "$@"; then
    return 0
  fi

  FAILURES=$((FAILURES + 1))
  printf '⚠ Failed: %s\n' "$label" >&2

  if [[ $STRICT == 1 ]]; then
    exit 1
  fi
}

require_cargo()
{
  if ((is_termux)) && ! command -v cargo > /dev/null 2>&1; then
    printf '→ Installing the Termux Rust toolchain\n'
    pkg install -y rust git clang make pkg-config
  fi

  if ! command -v cargo > /dev/null 2>&1; then
    cat >&2 <<'EOF'
Error: cargo was not found.

Linux, macOS, and WSL: install Rust with rustup from https://rustup.rs/.
Termux: run `pkg install rust git clang make pkg-config`.
Native Windows PowerShell/cmd cannot execute this Bash script directly; use WSL
or use a dedicated PowerShell installer.
EOF
    exit 1
  fi

  if ! command -v git > /dev/null 2>&1; then
    printf 'Error: git is required by cargo install --git.\n' >&2
    exit 1
  fi
}

install_git()
{
  local label=$1
  local repository=$2
  shift 2

  run_install "$label" cargo install --git "$repository" "$@"
}

require_cargo

printf '→ Cargo host: %s\n' "$(rustc -vV | sed -n 's/^host: //p')"
printf '→ Cargo install root: %s\n' "$CARGO_HOME"

if ((is_termux)); then
  printf '→ Termux detected: skipping Buck2 nightly bootstrap.\n'
elif command -v rustup > /dev/null 2>&1; then
  if rustup toolchain install nightly-2025-08-01; then
    run_install \
      'buck2' \
      cargo +nightly-2025-08-01 install \
      --git https://github.com/facebook/buck2.git buck2
  else
    FAILURES=$((FAILURES + 1))
    printf '⚠ Failed to install Rust nightly-2025-08-01; skipping Buck2.\n' >&2

    if [[ $STRICT == 1 ]]; then
      exit 1
    fi
  fi
else
  printf '⚠ rustup is unavailable; skipping Buck2 nightly bootstrap.\n' >&2
fi

install_git 'lelwel' https://github.com/0x2a-42/lelwel lelwel \
  --features clap,cli,lsp,wasm
install_git 'mm0-rs' https://github.com/digama0/mm0 --locked mm0-rs
install_git 'vale-ls' https://github.com/errata-ai/vale-ls vale-ls
install_git 'gn-language-server' https://github.com/google/gn-language-server gn-language-server
install_git 'dts-lsp' https://github.com/igor-prusov/dts-lsp dts-lsp
install_git 'ink-analyzer' https://github.com/ink-analyzer/ink-analyzer.git ink-analyzer
install_git 'prosemd-lsp' https://github.com/kitten/prosemd-lsp prosemd-lsp
install_git 'testing-ls-adapter' https://github.com/kbwo/testing-language-server testing-ls-adapter
install_git 'testing-language-server' https://github.com/kbwo/testing-language-server testing-language-server
install_git 'neocmakelsp' https://github.com/neocmakelsp/neocmakelsp neocmakelsp
install_git 'pest-language-server' https://github.com/pest-parser/pest-ide-tools pest-language-server
install_git 'rumdl' https://github.com/rvben/rumdl rumdl
install_git 'taplo-cli' https://github.com/tamasfe/taplo taplo-cli --features lsp
install_git 'test-gen' https://github.com/tamasfe/taplo test-gen
install_git 'typos-lsp' https://github.com/tekumara/typos-lsp typos-lsp
install_git 'uiua' https://github.com/uiua-lang/uiua uiua -F full
install_git 'wgsl-analyzer' https://github.com/wgsl-analyzer/wgsl-analyzer wgsl-analyzer
install_git 'pbls' https://git.sr.ht/~rrc/pbls pbls

if ((FAILURES > 0)); then
  printf '⚠ %d Cargo installer job(s) failed. Installed binaries are in %s.\n' \
    "$FAILURES" "$CARGO_BIN" >&2
  exit 1
fi

printf '✓ Cargo LSP installation complete. Binaries are in %s.\n' "$CARGO_BIN"