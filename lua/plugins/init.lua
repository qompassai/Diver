-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------
if vim.fn.has('nvim-0.9.0') == 0 then
    vim.api.nvim_echo({
        {'Diver requires Neovim >= 0.9.0\n', 'ErrorMsg'},
        {'Press any key to exit', 'MoreMsg'}
    }, true, {})
    vim.fn.getchar()
    vim.cmd([[quit]])
    return {}
end
return {
    {import = 'plugins.core'}, {import = 'plugins.ai'}, {
        {import = 'plugins.cloud'}, {import = 'plugins.data'},
        {import = 'plugins.edu'}, {import = 'plugins.cicd'},
        {import = 'plugins.lang'}, {import = 'plugins.nav'},
        {import = 'plugins.ui'}
    }
}
