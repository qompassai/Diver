-- /qompassai/Diver/linters/deadnix.lua
-- Qompass AI Deadnix Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--local core_parser = require('config.core.parser')
return ---@type vim.lint.Config
{
    cmd = 'deadnix',
    stdin = false,
    append_fname = true,
    args = {
        '--output-format',
        'json',
        '--warn-used-underscore',
        '--fail',
    },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output, bufnr)
        if output == '' then
            return {}
        end
        local ok, decoded = pcall(vim.json.decode, output)
        if not ok or not decoded then
            return {}
        end
        local diagnostics = {}
        for _, item in ipairs(decoded) do
            if not item.path or not item.line or not item.column then
                goto continue
            end
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            if vim.fs.basename(item.path) ~= vim.fs.basename(bufname) and item.path ~= bufname then
                goto continue
            end
            local lnum = (item.line or 1) - 1
            local col = (item.column or 1) - 1
            diagnostics[#diagnostics + 1] = { ---@type vim.lint.Diagnostic
                lnum = lnum,
                end_lnum = lnum,
                col = col,
                end_col = col + 1,
                severity = vim.diagnostic.severity.WARN,
                source = 'deadnix',
                message = item.message or 'dead code detected',
                code = item.kind,
            }
            ::continue::
        end
        return diagnostics
    end,
}
