#!/usr/bin/env bash
# /qompassai/Diver/lsp/jimmer.sh
# Qompass AI Diver Jimmer Install Script
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
set -euo pipefail
REPO_URL="https://github.com/Enaium/jimmer-dto-lsp.git"
REPO_DIR="${REPO_DIR:-$HOME/.GH/jimmer-dto-lsp}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PREFIX="${PREFIX:-$XDG_DATA_HOME/jimmer-dto-lsp}"
echo "==> Cloning repository to $REPO_DIR"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$REPO_DIR"
fi
echo "==> Building shadow JAR"
cd "$REPO_DIR/server"
../gradlew :server:shadowJar
echo "==> Finding built JAR"
JAR_PATH="$(find build/libs -maxdepth 1 -type f -name 'jimmer-dto-lsp-*-all.jar' -printf '%f\n' 2>/dev/null | sort | tail -n1)"
JAR_PATH="build/libs/$JAR_PATH"
if [ ! -f "$JAR_PATH" ]; then
  echo "No jimmer-dto-lsp *-all.jar found in build/libs" >&2
  exit 1
fi
echo "   Using JAR: $JAR_PATH"
echo "==> Installing to $PREFIX"
mkdir -p "$PREFIX/lib" "$PREFIX/bin"
cp "$JAR_PATH" "$PREFIX/lib/"
JAR_BASENAME="$(basename "$JAR_PATH")"
cat > "$PREFIX/bin/jimmer-dto-lsp" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PREFIX="${PREFIX:-$XDG_DATA_HOME/jimmer-dto-lsp}"
exec java -jar "$PREFIX/lib/JAR_BASENAME_PLACEHOLDER" "$@"
EOF
sed -i "s/JAR_BASENAME_PLACEHOLDER/$JAR_BASENAME/" "$PREFIX/bin/jimmer-dto-lsp"
chmod +x "$PREFIX/bin/jimmer-dto-lsp"
echo
echo "==> Updating shell configuration"
BASHRC="$HOME/.bashrc"
read -r -d '' BASH_SNIPPET << "EOF"
# jimmer-dto-lsp (XDG)
export XDG_DATA_HOME="\${XDG_DATA_HOME:-\$HOME/.local/share}"
export PREFIX="\${PREFIX:-\$XDG_DATA_HOME/jimmer-dto-lsp}"
export PATH="\$PREFIX/bin:\$PATH"
EOF
if [ -f "$BASHRC" ]; then
  if ! grep -q 'jimmer-dto-lsp (XDG)' "$BASHRC"; then
    printf '%s\n' "$BASH_SNIPPET" >> "$BASHRC"
    echo "   Added jimmer-dto-lsp exports to $BASHRC"
  else
    echo "   $BASHRC already has jimmer-dto-lsp exports, skipping"
  fi
else
  printf '%s\n' "$BASH_SNIPPET" >> "$BASHRC"
  echo "   Created $BASHRC and added jimmer-dto-lsp exports"
fi
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
FISH_CONF_DIR="$XDG_CONFIG_HOME/fish/conf.d"
read -r -d '' FISH_SNIPPET << "EOF"
# jimmer-dto-lsp (XDG)
if not set -q XDG_DATA_HOME
    set -gx XDG_DATA_HOME $HOME/.local/share
end
if not set -q PREFIX
    set -gx PREFIX "$XDG_DATA_HOME/jimmer-dto-lsp"
end
if not contains "$PREFIX/bin" $PATH
    set -gx PATH "$PREFIX/bin" $PATH
end
EOF
mkdir -p "$FISH_CONF_DIR"
FISH_FILE="$FISH_CONF_DIR/jimmer.fish"
if [ -f "$FISH_FILE" ]; then
  if ! grep -q 'jimmer-dto-lsp (XDG)' "$FISH_FILE"; then
    printf '%s\n' "$FISH_SNIPPET" >> "$FISH_FILE"
    echo "   Updated $FISH_FILE with jimmer-dto-lsp exports"
  else
    echo "   $FISH_FILE already has jimmer-dto-lsp exports, skipping"
  fi
else
  printf '%s\n' "$FISH_SNIPPET" > "$FISH_FILE"
  echo "   Created $FISH_FILE with jimmer-dto-lsp exports"
fi