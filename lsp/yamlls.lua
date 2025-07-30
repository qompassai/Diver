-- /qompassai/Diver/lsp/yamlls.lua
-- Qompass AI Yamlls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['yamlls'] = {
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yaml', 'yml', 'yaml.docker-compose', 'yaml.gitlab', 'yaml.helm-values' },
    settings = {
        -- https://github.com/redhat-developer/vscode-redhat-telemetry#how-to-disable-telemetry-reporting
        redhat = {
            telemetry = {
                enabled = false
            }
        },
    },
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { "*.yml", "*.yaml" },
        callback = function()
            vim.bo.filetype = "yaml"
        end,
    })
}
