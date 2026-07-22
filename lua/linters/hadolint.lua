-- #################################################################
-- /qompassai/lua/linters/hadolint.lua
-- Qompass AI Hadolint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'hadolint',
        cmd = 'hadolint',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '--format',
                        'json',
                        '-',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        parser = function(output, bufnr)
                local ok, decoded = pcall(vim.json.decode, output)
                if not ok or type(decoded) ~= 'table' then
                        return {}
                end

                local diagnostics = {}
                local filename = vim.api.nvim_buf_get_name(bufnr)

                for _, item in ipairs(decoded) do
                        local severity = vim.diagnostic.severity.WARN
                        if item.level == 'error' then
                                severity = vim.diagnostic.severity.ERROR
                        elseif item.level == 'info' or item.level == 'style' then
                                severity = vim.diagnostic.severity.INFO
                        end

                        if not item.file or item.file == '-' or item.file == filename then
                                table.insert(diagnostics, {
                                        lnum = math.max((item.line or 1) - 1, 0),
                                        col = math.max((item.column or 1) - 1, 0),
                                        end_lnum = math.max((item.line or 1) - 1, 0),
                                        end_col = math.max((item.column or 1), 0),
                                        severity = severity,
                                        source = 'hadolint',
                                        code = item.code,
                                        message = string.format('[%s] %s', item.code or 'hadolint', item.message or ''),
                                })
                        end
                end

                return diagnostics
        end,
} --[[@as vim.lint.Config]]