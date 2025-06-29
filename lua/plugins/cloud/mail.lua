-- /qompassai/Diver/lua/plugins/cloud/mail.lua
-- Qompass AI Diver Mail Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'martineausimon/nvim-mail-merge',
    ft = {'markdown'}, -- optional
    config = function()
        require('nvmm').setup({
            mappings = {
                attachment = '<leader>a',
                config = '<leader>c',
                preview = '<leader>p',
                send_text = '<leader>st',
                send_html = '<leader>sh'
            },
            options = {
                mail_client = {
                    text = 'neomutt', -- or "mailx"
                    html = 'neomutt'
                },
                auto_break_md = true,
                neomutt_config = '$HOME/.neomuttrc',
                mailx_account = nil, -- if you use different accounts in .mailrc
                save_log = true,
                log_file = './nvmm.log',
                date_format = '%Y-%m-%d',
                pandoc_metadatas = { -- syntax with [['metadata']] is important
                    [['title= ']], [['margin-top=0']], [['margin-left=0']],
                    [['margin-right=0']], [['margin-bottom=0']],
                    [['mainfont: sans-serif']]
                }
            }
        })
    end
}
