-- /qompassai/Diver/linters/actionlint.lua
-- Qompass AI Actionlint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local function get_file_name()
    return vim.api.nvim_buf_get_name(0)
end
return ---@type vim.lint.Config
{
    name = 'actionlint',
    cmd = 'actionlint',
    stdin = true,
    args = {
        '-format',
        '{{json .}}',
        '-stdin-filename',
        get_file_name,
        '-',
    },
    ignore_exitcode = true,

    parser = function(output, _)
        if output == '' then
            return {}
        end
        ---@type table[]
        local decoded = vim.json.decode(output)
        if not decoded then
            return {}
        end
        local diagnostics = {}
        vim.iter(decoded):each(function(item)
            diagnostics[#diagnostics + 1] = { ---@type table[]
                lnum = item.line - 1, ---@type integer
                end_lnum = item.line - 1, ---@type integer
                col = item.column - 1, ---@type integer
                end_col = item.end_column, ---@type integer
                severity = vim.diagnostic.severity.WARN, ---@type integer
                source = 'actionlint: ' .. item.kind, ---@type string
                message = item.message, ---@type string
            }
        end)
        return diagnostics
    end,
}
