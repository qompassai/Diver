-- /qompassai/Diver/lua/linters/dscanner.lua
-- Qompass AI Diver DScanner Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/dlang-community/D-Scanner
---
--- D-Scanner's style check (-S) with the machine-parsable error
--- format pinned explicitly, per upstream's tooling-integration
--- docs: -f '{filepath}({line}:{column})[{type}]: {message}'.
--- The parser below consumes exactly that shape; nothing is
--- guessed from localized output. dscanner exits non-zero on
--- tool errors only in some modes, so the exit code is ignored
--- and diagnostics come from stdout alone. When the dscanner
--- binary is absent the linter is simply unavailable (nvim-lint
--- semantics); serve-d also embeds D-Scanner checks, but through
--- the LSP, not this module.
return ---@type vim.lint.Config
{
    cmd = 'dscanner',
    stdin = false,
    append_fname = true,
    args = {
        '-S',
        '-f',
        '{filepath}({line}:{column})[{type}]: {message}',
    },
    stream = 'stdout',
    ignore_exitcode = true,
    env = nil,
    ---@type LintBufferParser
    ---@param output string
    ---@param bufnr integer
    ---@return vim.Diagnostic.Set[]
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local path, lnum, col, kind, msg = line:match('^(.-)%((%d+):(%d+)%)%[(.-)%]:%s*(.+)$')
            if path and lnum and col and kind and msg then
                if path == bufname or vim.fs.basename(path) == vim.fs.basename(bufname) then
                    local severity = kind == 'error' and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN
                    table.insert(diagnostics, {
                        lnum = tonumber(lnum) - 1,
                        end_lnum = tonumber(lnum) - 1,
                        col = tonumber(col) - 1,
                        end_col = tonumber(col),
                        message = msg,
                        severity = severity,
                        source = 'dscanner',
                        code = kind,
                    })
                end
            end
        end
        return diagnostics
    end,
}
