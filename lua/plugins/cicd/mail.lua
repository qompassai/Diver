-- qompassai/Diver/lua/plugins/cicd/mail.lua
-- Qompass AI Diver Mail Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    {
        'martineausimon/nvim-mail-merge',
        config = function()
            require('nvmm').setup({
                mappings = {
                    attachment = '<leader>m',
                    config = '<leader>c',
                    preview = '<leader>p',
                    send_text = '<leader>st',
                    send_html = '<leader>sh'
                },
                options = {
                    mail_client = {text = 'neomutt', html = 'neomutt'},
                    auto_break_md = false,
                    neomutt_config = '$XDG_CONFIG_HOME/neomutt/.neomuttrc',
                    mailx_account = nil,
                    save_log = true,
                    log_file = './nvmm.log',
                    date_format = '%Y-%m-%d',
                    pandoc_metadatas = {
                        [['title= ']], [['margin-top=0']], [['margin-left=0']],
                        [['margin-right=0']], [['margin-bottom=0']],
                        [['mainfont: sans-serif']]
                    }
                }
            })
        end
    }, {
        'lfilho/note2cal.nvim',
        config = function()
            require('note2cal').setup({
                debug = false,
                calendar_name = 'Work',
                highlights = {at_symbol = 'WarningMsg', at_text = 'Number'},
                keymaps = {normal = '<Leader>se', visual = '<Leader>se'}
            })
        end,
    }
}
