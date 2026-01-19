-- qompassai/Diver/lua/config/lang/mojo.lua
-- Qompass AI Diver Mojo Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.lang.mojo'
local M = {}
function M.mojo_filetype()
    local ok, ft = pcall(require, 'filetype')
    if ok then
        ft.add({
            extension = {
                mojo = 'mojo',
            },
            pattern = {
                ['.*%.🔥'] = 'mojo',
            },
        })
    else
        vim.cmd([[
      augroup MojoFiletype
        autocmd BufNewFile,BufRead *.mojo set filetype=mojo
        autocmd BufNewFile,BufRead *.🔥 set filetype=mojo
      augroup END
    ]])
    end
end

function M.mojo_autocmds()
    pcall(vim.api.nvim_create_autocmd, 'FileType', {
        pattern = {
            'mojo',
        },
        callback = function(args)
            if vim.bo[args.buf].filetype ~= 'mojo' then
                return
            end
            vim.opt_local.tabstop = 4
            vim.opt_local.shiftwidth = 4
            vim.opt_local.expandtab = true
            pcall(vim.keymap.set, 'n', '<leader>mr', ':MojoRun<CR>', {
                buffer = args.buf,
                desc = 'Run Mojo file',
            })
            pcall(vim.keymap.set, 'n', '<leader>md', ':MojoDebug<CR>', {
                buffer = args.buf,
                desc = 'Debug Mojo file',
            })
        end,
    })
end

local ok_dap, dap = pcall(require, 'dap')
if ok_dap and dap then
    dap.adapters.mojo_lldb = {
        type = 'executable',
        command = vim.fn.expand('mojo-lldb-dap'),
        name = 'mojo-lldb',
    }
    dap.configurations.mojo = {
        {
            name = 'Debug Mojo file',
            type = 'mojo_lldb',
            request = 'launch',
            program = function()
                return vim.api.nvim_buf_get_name(0)
            end,
            cwd = vim.fn.getcwd(),
            stopOnEntry = false,
        },
    }
end
return M
