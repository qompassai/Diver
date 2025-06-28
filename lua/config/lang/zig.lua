-- /Diver/lua/config/lang/zig.lua
-- Qompass AI Diver Zig Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------
---@module 'config.lang.zig'
---@class ZigConfigModule
---@field zig_lsp fun(): table
---@field zig_tools fun(): table
---@field zig_diagnostics fun(): function
---@field setup_zig fun(opts?: table): ZigConfig
local M = {}
---@return table
function M.zig_lsp()
    local function find_executable(names)
        return vim.iter(names):map(function(name)
            return vim.fs.find(name, {
                path = table.concat({
                    vim.env.HOME .. '/.local/bin',
                    vim.fn.stdpath('data') .. '/mason/bin', vim.env.PATH
                }, ':')
            })[1]
        end):next()
    end
    local zls_path = find_executable({'zls'}) or 'zls'
    local zig_path = find_executable({'zig'}) or 'zig'
    local zlint_path = find_executable({'zlint'}) or 'zlint'
    return {
        cmd = {zls_path},
        settings = {
            zls = {
                enable_ast_check_diagnostics = true,
                enable_build_on_save = true,
                zig_exe_path = zig_path,
                enable_inlay_hints = true,
                inlay_hints = {
                    parameter_names = true,
                    variable_names = false,
                    builtin = true,
                    type_names = true
                }
            }
        },
        zlint_path = zlint_path
    }
end
---@return table
function M.zig_tools()
    return {
        build_dir = 'zig-out',
        on_attach = function(_, bufnr)
            vim.keymap.set('n', '<leader>zih', function()
                vim.lsp.inlay_hint.enable(bufnr, not vim.lsp.inlay_hint
                                              .is_enabled(bufnr))
            end, {buffer = bufnr, desc = 'Toggle inlay hints'})
        end
    }
end
---@return function
function M.zig_diagnostics()
    return function(ctx)
        local config = M.zig_lsp()
        local output = vim.fn.systemlist(
                           config.zlint_path .. ' --format github ' ..
                               vim.fn.shellescape(ctx.file))
        local diagnostics = {}
        for _, line in ipairs(output) do
            local line_num, col_num, code, msg = line:match(
                                                     ':(%d+):(%d+): (%S+): (.*)')
            if line_num then
                table.insert(diagnostics, {
                    lnum = tonumber(line_num) - 1,
                    col = tonumber(col_num) - 1,
                    message = string.format('[%s] %s', code, msg),
                    severity = vim.diagnostic.severity.WARN,
                    source = 'zlint'
                })
            end
        end
        vim.diagnostic.set(0, diagnostics)
    end
end
---@class ZigConfig
---@field lsp table
---@field tools table
---@field diagnostics function
---@param opts? table
---@return ZigConfig
function M.setup_zig(opts)
    opts = opts or {}
    local lsp_config = M.zig_lsp()
    vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = {'*.zig', '*.zon'},
        callback = M.zig_diagnostics()
    })
    return {
        lsp = lsp_config,
        tools = M.zig_tools(),
        diagnostics = M.zig_diagnostics
    }
end
return M
