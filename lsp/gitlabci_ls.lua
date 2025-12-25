-- /qompassai/Diver/lsp/gitlabci_ls.lua
-- Qompass AI Gitlab Continuous Integration (CI) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/alesbrelih/gitlab-ci-ls
-- cargo install gitlab-ci-ls
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'gitlab-ci-ls',
    },
    filetypes = { ---@type string[]
        'yaml.gitlab',
    },
    init_options = {
        cache_path = (vim.env.XDG_CACHE_HOME or (vim.env.HOME .. '/.cache')) .. '/gitlab-ci-ls', ---@type string
        log_path = ((vim.env.XDG_CACHE_HOME or (vim.env.HOME .. '/.cache')) .. '/gitlab-ci-ls') ---@type string
            .. '/log/gitlab-ci-ls.log',
    },
    root_markers = { ---@type string[]
        '.git',
        '.gitlab-ci.yml',
        '.gitlab-ci.yaml',
    },
}
