-- /qompassai/diver/linter/fish.lua
-- Qompass AI Diver Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local efm = '%E%f (%[%^ ]%# %l): %m,%C%p^,%C%.%#'
return ---@type vim.lint.Config
{
    cmd = 'fish',
    args = {
        '--no-execute',
    },
    stdin = false,
    ignore_exitcode = true,
    stream = 'stderr',
    parser = require('lint.parser').from_errorformat(efm, {
        source = 'fish',
        severity = vim.diagnostic.severity.ERROR, ---@type integer
    }),
}
