#!/usr/bin/env bash
# /qompassai/diver/scripts/vs.sh
# Qompass AI VS Extension Extracter Script
# Copyright (C) 2025 Qompass AI, All rights reserved
# ----------------------------------------
extensionId="RiversideSoftware.openedge-abl-lsp"
publisher="RiversideSoftware"
name="openedge-abl-lsp"
curl -L \
  "https://$publisher.gallery.vsassets.io/_apis/public/gallery/publisher/$publisher/extension/$name/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage" \
  -o "$name.vsix"
mkdir -p $'{XDG_DATA_HOME}'/openedge-abl-lsp
bsdtar -xf openedge-abl-lsp.vsix -C $'{XDG_DATA_HOME}'/openedge-abl-lsp
mkdir -p "${HOME}"/.local/bin
cat > "${HOME}"/.local/bin/openedge-abl-ls << 'EOF'
#!/usr/bin/env bash
JAVACMD="$XDG_DATA_HOME/openedge-abl-lsp/jre/bin/java"
JAR="$XDG_DATA_HOME/openedge-abl-lsp/resources/abl-lsp.jar"
exec "$JAVACMD" \
  -Dorg.slf4j.simpleLogger.showLogName=false \
  -Dorg.slf4j.simpleLogger.defaultLogLevel=INFO \
  -jar "$JAR"
EOF
chmod +x "${HOME}"/.local/bin/openedge-abl-ls