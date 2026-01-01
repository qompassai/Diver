-- /qompassai/Diver/lsp/mojo_ls.lua
-- Qompass AI Diver Mojo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--ln -s $XDG_DATA_HOME/mojo/.pixi/envs/default/bin/mojo-lsp-server \
--    $HOME/.local/bin/mojo-lsp-server
--ln -s \
--  $XDG_DATA_HOME/mojo/.pixi/envs/default/bin/mojo-lldb-dap \
--  $HOME/.local/bin/mojo-lldb-dap
return ---@type vim.lsp.Config
{
    cmd = {
        'mojo-lsp-server',
        '--log=info',
        '--pretty',
        '--attach-debugger-on-startup',
    },
    filetypes = {
        'mojo',
    },
    root_markers = {
        '.git',
        'pixi.toml',
    },
    settings = {},
}
