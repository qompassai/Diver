#!/bin/bash -ex

go install golang.org/dl/gotip@latest
go install golang.org/x/tools/cmd/godoc@latest
go install github.com/lotusirous/gostdsym/stdsym@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install golang.org/x/tools/gopls@latest
go install mvdan.cc/gofumpt@latest
go install golang.org/x/tools/cmd/deadcode@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/segmentio/golines@latest
go install gotest.tools/gotestsum@latest
#####################################################################
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/nametake/golangci-lint-langserver@latest
go install github.com/bufbuild/buf/cmd/buf@latest
go install github.com/hashicorp/terraform-ls@latest
go install github.com/sqls-server/sqls@latest
go install github.com/hyprland-community/hyprls/cmd/hyprls@latest
go install github.com/kitagry/bqls@latest
go install github.com/arduino/arduino-language-server@latest
go install github.com/wader/jq-lsp@latest
go install github.com/juliosueiras/nomad-lsp@latest
go install github.com/grafana/jsonnet-language-server@latest
go install github.com/a-h/templ/cmd/templ@latest
go install github.com/opa-oz/pug-lsp@latest
go install github.com/sqls-server/sqls@latest
go install github.com/nokia/ntt@latest
go install github.com/kitagry/regols@latest
go install github.com/nobl9/nobl9-language-server/cmd/nobl9-language-server@latest
go install github.com/ptdewey/plantuml-lsp@latest
go install github.com/anz-bank/sysl/cmd/sysl@latest