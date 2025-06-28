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
    {import = 'plugins.core'}, {import = 'plugins.ai'},
    {import = 'plugins.cloud', event = 'BufReadCmd'},
    {import = 'plugins.data', ft = {'jupyter', 'quarto', 'python', 'r'}},
    {import = 'plugins.edu', cmd = {'VimBeGood', 'Twilight'}},
    {import = 'plugins.cicd'}, {
        import = 'plugins.lang',
        ft = {
            'bash', 'c', 'c_sharp', 'cpp', 'css', 'cuda', 'containerfile',
            'dart', 'dockerfile', 'elixir', 'elm', 'f_sharp', 'go', 'graphql',
            'haskell', 'html', 'java', 'javascript', 'json', 'kotlin', 'latex',
            'lua', 'markdown', 'matlab', 'mojo', 'nim', 'nix', 'perl', 'php',
            'powershell', 'python', 'r', 'ruby', 'rust', 'scala', 'scss', 'sh',
            'solidity', 'sql', 'svelte', 'swift', 'teal', 'toml', 'typescript',
            'typst', 'vhdl', 'visual_basic', 'vue', 'yml', 'yaml', 'zig', 'zsh'
        }
    }, {import = 'plugins.nav'}, {import = 'plugins.ui'}
}
