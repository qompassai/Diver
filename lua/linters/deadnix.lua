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
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr) ---@param output string
        if output == '' then
            return {}
        end
        local ok, decoded_raw = pcall(vim.json.decode, output)
        if not ok or not decoded_raw then
            return {}
        end
        local decoded = decoded_raw ---@type vim.lint.Config.ReportItem[]
        local diagnostics = {}
        for _, item in ipairs(decoded) do
            if item.path and item.line and item.column then
                local bufname = vim.api.nvim_buf_get_name(bufnr)
                if vim.fs.basename(item.path) == vim.fs.basename(bufname) or item.path == bufname then
                    local lnum = (item.line or 1) - 1
                    local col = (item.column or 1) - 1
                    diagnostics[#diagnostics + 1] = {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        severity = vim.diagnostic.severity.WARN,
                        source = 'deadnix',
                        message = item.message or 'dead code detected',
                        code = item.kind,
                    }
                end
            end
        end
        return diagnostics
    end,
}
