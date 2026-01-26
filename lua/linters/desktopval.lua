-- /qompassai/Diver/linters/desktop-file-validate.lua
-- Qompass AI Diver desktop-file-validate Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    name = 'desktop-file-validate',
    cmd = 'desktop-file-validate',
    stdin = false,
    append_fname = true,
    args = {
        --'--no-hints',
        '--warn-kde',
    },
    stream = 'stderr',
    ignore_exitcode = false,
    env = nil,
    ---@param output string
    ---@param bufnr integer
    ---@return vim.lint.Diagnostic[]
    parser = function(output, bufnr)
        ---@type vim.lint.Diagnostic[]
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filename = vim.fs.basename(bufname)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, msg = line:match('^(.-):(%d+):%s*(.+)$')
            if path and lnum and msg then
                lnum = tonumber(lnum) - 1
                local base = vim.fs.basename(path)
                if base == filename or path == bufname then
                    diagnostics[#diagnostics + 1] = {
                        lnum = lnum, ---@type number
                        end_lnum = lnum, ---@type number
                        col = 0,
                        end_col = 1,
                        severity = vim.diagnostic.severity.ERROR,
                        source = 'desktop-file-validate',
                        message = msg,
                    }
                end
            end
        end

        return diagnostics
    end,
}