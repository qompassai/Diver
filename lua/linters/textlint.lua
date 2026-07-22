-- #################################################################
-- /qompassai/lua/linters/textlint.lua
-- Qompass AI Textlint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'textlint',
        cmd = 'textlint',
        stdin = false,
        append_fname = true,
        args = function()
                return {
                        '--format',
                        'json',
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
                for _, item in ipairs(decoded) do
                        local line = (item.location and item.location.start and item.location.start.line) or item.line or 1
                        local col = (item.location and item.location.start and item.location.start.column) or item.column or 1
                        local severity = vim.diagnostic.severity.WARN

                        if item.severity == 2 or item.severity == 'error' then
                                severity = vim.diagnostic.severity.ERROR
                        elseif item.severity == 1 or item.severity == 'warning' then
                                severity = vim.diagnostic.severity.WARN
                        end

                        diagnostics[#diagnostics + 1] = {
                                lnum = math.max(line - 1, 0),
                                col = math.max(col - 1, 0),
                                end_lnum = math.max(line - 1, 0),
                                end_col = math.max(col, 0),
                                severity = severity,
                                source = 'textlint',
                                code = item.ruleId or item.ruleName or nil,
                                message = item.message or item.ruleId or 'textlint diagnostic',
                        }
                end

                return diagnostics
        end,
} --[[@as vim.lint.Config]]