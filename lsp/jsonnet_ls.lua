-- /qompassai/Diver/lsp/jsonnet_ls.lua
-- Qompass AI JSonnet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/grafana/jsonnet-language-server
--  go install github.com/grafana/jsonnet-language-server@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'jsonnet-language-server',
    },
    filetypes = { ---@type string[]
        'jsonnet',
        'libsonnet',
    },
    root_markers = { ---@type string[]
        'jsonnetfile.json',
        '.git',
    },
}
