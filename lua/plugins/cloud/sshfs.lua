-- /qompassai/Diver/lua/plugins/cloud/sshfs.lua
-- Qompass AI Diver SSHFS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'nosduco/remote-sshfs.nvim',
    dependencies = {'ibhagwan/fzf-lua'},
    config = function()
        require('remote-sshfs').setup(require('config.cloud.sshfs').opts)
        local sshfs = require('remote-sshfs')
        local fzf = require('fzf-lua')
        vim.keymap.set('n', '<leader>ss', function()
            fzf.fzf_exec(sshfs.list_connections(), {
                prompt = 'SSHFS > ',
                actions = {
                    ['default'] = function(selected)
                        if selected[1] then
                            sshfs.connect(selected[1])
                        end
                    end
                }
            })
        end, {desc = '[SSHFS] Connect to remote host'})
    end
}
