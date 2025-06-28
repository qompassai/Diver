-- /qompassai/Diver/lua/plugins/ai/unreal.lua
-- Qompass AI Diver Unreal Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    {
        'zadirion/Unreal.nvim',
        dependencies = {'tpope/vim-dispatch'},
        config = function()
            vim.g.UnrealDir =
                '/home/phaedrus/Games/epic-games-store/drive_c/Program Files/Epic Games/UE_5.5.1/'
        end,
        vim.api.nvim_create_user_command('UnrealBuild', function()
            vim.cmd('Dispatch Build.sh MyGameEditor Linux Development')
        end, {desc = 'Build Unreal Project'}),
        vim.api.nvim_create_user_command('UnrealRun', function()
            vim.cmd('Dispatch ./MyGame/Binaries/Linux/MyGameEditor')
        end, {desc = 'Run Unreal Editor'})
    }
}
