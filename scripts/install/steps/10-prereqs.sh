#!/usr/bin/env bash
# steps/10-prereqs.sh — bootstrap build tooling, rootlessly.
#
# Default: the full from-source toolchain (git, curl, tar, make, clang,
# cmake, ninja, gettext, pkg-config) is bootstrapped into $PREFIX for any
# tool that is missing — this feeds the default from-source Neovim build.
# A C compiler is satisfied by clang OR gcc; clang is only bootstrapped
# when neither exists.
#
# Opt-out: DIVER_NVIM_PREBUILT=1 skips the toolchain and only verifies the
# download/extract basics (curl, tar, bash) for the prebuilt nightly.
#
# Everything builds into $PREFIX — no root required.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

PREBUILT="${DIVER_NVIM_PREBUILT:-0}"

install_git() {
  local ver="2.53.0"
  local url="https://mirrors.edge.kernel.org/pub/software/scm/git/git-${ver}.tar.xz"
  local dest="$DIVER_TMP_DIR/git-src"
  diver_download_extract "$url" "$dest"
  (
    cd "$dest"
    make configure
    ./configure --prefix="$PREFIX"
    make -j"$(nproc)"
    make install
  )
}

install_cmake() {
  local ver="4.4.3"
  local url="https://github.com/Kitware/CMake/releases/download/v${ver}/cmake-${ver}-${DIVER_OS}-${DIVER_ARCH}.tar.gz"
  local dest="$PREFIX/cmake-${ver}"
  diver_download_extract "$url" "$dest" 1
  diver_link_bin "$dest/bin/cmake" cmake
  diver_link_bin "$dest/bin/ctest" ctest
  diver_link_bin "$dest/bin/cpack" cpack
}

install_ninja() {
  local asset="ninja-linux.zip"
  [[ $DIVER_ARCH == aarch64 ]] && asset="ninja-linux-aarch64.zip"
  local url="https://github.com/ninja-build/ninja/releases/latest/download/${asset}"
  local dest="$DIVER_TMP_DIR/ninja"
  diver_download_extract "$url" "$dest"
  install -m 755 "$dest/ninja" "$BIN_DIR/ninja"
}

install_clang() {
  local ver="21.1.8"
  local asset="LLVM-${ver}-Linux-X64.tar.xz"
  [[ $DIVER_ARCH == aarch64 ]] && asset="LLVM-${ver}-Linux-ARM64.tar.xz"
  local url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${ver}/${asset}"
  local dest="$PREFIX/clang-${ver}"
  diver_log "LLVM ${ver} is a large download (~1 GB) — one-time cost"
  diver_download_extract "$url" "$dest" 1
  diver_link_bin "$dest/bin/clang" clang
  diver_link_bin "$dest/bin/clang++" clang++
}

install_pkg_config() {
  local ver="2.3.0"
  local url="https://distfiles.ariadne.space/pkgconf/pkgconf-${ver}.tar.xz"
  local dest="$DIVER_TMP_DIR/pkgconf-src"
  diver_download_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX" --with-system-libdir=/usr/lib --with-system-includedir=/usr/include
    make -j"$(nproc)"
    make install
  )
  ln -sf "$BIN_DIR/pkgconf" "$BIN_DIR/pkg-config" 2>/dev/null || true
}

install_gettext() {
  local ver="0.26"
  local url="https://ftp.gnu.org/gnu/gettext/gettext-${ver}.tar.gz"
  local dest="$DIVER_TMP_DIR/gettext-src"
  diver_download_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX" --disable-java --disable-csharp
    make -j"$(nproc)"
    make install
  )
}

install_tar() {
  local ver="1.35"
  local url="https://ftp.gnu.org/gnu/tar/tar-${ver}.tar.gz"
  local dest="$DIVER_TMP_DIR/tar-src"
  diver_download_extract "$url" "$dest"
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
  local dest="$DIVER_TMP_DIR/make-src"
  diver_download_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX"
    make -j"$(nproc)"
    make install
  )
}

if ((IS_NIX_ON_DROID)); then
  diver_log "Nix-on-Droid detected — nix user profiles are the package story"
  diver_have nix || diver_die "nix not on PATH under Nix-on-Droid"
  diver_ok "prerequisites present (nix $(nix --version 2>/dev/null))"
  exit 0
fi

if ((IS_TERMUX)); then
  diver_log "Termux detected — installing via pkg"
  pkg update -y
  pkg upgrade -y
  pkg install -y git curl tar make clang cmake ninja pkg-config python nodejs 2>/dev/null || true
  exit 0
fi

if [[ $PREBUILT == 1 ]]; then
  diver_log "prebuilt mode — only checking download basics"
  for t in curl tar bash; do
    diver_have "$t" || diver_die "missing required tool for binary install: $t"
  done
  diver_ok "prerequisites present (curl, tar, bash)"
  exit 0
fi

diver_log "source-build mode (default) — bootstrapping missing tools into $PREFIX"

need_tool() {
  local t=$1
  diver_have "$t" && return 0
  [[ -x "$BIN_DIR/$t" ]] && return 0
  return 1
}

need_compiler() {
  need_tool clang || need_tool gcc || need_tool cc
}

NEEDED_TOOLS=(git curl tar make cmake ninja bash pkg-config gettext)
MISSING=()
for tool in "${NEEDED_TOOLS[@]}"; do
  need_tool "$tool" || MISSING+=("$tool")
done
need_compiler || MISSING+=("cc")

for t in "${MISSING[@]}"; do
  case "$t" in
    git) install_git ;;
    cmake) install_cmake ;;
    ninja) install_ninja ;;
    cc)
      diver_log "no C compiler found — bootstrapping clang"
      install_clang
      ;;
    pkg-config) install_pkg_config ;;
    gettext) install_gettext ;;
    tar) install_tar ;;
    make) install_make ;;
    curl | bash)
      diver_die "please install $t with your system package manager and re-run"
      ;;
    *)
      diver_die "no bootstrap recipe for $t"
      ;;
  esac
done

diver_ok "build toolchain ready in $PREFIX"
