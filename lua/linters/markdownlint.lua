-- #################################################################
-- /qompassai/lua/linters/markdownlint.lua
-- Qompass AI Markdownlint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'markdownlint',
        cmd = 'markdownlint',
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
                        local line = item.lineNumber or item.line or 1
                        local col = item.ruleInformation and item.ruleInformation.column or 1
                        table.insert(diagnostics, {
                                lnum = math.max(line - 1, 0),
                                col = math.max(col - 1, 0),
                                end_lnum = math.max(line - 1, 0),
                                end_col = math.max(col, 0),
                                severity = vim.diagnostic.severity.WARN,
                                source = 'markdownlint',
                                code = item.ruleNames and item.ruleNames[1] or 'markdownlint',
                                message = item.errorDetail or item.ruleDescription or item.errorContext or item.ruleNames and table.concat(item.ruleNames, '/'),
                        })
                end

                return diagnostics
        end,
} --[[@as vim.lint.Config]]