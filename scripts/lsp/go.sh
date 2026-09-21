#!/usr/bin/env bash
set -euo pipefail

if ! command -v go >/dev/null 2>&1; then
  printf '%s\n' 'error: Go is not installed or not on PATH.' >&2
  exit 1
fi

host_goos="$(go env GOOS)"
host_goarch="$(go env GOARCH)"

case "${host_goos}/${host_goarch}" in
  linux/amd64 | linux/arm64 | android/arm64)
    ;;
  *)
    printf 'warning: untested target: %s/%s\n' "$host_goos" "$host_goarch" >&2
    ;;
esac

export GOBIN="${XDG_BIN_HOME:-$HOME/.local/bin}"
export GOCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go-build"
export GOMODCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go-mod"
export GOPROXY='https://proxy.golang.org,direct'
export GOSUMDB='sum.golang.org'
export PATH="$GOBIN:$PATH"

mkdir -p "$GOBIN" "$GOCACHE" "$GOMODCACHE"

printf 'Host target: %s/%s\n' "$host_goos" "$host_goarch"
printf 'Termux: %s\n' "${TERMUX_VERSION:-no}"
go env GOBIN GOCACHE GOMODCACHE GOPROXY GOSUMDB
du -sh "$GOCACHE" "$GOMODCACHE"

tools=(
  'github.com/a-h/templ/cmd/templ@latest'
  'github.com/anz-bank/sysl/cmd/sysl@latest'
  'github.com/arduino/arduino-language-server@latest'
  'github.com/bufbuild/buf/cmd/buf@latest'
  'github.com/docker/docker-language-server/cmd/docker-language-server@latest'
  'github.com/go-delve/delve/cmd/dlv@latest'
  'github.com/golangci/golangci-lint/cmd/golangci-lint@latest'
  'github.com/grafana/jsonnet-language-server@latest'
  'github.com/hashicorp/terraform-ls@latest'
  'github.com/huderlem/poryscript-pls@latest'
  'github.com/hyprland-community/hyprls/cmd/hyprls@latest'
  'github.com/juliosueiras/nomad-lsp@latest'
  'github.com/kitagry/bqls@latest'
  'github.com/kitagry/regols@latest'
  'github.com/laravel-ls/laravel-ls/cmd/laravel-ls@latest'
  'github.com/lotusirous/gostdsym/stdsym@latest'
  'github.com/nametake/golangci-lint-langserver@latest'
  'github.com/nobl9/nobl9-language-server/cmd/nobl9-language-server@latest'
  'github.com/nokia/ntt@latest'
  'github.com/Open-MBEE/OpenSysML/cmd/sysml-lsp@latest'
  'github.com/opa-oz/pug-lsp@latest'
  'github.com/opentofu/tofu-ls@latest'
  'github.com/ptdewey/plantuml-lsp@latest'
  'github.com/segmentio/golines@latest'
  'github.com/sqls-server/sqls@latest'
  'github.com/wader/jq-lsp@latest'
  'golang.org/dl/gotip@latest'
  'golang.org/x/tools/cmd/deadcode@latest'
  'golang.org/x/tools/cmd/godoc@latest'
  'golang.org/x/tools/gopls@latest'
  'gotest.tools/gotestsum@latest'
  'mvdan.cc/gofumpt@latest'
)

failed=()

install_go_tool() {
  local package="$1"

  printf '\n==> Installing %s\n' "$package"

  if go install "$package"; then
    printf '    installed\n'
  else
    printf '    failed: %s\n' "$package" >&2
    failed+=("$package")
  fi
}

for tool in "${tools[@]}"; do
  install_go_tool "$tool"
done

printf '\nInstalled binaries directory: %s\n' "$GOBIN"

if ((${#failed[@]} > 0)); then
  printf '\nThe following tools failed for %s/%s:\n' "$host_goos" "$host_goarch" >&2

  for tool in "${failed[@]}"; do
    printf '  - %s\n' "$tool" >&2
  done

  exit 1
fi

printf '\nAll Go tools installed successfully.\n'