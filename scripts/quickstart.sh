#!/usr/bin/env bash
# /qompassai/Diver/scripts/quickstart.sh
# Qompass AI Diver Quickstart Script
# Copyright (C) 2025 Qompass AI, All rights reserved
#####################################################
# Reference: https://neovim.io/doc2/build/
set -euo pipefail
IS_WSL=0
IS_TERMUX=0
case "$(uname -s)" in
  Linux)
    if grep -qi microsoft /proc/version 2> /dev/null; then
      IS_WSL=1
    fi
    ;;
esac
if [[ ${PREFIX-} == *com.termux* ]] \
  || [[ ${SHELL-} == *com.termux* ]] \
  || [[ ${HOME} == *com.termux* ]]; then
  IS_TERMUX=1
fi
if ((IS_TERMUX)); then
  PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
else
  PREFIX="${HOME}/.local"
fi
BIN_DIR="$PREFIX/bin"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INIT_LUA="$XDG_CONFIG_HOME/nvim/init.lua"
NVIM_DATA_DIR="$XDG_DATA_HOME/nvim"
BUILD_DIR="${BUILD_DIR:-$HOME/src/neovim-nightly}"
if ((IS_TERMUX)); then
  TMP_DIR="${TMPDIR:-$PREFIX/tmp}/nvim-bootstrap-$$"
else
  TMP_DIR="${TMPDIR:-/tmp}/nvim-bootstrap-$$"
fi
mkdir -p "$BIN_DIR" "$NVIM_DATA_DIR" "${BUILD_DIR}" "${TMP_DIR}"
OS='linux'
ARCH='x86_64'
if ((IS_TERMUX)); then
  OS='android'
  ARCH="$(uname -m)" # aarch64 on most modern Android devices
