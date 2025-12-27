-- /qompassai/Diver/linters/buildifier.lua
-- Qompass AI Diver Buildifier Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local function get_cur_file_type(bufnr)
    bufnr = bufnr or 0
    local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t')
    fname = string.lower(fname)
    if fname == 'module.bazel' then
        return 'module'
    elseif vim.endswith(fname, '.bzl') then
        return 'bzl'
    elseif vim.endswith(fname, '.sky') then
        return 'default'
    elseif fname == 'build' or vim.startswith(fname, 'build.') or vim.endswith(fname, '.build') then
        return 'build'
    elseif fname == 'workspace' or vim.startswith(fname, 'workspace.') or vim.endswith(fname, '.workspace') then
        return 'workspace'
    else
        return 'default'
    end
end
return ---@type vim.lint.Config
{
    cmd = 'buildifier',
    stdin = true,
    append_fname = false,
    args = {
        '-lint',
        'warn',
        '-mode',
        'check',
        '-warnings',
        'all',
        '-format',
        'json',
        '-type',
        get_cur_file_type,
    },
    stream = 'both',
    ignore_exitcode = true,
    env = nil,
    parser = function(output, bufnr)
        local diagnostics = {}
        if output == '' then
            return diagnostics
        end
        local function parse_stdout_json(line)
            local ok, out = pcall(vim.json.decode, line)
            if not ok or type(out) ~= 'table' then
                return
            end
            if out.success == true then
                return
            end
            local f = out.files and out.files[1]
            if not f then
                return
            end
            if f.formatted == false then
                table.insert(diagnostics, {
                    bufnr = bufnr,
                    lnum = 0,
                    col = 0,
                    end_lnum = 0,
                    end_col = 0,
                    severity = vim.diagnostic.severity.HINT,
                    source = 'buildifier',
                    message = 'Please run buildifier to reformat this file.',
                    code = 'reformat',
                })
            end
            if not f.warnings then
                return
            end
            for _, item in ipairs(f.warnings) do
                local sev = vim.diagnostic.severity.INFO
                if item.actionable == true then
                    sev = vim.diagnostic.severity.WARN
                end
                table.insert(diagnostics, {
                    bufnr = bufnr,
                    lnum = (item.start and item.start.line or 1) - 1,
                    col = (item.start and item.start.column or 1) - 1,
                    end_lnum = (item['end'] and item['end'].line or item.start.line or 1) - 1,
                    end_col = (item['end'] and item['end'].column or item.start.column or 1) - 1,
                    severity = sev,
                    source = 'buildifier',
                    message = (item.message or '') .. (item.url and ('\n\n' .. item.url) or ''),
                    code = item.category,
                })
            end
        end
        local function parse_stderr_line(line)
            local parts = vim.split(line, ':')
            local lnum, col, message = 0, 0, ''
            if #parts >= 4 then
                lnum = tonumber(parts[2]) or 1
                col = tonumber(parts[3]) or 1
                message = table.concat(parts, ':', 4)
            elseif #parts == 3 then
                message = parts[3]
            elseif #parts == 2 then
                message = parts[2]
            else
                message = line
            end
            if message ~= '' then
                table.insert(diagnostics, {
                    bufnr = bufnr,
                    lnum = lnum - 1,
                    col = col - 1,
                    end_lnum = lnum - 1,
                    end_col = col,
                    severity = vim.diagnostic.severity.ERROR,
                    source = 'buildifier',
                    message = message:gsub('^%s+', ''),
                    code = 'syntax',
                })
            end
        end
        for _, line in
            ipairs(vim.split(output, '\n', {
                plain = true,
                trimempty = true,
            }))
        do
            if vim.startswith(line, '{') then
                parse_stdout_json(line)
            else
                parse_stderr_line(line)
            end
        end
        return diagnostics
    end,
}
