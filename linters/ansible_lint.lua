-- /qompassai/Diver/linters/ansible_lint.lua
-- Qompass AI Diver Ansible Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local efm = '%f:%l:%c: %m,%f:%l: %m'
return {
    cmd = 'ansible-lint',
    args = {
        '-p',
        '--nocolor',
    },
    ignore_exitcode = true,
    parser = require('lint.parser').from_errorformat(efm, { ---@type string
        source = 'ansible-lint',
        severity = vim.diagnostic.severity.INFO, ---@type string
    }),
}
