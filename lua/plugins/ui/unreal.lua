-- /qompassai/Diver/lua/plugins/ui/unreal.lua
-- Qompass AI Diver Unreal Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

return {
    {
        'zadirion/Unreal.nvim',
        dependencies = { 'tpope/vim-dispatch' },
        config = function()
            vim.g.UnrealDir = os.getenv('UNREAL_ENGINE_DIR') or '/opt/UnrealEngine'
            local project_name = os.getenv('UNREAL_PROJECT_NAME') or 'MyGame'
            local editor_target = project_name .. 'Editor'
            local build_script = 'Build.sh ' .. editor_target .. ' Linux Development'
            local run_command = './' .. project_name .. '/Binaries/Linux/' .. editor_target
            vim.api.nvim_create_user_command('UnrealBuild', function()
                vim.cmd('Dispatch ' .. build_script)
            end, { desc = 'Build Unreal Project' })
            vim.api.nvim_create_user_command('UnrealRun', function()
                vim.cmd('Dispatch ' .. run_command)
            end, { desc = 'Run Unreal Editor' })
        end,
    },
}
