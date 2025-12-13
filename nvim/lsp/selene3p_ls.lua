-- /qompassai/Diver/lsp/selene3p_ls.lua
-- Qompass AI Selene 3rd Party LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/antonk52/lua-3p-language-servers
--pnpm add -g lua-3p-language-servers

vim.lsp.config['selene3p_ls'] = {
    cmd = { 'selene-3p-language-server' },
    filetypes = { 'lua' },
    root_markers = { 'selene.toml' },
}

vim.api.nvim_create_user_command('SeleneCheck', function()
    vim.cmd('write')
    vim.fn.jobstart({ 'selene', vim.api.nvim_buf_get_name(0) }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                print(table.concat(data, '\n'))
            end
        end,
        on_stderr = function(_, data)
            if data then
                print(table.concat(data, '\n'))
            end
        end,
    })
end, {})
