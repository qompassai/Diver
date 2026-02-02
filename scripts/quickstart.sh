#!/usr/bin/env bash
# /qompassai/Diver/scripts/quickstart.sh
# Qompass AI Diver Quickstart Script
# Copyright (C) 2025 Qompass AI, All rights reserved
#####################################################
# Reference: https://neovim.io/doc2/build/
set -euo pipefail
PREFIX="${HOME}/.local"
BIN_DIR="$PREFIX/bin"
INIT_LUA="$HOME/.config/nvim/init.lua"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
NVIM_DATA_DIR="$XDG_DATA_HOME/nvim"
BUILD_DIR="${BUILD_DIR:-$HOME/src/neovim-nightly}"
TMP_DIR="${TMPDIR:-/tmp}/nvim-bootstrap-$$"
mkdir -p "$BIN_DIR" "$NVIM_DATA_DIR" "${BUILD_DIR}" "${TMP_DIR}"
OS='linux'
ARCH='x86_64'
download_and_extract()
{
  local url=$1
  local dest_dir=$2
  local strip_top=${3:-0}
  mkdir -p "$dest_dir"
  local fname
  fname="$TMP_DIR/$(basename "$url")"
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
install_cmake()
{
  local ver="4.2.1"
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
  local url="https://github.com/ninja-build/ninja/releases/latest/download/ninja-${OS}.zip"
  local dest="$TMP_DIR/ninja"
  download_and_extract "$url" "$dest"
  install -m 755 "$dest/ninja" "$BIN_DIR/ninja"
}
install_clang()
{
  local ver="21.1.6"
  local url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${ver}/clang+llvm-${ver}-x86_64-linux-gnu-ubuntu-22.04.tar.xz"
  local dest="$PREFIX/clang-${ver}"
  download_and_extract "$url" "$dest" 1
  ln -sf "$dest/bin/clang" "$BIN_DIR/clang"
  ln -sf "$dest/bin/clang++" "$BIN_DIR/clang++"
}
install_pkg_config()
{
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
install_tar()
{
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
  install_luajit_and_lua_ls()
  {
    local lj_ver="2.1.0-beta3"
    local lj_url="https://luajit.org/download/LuaJIT-${lj_ver}.tar.gz"
    local lj_dest="$TMP_DIR/LuaJIT-${lj_ver}"
    download_and_extract "$lj_url" "$TMP_DIR"
    (
      cd "$lj_dest"
      make -j"$(nproc)" PREFIX="$PREFIX"
      make install PREFIX="$PREFIX"
    )
    local lr_ver="3.11.1"
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
    luarocks install --lua-dir="$PREFIX" lua-language-server || {
      echo "Warning: luarocks lua-language-server install failed; check rock name/availability."
    }
    cat > "$BIN_DIR/lua_ls" << 'EOF'
#!/usr/bin/env bash
# Wrapper for lua-language-server (installed via LuaRocks/LuaJIT)
exec lua-language-server "$@"
EOF
    chmod +x "$BIN_DIR/lua_ls"
  }
}
NEEDED_TOOLS=(git curl tar make clang cmake ninja bash pkg-config)
MISSING=()
need_tool()
{
  local t=$1
  if command -v "$t" > /dev/null 2>&1; then
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
if [[ -d "$BUILD_DIR/.git" ]]; then
  cd "$BUILD_DIR"
  git fetch --all --tags
else
  git clone https://github.com/neovim/neovim "$BUILD_DIR" --recursive
  cd "$BUILD_DIR"
fi
git switch nightly
rm -rf build .deps
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
  if [[ -d $RUNTIME_DEST ]] && [[ ! -L ${RUNTIME_DEST} ]]; then
    mv "${RUNTIME_DEST}" "${RUNTIME_DEST}.backup-$(date +%s)"
  fi
  [[ -L $RUNTIME_DEST ]] && rm "$RUNTIME_DEST"
  cp -r "$RUNTIME_SRC" "$RUNTIME_DEST"
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
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
    echo "✓ Created $INIT_LUA with runtime setup"
  fi
fi
add_path_line="export PATH=\"$BIN_DIR:\$PATH\""
for rc in "$HOME/.bashrc" "${HOME}/.zshrc" "$HOME/.config/fish/config.fish"; do
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
  cp -v "$PARSER_SRC"/*.so "$PARSER_DEST"/ 2> /dev/null || {
    echo "⚠ No parser files found to copy"
  }
  parser_count=$(find "$PARSER_DEST" -name "*.so" | wc -l)
  echo "✓ Installed $parser_count tree-sitter parsers"
else
  echo "⚠ Parser directory not found: $PARSER_SRC"
  echo "  Install parsers first: nvim -c 'TSInstall all' -c 'q'"
fi
pnpm add -g neovim && pip install --user pynvim && gem install neovim
NVIM_BIN="$BIN_DIR/nvim"
if [[ -x $NVIM_BIN ]]; then
  echo "Neovim → $NVIM_BIN"
  "$NVIM_BIN" --version | sed -n '1,8p'
else
  echo "Error: Neovim not at $NVIM_BIN :(" >&2
  exit 1
fi
echo "Great Success!"
rm -rf "$TMP_DIR"
