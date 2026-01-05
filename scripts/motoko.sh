#!/usr/bin/env bash
# /qompassai/Diver/scripts/motoko.sh
# Qompass AI Motoko Helper Script
# Copyright (C) 2026 Qompass AI, All rights reserved
####################################################
mkdir -p "$XDG_DATA_HOME/motoko-lsp"
cd ||"$XDG_DATA_HOME/motoko-lsp"
curl -L -o motoko.vsix \
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/dfinity-foundation/vsextensions/vscode-motoko/0.18.7/vspackage"
bsdtar -xf motoko.vsix -s'|^|motoko-vscode/|'
cat > "$HOME/.local/bin/motoko-lsp" <<'EOF'
#!/usr/bin/env bash
ROOT="$XDG_DATA_HOME/motoko-lsp/motoko-vscode/extension/out"
exec node "$ROOT/server.js"
EOF
chmod +x "$HOME/.local/bin/motoko-lsp"