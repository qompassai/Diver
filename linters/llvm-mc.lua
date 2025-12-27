-- /qompassai/Diver/linters/llvm_mc.lua
-- Qompass AI Diver LLVM-MC Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lint.Config
{
    cmd = 'llvm-mc',
    stdin = false,
    append_fname = true,
    args = {
        '--arch=x86_64',
        '--filetype=null',
        '--no-exec-stack',
        '--position-independent',
        '--show-encoding',
        '--show-inst-operands',
        '--validate-cfi',
        -- "--triple=x86_64-unknown-linux-gnu",
        -- "-g", "--preserve-comments", "--print-imm-hex",
    },
    stream = nil,
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
            local path, lnum, col, kind, msg = line:match('^(.-):(%d+):(%d+):%s*(%w+):%s*(.+)$')
            if path and lnum and msg then
                lnum = tonumber(lnum) - 1
                col = tonumber(col or 1) - 1
                if vim.fs.basename(path) == filename or path == bufname then
                    local sev
                    if kind == 'error' then
                        sev = vim.diagnostic.severity.ERROR
                    elseif kind == 'warning' then
                        sev = vim.diagnostic.severity.WARN
                    else
                        sev = vim.diagnostic.severity.INFO
                    end
                    table.insert(diagnostics, {
                        lnum = lnum,
                        end_lnum = lnum,
                        col = col,
                        end_col = col + 1,
                        message = msg,
                        severity = sev,
                        source = 'llvm-mc',
                    })
                end
            end
        end
        return diagnostics
    end,
}