fi
download_and_extract()
{
  local url=$1
  local dest_dir=$2
  local strip_top=${3:-0}
  mkdir -p "$dest_dir"
  local fname="$TMP_DIR/$(basename "$url")"
  curl -L --fail -o "$fname" "$url"
  case "$fname" in
    *.tar.gz | *.tgz)
      if [[ $strip_top -eq 1 ]]; then
        tar -xzf "$fname" -C "$dest_dir" --strip-components=1
      else
        tar -xzf "$fname" -C "$dest_dir"
      fi
      ;;
    *.tar.xz)
      if [[ $strip_top -eq 1 ]]; then
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
install_git()
{
  if ((IS_TERMUX)); then
    pkg install -y git
    return 0
  fi
  local ver="2.53.0"
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
install_cmake()
{
  if ((IS_TERMUX)); then
    pkg install -y cmake
    return 0
  fi
  local ver="4.2.3"
  local url="https://github.com/Kitware/CMake/releases/download/v${ver}/cmake-${ver}-${OS}-${ARCH}.tar.gz"
  local dest="$PREFIX/cmake-${ver}"
  download_and_extract "$url" "$dest" 1
  ln -sf "$dest/bin/cmake" "$BIN_DIR/cmake"
  ln -sf "$dest/bin/ctest" "$BIN_DIR/ctest"
  ln -sf "$dest/bin/cpack" "$BIN_DIR/cpack"
  ln -sf "$dest/bin/cmakexbuild" "$BIN_DIR/cmakexbuild" 2> /dev/null || true
}
install_ninja()
{
  if ((IS_TERMUX)); then
    pkg install -y ninja
    return 0
  fi
  local url="https://github.com/ninja-build/ninja/releases/latest/download/ninja-${OS}.zip"
  local dest="$TMP_DIR/ninja"
  download_and_extract "$url" "$dest"
  install -m 755 "$dest/ninja" "$BIN_DIR/ninja"
}
install_clang()
{
  if ((IS_TERMUX)); then
    pkg install -y clang
    return 0
  fi
  local ver="21.1.8"
  local url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${ver}/clang+llvm-${ver}-x86_64-linux-gnu-ubuntu-22.04.tar.xz"
  local dest="$PREFIX/clang-${ver}"
  download_and_extract "$url" "$dest" 1
  ln -sf "$dest/bin/clang" "$BIN_DIR/clang"
  ln -sf "$dest/bin/clang++" "$BIN_DIR/clang++"
}
install_pkg_config()
{
  if ((IS_TERMUX)); then
    pkg install -y pkg-config
    return 0
  fi
  local ver="2.3.0"
  local url="https://distfiles.ariadne.space/pkgconf/pkgconf-${ver}.tar.xz"
  local dest="$TMP_DIR/pkgconf-src"
  download_and_extract "$url" "$dest"
  (
    cd "$dest"
    ./configure --prefix="$PREFIX" --with-system-libdir=/usr/lib --with-system-includedir=/usr/include
    make -j"$(nproc)"
    make install
  )
  ln -sf "$BIN_DIR/pkgconf" "$BIN_DIR/pkg-config" 2> /dev/null || true
}
install_tar()
{
  if ((IS_TERMUX)); then
    pkg install -y tar
    return 0
  fi
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
install_make()
{
  if ((IS_TERMUX)); then
    pkg install -y make
    return 0
  fi
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
install_luajit_and_lua_ls()
{
  if ((IS_TERMUX)); then
    pkg install -y luajit lua-language-server 2> /dev/null || true
    if command -v lua-language-server > /dev/null 2>&1; then
      cat > "$BIN_DIR/lua_ls" << 'EOF'
#!/usr/bin/env bash
exec lua-language-server "$@"
EOF
      chmod +x "$BIN_DIR/lua_ls"
    fi
    return 0
  fi
  local lj_dest="$TMP_DIR/LuaJIT-git"
  if [[ ! -d "$lj_dest/.git" ]]; then
    git clone https://luajit.org/git/luajit.git "$lj_dest"
  else
    git -C "$lj_dest" pull
  fi
  (
    cd "$lj_dest"
    make -j"$(nproc)" PREFIX="$PREFIX"
    make install PREFIX="$PREFIX"
  )
  local lr_ver="3.12.2"
  local lr_url="https://luarocks.github.io/luarocks/releases/luarocks-${lr_ver}.tar.gz"
  local lr_dest="$TMP_DIR/luarocks-${lr_ver}"
  download_and_extract "$lr_url" "$TMP_DIR"
  (
    cd "$lr_dest"
    ./configure \
      --prefix="$PREFIX" \
      --with-lua="$PREFIX" \
      --with-lua-include="$PREFIX/include/luajit-2.1" \
      --lua-suffix=jit
    make -j"$(nproc)"
    make install
  )
  export PATH="$BIN_DIR:$PATH"
  if command -v luarocks > /dev/null 2>&1; then
    luarocks install --lua-dir="$PREFIX" lua-language-server || {
      echo "Warning: luarocks lua-language-server install failed; check rock name/availability."
    }
  fi

  cat > "$BIN_DIR/lua_ls" << 'EOF'
#!/usr/bin/env bash
exec lua-language-server "$@"
EOF
  chmod +x "$BIN_DIR/lua_ls"
}
NEEDED_TOOLS=(git curl tar make clang cmake ninja bash pkg-config)
MISSING=()

need_tool()
{
  local t=$1
  command -v "$t" > /dev/null 2>&1 && return 0
  [[ -x "$BIN_DIR/$t" ]] && return 0
  return 1
}
for tool in "${NEEDED_TOOLS[@]}"; do
  need_tool "$tool" || MISSING+=("$tool")
done
if ((IS_TERMUX)); then
  pkg update -y
  pkg upgrade -y
  pkg install -y git curl tar make clang cmake ninja pkg-config python nodejs ruby 2> /dev/null || true
fi

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
        echo "  Please install $t and try again."
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
if ((IS_WSL)); then
  case "$PWD" in
    /mnt/*)
      echo "⚠ WSL2: building under /mnt is slow due to 9P cross-filesystem overhead."
      echo "  Recommend cloning/building under your Linux home (~/) instead."
      ;;
  esac
fi
if ((IS_TERMUX)) && command -v nvim > /dev/null 2>&1; then
  echo "→ Neovim already present in Termux; continuing with runtime/LSP/langhost setup."
fi
if [[ -d "$BUILD_DIR/.git" ]]; then
  cd "$BUILD_DIR"
  git fetch --all --tags
else
  git clone https://github.com/neovim/neovim "$BUILD_DIR" --recursive
  cd "$BUILD_DIR"
fi
git switch master || git checkout master
rm -rf build .deps
if ((IS_TERMUX)); then
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
fi
cmake -S cmake.deps -B .deps -G Ninja \
  -D CMAKE_BUILD_TYPE=RelWithDebInfo \
  -D USE_BUNDLED=ON \
  -D USE_BUNDLED_LUAJIT=ON
cmake --build .deps
cmake -B build -G Ninja \
  -D CMAKE_BUILD_TYPE=RelWithDebInfo \
  -D CMAKE_INSTALL_PREFIX="$PREFIX" \
  -D CMAKE_INSTALL_DATADIR="$NVIM_DATA_DIR"
cmake --build build
cmake --install build
RUNTIME_SRC="$PREFIX/share/nvim/runtime"
RUNTIME_DEST="$NVIM_DATA_DIR/runtime"

if [[ -d $RUNTIME_SRC ]]; then
  mkdir -p "$NVIM_DATA_DIR"
  if [[ -d $RUNTIME_DEST ]] && [[ ! -L $RUNTIME_DEST ]]; then
    mv "$RUNTIME_DEST" "${RUNTIME_DEST}.backup-$(date +%s)"
  fi
  [[ -L $RUNTIME_DEST ]] && rm "$RUNTIME_DEST"
  cp -r "$RUNTIME_SRC" "$RUNTIME_DEST"

  INIT_LUA="$XDG_CONFIG_HOME/nvim/init.lua"
  mkdir -p "$(dirname "$INIT_LUA")"

  RUNTIME_BLOCK='local data_runtime = vim.fn.stdpath("data") .. "/runtime"
if vim.fn.isdirectory(data_runtime) == 1 then
  vim.opt.runtimepath:prepend(data_runtime)
end
'
  if [[ -f $INIT_LUA ]]; then
    if ! grep -q "stdpath.*runtime" "$INIT_LUA"; then
      echo "$RUNTIME_BLOCK" | cat - "$INIT_LUA" > "$INIT_LUA.tmp"
      mv "$INIT_LUA.tmp" "$INIT_LUA"
      echo "✓ Runtime config added to $INIT_LUA"
    else
      echo "→ Runtime config already exists in $INIT_LUA"
    fi
  else
    cat > "$INIT_LUA" << 'EOINIT'
local data_runtime = vim.fn.stdpath("data") .. "/runtime"
if vim.fn.isdirectory(data_runtime) == 1 then
  vim.opt.runtimepath:prepend(data_runtime)
end
EOINIT
    echo "✓ Created init.lua with runtime setup at $INIT_LUA"
  fi
fi
add_path_line="export PATH=\"$BIN_DIR:\$PATH\""
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish" "$HOME/.profile"; do
  [[ -f $rc ]] || continue
  if ! grep -Fq "$BIN_DIR" "$rc"; then
    printf '\n# Added by Neovim nightly installer\n%s\n' "$add_path_line" >> "$rc"
    echo "→ PATH updated in $rc"
  fi
done
PARSER_SRC="${HOME}/.local/share/nvim/lazy/nvim-treesitter/parser"
PARSER_DEST="$NVIM_DATA_DIR/runtime/parser"
if [[ -d $PARSER_SRC ]]; then
  echo "→ Installing parsers to runtime"
  if [[ -d $PARSER_DEST ]] && [[ ! -L $PARSER_DEST ]]; then
    mv "$PARSER_DEST" "${PARSER_DEST}.backup-$(date +%s)"
    echo "  Backed up old parsers"
  fi
  [[ -L $PARSER_DEST ]] && rm "$PARSER_DEST"
  mkdir -p "$PARSER_DEST"
  cp -v "$PARSER_SRC"/*.so "$PARSER_DEST"/ 2> /dev/null || echo "⚠ No parser .so files found to copy"
  parser_count=$(find "$PARSER_DEST" -name "*.so" | wc -l)
  echo "✓ Installed $parser_count tree-sitter parsers"
else
  echo "⚠ Parser directory not found: $PARSER_SRC"
  echo "  Install parsers first: nvim -c 'TSInstall all' -c 'q'"
fi
install_luajit_and_lua_ls
if command -v pnpm > /dev/null 2>&1; then
  pnpm add -g neovim || echo "⚠ pnpm neovim host install failed"
elif command -v npm > /dev/null 2>&1; then
  npm install -g neovim || echo "⚠ npm neovim host install failed"
fi
if command -v pip > /dev/null 2>&1; then
  pip install --user pynvim || echo "⚠ pynvim install failed"
elif command -v pip3 > /dev/null 2>&1; then
  pip3 install --user pynvim || echo "⚠ pynvim install failed"
fi
if command -v gem > /dev/null 2>&1; then
  gem install neovim || echo "⚠ Ruby neovim host install failed"
fi
NVIM_BIN="$BIN_DIR/nvim"
if ((IS_TERMUX)) && [[ ! -x $NVIM_BIN ]] && command -v nvim > /dev/null 2>&1; then
  NVIM_BIN="$(command -v nvim)"
fi
if [[ -x $NVIM_BIN ]]; then
  echo "Neovim → $NVIM_BIN"
  "$NVIM_BIN" --version | sed -n '1,8p'
else
  echo "Error: Neovim not at $NVIM_BIN :(" >&2
  exit 1
fi
echo "Great Success!"
rm -rf "$TMP_DIR"
