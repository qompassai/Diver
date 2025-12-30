-- /qompassai/Diver/linters/yara.lua
-- Qompass AI Diver YARA Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'yara',
    stdin = false,
    append_fname = true,
    args = {},
    stream = nil,
    ignore_exitcode = false,
    env = nil,
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        for line in
            vim.gsplit(output, '\n', {
                plain = true,
                trimempty = true,
            })
        do
            local rule, path = line:match('^(%S+)%s+(.+)$')
            if rule and path then
                if vim.fs.basename(path) == filename or path == bufname then
                    table.insert(diagnostics, {
                        lnum = 0,
                        end_lnum = 0,
                        col = 0,
                        end_col = 1,
                        message = 'YARA rule matched: ' .. rule,
                        severity = vim.diagnostic.severity.WARN,
                        source = 'yara',
                    })
                end
            end
        end
        return diagnostics
    end,
}
