-- /qompassai/Diver/lua/mappings/lintmap.lua
-- Qompass AI Diver Linter Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

function M.setup_lintmap()
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }
    map('n', '<leader>ll', function()
        local ok, lint = pcall(require, 'lint')
        if not ok then
            vim.notify('nvim-lint not available', vim.log.levels.WARN)
            return
        end
        lint.try_lint()
    end, vim.tbl_extend('force', opts, { desc = 'Run linter' }))
    map(
        'n',
        '<leader>lL',
        'md>LintWith ',
        vim.tbl_extend('force', opts, {
            desc = 'Run specific linter',
        })
    )
    map('n', '<leader>li', function()
        local ok, lint = pcall(require, 'lint')
        if not ok then
            vim.notify('nvim-lint not available', vim.log.levels.WARN)
            return
        end
        local ft = vim.bo.filetype
        local linters = lint.linters_by_ft[ft] or {}
        if #linters == 0 then
            vim.notify('No linters configured for filetype: ' .. ft, vim.log.levels.INFO)
        else
            vim.notify('Available linters: ' .. table.concat(linters, ', '), vim.log.levels.INFO)
        end
    end, vim.tbl_extend('force', opts, { desc = 'Show available linters' }))
    map('n', '<leader>lf', function()
        local ok_conform, conform = pcall(require, 'conform')
        if not ok_conform then
            vim.notify('conform.nvim not available', vim.log.levels.WARN)
            return
        end
        local ok_lint, lint = pcall(require, 'lint')
        if not ok_lint then
            vim.notify('nvim-lint not available', vim.log.levels.WARN)
            return
        end
        conform.format({ async = true }, function()
            lint.try_lint()
        end)
    end, vim.tbl_extend('force', opts, { desc = 'Format and lint' }))
    map('n', '<leader>lc', function()
        vim.diagnostic.reset()
    end, vim.tbl_extend('force', opts, { desc = 'Clear diagnostics' }))
end

return M
