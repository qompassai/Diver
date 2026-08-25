#!/usr/bin/env lua
-- /qompassai/Diver/after/ftplugin/w3m.lua
-- Qompass AI Diver After Filetype W3m Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
if vim.b.did_ftplugin then
    return
end
vim.b.did_ftplugin = 1
local ok, w3m = pcall(require, 'w3m')
local buf = vim.api.nvim_get_current_buf()
local function bufcmd(name, fn, opts)
    opts = opts or {}
    opts.buffer = buf
    vim.api.nvim_buf_create_user_command(buf, name, fn, opts)
end
if ok and w3m then
    bufcmd('W3mCopyUrl', function()
        w3m.copy_url('*')
    end)
    bufcmd('W3mReload', w3m.reload)
    bufcmd('W3mAddressBar', w3m.edit_address)
    bufcmd('W3mShowTitle', w3m.show_title)
    bufcmd('W3mShowExtenalBrowser', w3m.show_external_browser)
    bufcmd('W3mShowSource', w3m.show_source_and_header)
    bufcmd('W3mShowDump', w3m.show_dump)
    bufcmd('W3mClose', function()
        vim.api.nvim_buf_delete(buf, {
            force = false,
        })
    end)
    bufcmd('W3mSyntaxOff', function()
        w3m.change_syntax(false)
    end)

    bufcmd('W3mSyntaxOn', function()
        w3m.change_syntax(true)
    end)
    bufcmd('W3mSetUserAgent', function(opts)
        w3m.set_user_agent(opts.args)
    end, {
        nargs = 1,
        complete = 'customlist,v:lua.require("w3m").list_user_agents',
    })
else
end