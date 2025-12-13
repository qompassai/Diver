#!/usr/bin/env bash
# /qompassai/Diver/scripts/quickstart.sh
# Qompass AI Diver Quickstart Script
# Copyright (C) 2025 Qompass AI, All rights reserved
#####################################################
set -euo pipefail
#https://neovim.io/doc2/build/
PREFIX="$HOME/.local"
BIN_DIR="$PREFIX/bin"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
NVIM_DATA_DIR="$XDG_DATA_HOME/nvim"
BUILD_DIR="${BUILD_DIR:-$HOME/src/neovim-nightly}"
TMP_DIR="${TMPDIR:-/tmp}/nvim-bootstrap-$$"
mkdir -p "$BIN_DIR" "$NVIM_DATA_DIR" "$BUILD_DIR" "$TMP_DIR"
OS="linux"
ARCH="x86_64"
download_and_extract() {
  local url=$1
  local dest_dir=$2
  local strip_top=${3:-0}
  mkdir -p "$dest_dir"
  local fname="$TMP_DIR/$(basename "$url")"
  echo "→ Downloading $url"
  curl -L --fail -o "$fname" "$url"
  case "$fname" in
  *.tar.gz | *.tgz)
    if [[ "$strip_top" -eq 1 ]]; then
      tar -xzf "$fname" -C "$dest_dir" --strip-components=1
    else
      tar -xzf "$fname" -C "$dest_dir"
    fi
    ;;
  *.tar.xz)
    if [[ "$strip_top" -eq 1 ]]; then
      tar -xJf "$fname" -C "$dest_dir" --strip-components=1
    else
      tar -xJf "$fname" -C "$dest_dir"
    fi
    ;;
  *.zip)
    unzip -q "$fname" -d "$dest_dir"
    ;;
  *)
    echo "!! Unknown archive format: $fname"
    exit 1
    ;;
  esac
}
install_git() {
  local ver="2.47.0"
  local url="https://mirrors.edge.kernel.org/pub/software/scm/git/git-${ver}.tar.xz"
  local dest="$TMP_DIR/git-src"
  download_and_extract "$url" "$dest"
  (
    cd "$dest"
    make configure
    ./configure --prefix="$PREFIX"
    make -j"$(nproc)"
    make install
  )
}
install_cmake() {
  local ver="4.2.1"
  local url="https://github.com/Kitware/CMake/releases/download/v${ver}/cmake-${ver}-${OS}-${ARCH}.tar.gz"
  local dest="$PREFIX/cmake-${ver}"
  download_and_extract "$url" "$dest" 1
  ln -sf "$dest/bin/cmake" "$BIN_DIR/cmake"
  ln -sf "$dest/bin/ctest" "$BIN_DIR/ctest"
  ln -sf "$dest/bin/cpack" "$BIN_DIR/cpack"
  ln -sf "$dest/bin/cmakexbuild" 2>/dev/null || true
}
install_ninja() {
  local url="https://github.com/ninja-build/ninja/releases/latest/download/ninja-${OS}.zip"
  local dest="$TMP_DIR/ninja"
  download_and_extract "$url" "$dest"
  install -m 755 "$dest/ninja" "$BIN_DIR/ninja"
}
install_clang() {
  local ver="21.1.6" # pick a release
  local url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${ver}/clang+llvm-${ver}-x86_64-linux-gnu-ubuntu-22.04.tar.xz"
  local dest="$PREFIX/clang-${ver}"
  download_and_extract "$url" "$dest" 1
  ln -sf "$dest/bin/clang" "$BIN_DIR/clang"
  ln -sf "$dest/bin/clang++" "$BIN_DIR/clang++"
}
install_pkg_config() {
  local ver="0.29.2"
  local url="https://pkgconfig.freedesktop.org/releases/pkg-config-${ver}.tar.gz"
  local dest="$TMP_DIR/pkg-config-src"
  download_and_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX" --with-internal-glib
    make -j"$(nproc)"
    make install
  )
}
install_tar() {
  local ver="1.35"
  local url="https://ftp.gnu.org/gnu/tar/tar-${ver}.tar.gz"
  local dest="$TMP_DIR/tar-src"
  download_and_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX"
    make -j"$(nproc)"
    make install
  )
}
install_make() {
  local ver="4.4.1"
  local url="https://ftp.gnu.org/gnu/make/make-${ver}.tar.gz"
  local dest="$TMP_DIR/make-src"
  download_and_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX"
    make -j"$(nproc)"
    make install
  )
}
NEEDED_TOOLS=(git curl tar make clang cmake ninja bash pkg-config)
MISSING=()
need_tool() {
  local t=$1
  if command -v "$t" >/dev/null 2>&1; then
    return 0
  elif [[ -x "$BIN_DIR/$t" ]]; then
    return 0
  else
    return 1
  fi
}
for tool in "${NEEDED_TOOLS[@]}"; do
  if ! need_tool "$tool"; then
    MISSING+=("$tool")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "→ Bootstrapping missing tools into $PREFIX:"
  for t in "${MISSING[@]}"; do
    case "$t" in
    git) install_git ;;
    cmake) install_cmake ;;
    ninja) install_ninja ;;
    clang) install_clang ;;
    pkg-config) install_pkg_config ;;
    tar) install_tar ;;
    make) install_make ;;
    curl | bash)
      echo "  Please install $t via your package manager and re-run."
      exit 1
      ;;
    *)
      echo "!! No bootstrap recipe defined for $t"
      exit 1
      ;;
    esac
  done
fi
export PATH="$BIN_DIR:$PATH"
if [[ -d "$BUILD_DIR/.git" ]]; then
  cd "$BUILD_DIR"
  git fetch --all --tags
else
  git clone https://github.com/neovim/neovim "$BUILD_DIR" --recursive
  cd "$BUILD_DIR"
fi
git switch nightly
rm -rf build .deps
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .deps
cmake -B build -G Ninja \
  -D CMAKE_BUILD_TYPE=RelWithDebInfo \
  -D CMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build build
cmake --install build
add_path_line="export PATH=\"$BIN_DIR:\$PATH\""
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
  [[ -f "$rc" ]] || continue
  if ! grep -Fq "$BIN_DIR" "$rc"; then
    printf '\n# Added by Neovim nightly installer\n%s\n' "$add_path_line" >>"$rc"
    echo "→ PATH updated in $rc"
  fi
done
pnpm add -g neovim && pip install pynvim && gem install neovim
echo "Great Success!"
rm -rf "$TMP_DIR"
