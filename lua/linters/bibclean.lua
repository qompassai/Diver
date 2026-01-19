-- /qompassai/Diver/linters/bibclean.lua
-- Qompass AI Diver Bibclean Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'bibclean',
    stdin = false,
    append_fname = true,
    args = {
        '-no-prettyprint',
        '-check-values',
        '-warnings',
        '-no-quiet',
        '-no-file-position',
        -- "-init-file", "bibclean.ini",
        -- "-max-width", "80",
        -- "-scribe",
    },
    stream = 'stderr',
    ignore_exitcode = true,
    env = nil,
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local filename = vim.fs.basename(bufname)
        for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
            local marker, path, lnum, msg = line:match('^(%?%?)%s+(.-)%s+(%d+):%s*(.+)$')
            if marker == '??' and path and lnum and msg then
                lnum = tonumber(lnum) - 1
                local col = 0
                if vim.fs.basename(path) == filename or path == bufname then
                    local severity = msg:match('^[Ee]rror') and vim.diagnostic.severity.ERROR
                        or vim.diagnostic.severity.WARN
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = msg,
                        severity = severity,
                        source = 'bibclean',
                    })
                end
            end
        end
        return diagnostics
    end,
}
