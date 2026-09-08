#!/usr/bin/env bash

# nvim2vsc.sh
# Qompass AI Diver Nvim-2-VScode LSP Converter
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
set -euo pipefail
# Output:
#   <output>/
#     .vscode/settings.json
#     lsp-export/
#       manifest.json
#       <server>.source
#       <server>.vscode.json
#
SRC_DIR="${1:-}"
OUT_DIR="${2:-./vscode}"
if [[ -z $SRC_DIR ]]; then
  echo "usage: $0 /path/to/scripts/lsp [/path/to/output]" >&2
  exit 1
fi
if [[ ! -d $SRC_DIR ]]; then
  echo "error: source directory not found: $SRC_DIR" >&2
  exit 1
fi
mkdir -p "$OUT_DIR/.vscode" "$OUT_DIR"
MANIFEST="$OUT_DIR/manifest.json"
SETTINGS="$OUT_DIR/.vscode/settings.json"
cat > "$SETTINGS" << 'JSON'
{
  "files.associations": {},
  "json.schemaDownload.enable": true,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit"
  },
  "lua.workspace.checkThirdParty": false,
  "lua.telemetry.enable": false,
  "typescript.tsdk": "node_modules/typescript/lib"
}
JSON

python3 - "$SRC_DIR" "$OUT_DIR" "$MANIFEST" "$SETTINGS" << 'PY'
import json, os, re, shutil, sys
from pathlib import Path

src = Path(sys.argv[1]).expanduser().resolve()
out = Path(sys.argv[2]).expanduser().resolve()
manifest_path = Path(sys.argv[3]).expanduser().resolve()
settings_path = Path(sys.argv[4]).expanduser().resolve()

files = []
for p in sorted(src.rglob('*')):
    if p.is_file() and p.suffix in {'.lua', '.json', '.jsonc', '.yaml', '.yml', '.toml'}:
        files.append(p)

settings = json.loads(settings_path.read_text())
manifest = []

COMMON_KEYS = {
    'lua_ls': {
        'settings': {
            'Lua.runtime.version': 'LuaJIT',
            'Lua.telemetry.enable': False,
            'Lua.workspace.checkThirdParty': False,
        }
    },
    'pyright': {
        'settings': {
            'python.analysis.autoImportCompletions': True,
            'python.analysis.typeCheckingMode': 'basic',
        }
    },
    'basedpyright': {
        'settings': {
            'python.analysis.autoImportCompletions': True,
            'python.analysis.typeCheckingMode': 'basic',
        }
    },
    'tsserver': {
        'settings': {
            'typescript.suggest.autoImports': True,
            'javascript.suggest.autoImports': True,
        }
    },
    'jsonls': {
        'settings': {
            'json.format.enable': True,
            'json.validate.enable': True,
        }
    },
    'yamlls': {
        'settings': {
            'yaml.format.enable': True,
            'yaml.validate': True,
            'yaml.schemaStore.enable': True,
        }
    },
    'bashls': {
        'settings': {
            'shellformat.flag': '-i 2'
        }
    },
    'rust_analyzer': {
        'settings': {
            'rust-analyzer.check.command': 'clippy'
        }
    },
    'taplo': {
        'settings': {
            'evenBetterToml.formatter.alignEntries': True,
        }
    },
}

for p in files:
    rel = p.relative_to(src)
    server = p.stem

    source_copy = out / 'lsp-export' / f'{server}.source{p.suffix}'
    source_copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(p, source_copy)

    vscode_stub = {
        'server': server,
        'source': str(rel),
        'recommended_extension': None,
        'settings': {},
        'files': [],
    }
    if server in COMMON_KEYS:
        vscode_stub['settings'].update(COMMON_KEYS[server]['settings'])
    if server in ('lua_ls', 'sumneko_lua'):
        vscode_stub['recommended_extension'] = 'sumneko.lua'
        settings.setdefault('Lua.telemetry.enable', False)
        settings.setdefault('Lua.workspace.checkThirdParty', False)
    elif server in ('jsonls',):
        vscode_stub['recommended_extension'] = 'vscode.json-language-features'
    elif server in ('yamlls',):
        vscode_stub['recommended_extension'] = 'redhat.vscode-yaml'
    elif server in ('pyright', 'basedpyright'):
        vscode_stub['recommended_extension'] = 'ms-python.vscode-pylance'
    elif server in ('tsserver', 'ts_ls'):
        vscode_stub['recommended_extension'] = 'vscode.typescript-language-features'
    elif server in ('rust_analyzer',):
        vscode_stub['recommended_extension'] = 'rust-lang.rust-analyzer'
    elif server in ('bashls',):
        vscode_stub['recommended_extension'] = 'mads-hartmann.bash-ide-vscode'
    elif server in ('taplo',):
        vscode_stub['recommended_extension'] = 'tamasfe.even-better-toml'

    stub_path = out / 'lsp-export' / f'{server}.vscode.json'
    stub_path.write_text(json.dumps(vscode_stub, indent=2) + '\n')

    manifest.append({
        'server': server,
        'source': str(rel),
        'copied_to': str(source_copy.relative_to(out)),
        'stub': str(stub_path.relative_to(out)),
        'recommended_extension': vscode_stub['recommended_extension'],
    })

settings_path.write_text(json.dumps(settings, indent=2) + '\n')
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
PY

echo "done: exported LSP configs to $OUT_DIR"
echo "      vscode settings: $SETTINGS"
echo "      manifest: $MANIFEST"
