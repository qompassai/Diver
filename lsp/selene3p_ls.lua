-- /qompassai/Diver/lsp/selene3p_ls.lua
-- Qompass AI Selene 3rd Party LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://github.com/antonk52/lua-3p-language-servers

return ---@type vim.lsp.Config
    {
    cmd = {
        'selene-3p-language-server',
    },
    filetypes = {
        'lua',
    },
    root_markers = {
        'selene.toml',
    },
    settings = {
        selene = {
            config = {
                empty_if = {
                    comment_count = true,
                },
            },
            rules = {
                almost_swapped = 'warn',
                divide_by_zero = 'deny',
                duplicate_keys = 'deny',
                empty_if = 'warn',
                empty_loop = 'warn',
                high_cyclomatic_complexity = 'warn',
                ifs_same_cond = 'warn',
                if_same_then_else = 'warn',
                mixed_table = 'allow',
                multiple_statements = 'warn',
                parenthese_conditions = 'warn',
                shadowing = 'warn',
                unbalanced_assignments = 'deny',
                undefined_variable = 'deny',
                unused_variable = 'warn',
            },
            std = 'luajit',
        },
    },
},
    vim.api.nvim_create_user_command('SeleneCheck', function()
        vim.cmd('write') ---@type string[]
        vim.fn.jobstart({ 'selene', vim.api.nvim_buf_get_name(0) }, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data) ---@param data string[]|nil
                if data then
                    print(table.concat(data, '\n'))
                end
            end,
            on_stderr = function(_, data) ---@param data string[]|nil
                if data then
                    print(table.concat(data, '\n'))
                end
            end,
        })
    end, {})
