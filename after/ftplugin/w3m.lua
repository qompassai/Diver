#!/usr/bin/env lua
-- /qompassai/Diver/after/ftplugin/w3m.lua
-- Qompass AI Diver After Filetype W3m Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
if vim.b.did_ftplugin then
    return
end
vim.b.did_ftplugin = 1
local ok, w3m = pcall(require, 'config.ui.w3m')
local buf = vim.api.nvim_get_current_buf()
local function bufcmd(name, fn, opts)
    opts = opts or {}
    vim.api.nvim_buf_create_user_command(buf, name, fn, opts)
end
if ok and w3m then
    -- Only commands whose backing helper exists are registered: the
    -- module does not implement every helper named here, and passing a
    -- nil callback would raise and abort the whole ftplugin.
    if w3m.copy_url then
        bufcmd('W3mCopyUrl', function()
            w3m.copy_url('*')
        end)
    end
    if w3m.reload then
        bufcmd('W3mReload', w3m.reload)
    end
    if w3m.edit_address then
        bufcmd('W3mAddressBar', w3m.edit_address)
    end
    if w3m.show_title then
        bufcmd('W3mShowTitle', w3m.show_title)
    end
    if w3m.show_external_browser then
        bufcmd('W3mShowExtenalBrowser', w3m.show_external_browser)
    end
    if w3m.show_source_and_header then
        bufcmd('W3mShowSource', w3m.show_source_and_header)
    end
    if w3m.show_dump then
        bufcmd('W3mShowDump', w3m.show_dump)
    end
    bufcmd('W3mClose', function()
        vim.api.nvim_buf_delete(buf, {
            force = false,
        })
    end)
    if w3m.change_syntax then
        bufcmd('W3mSyntaxOff', function()
            w3m.change_syntax(false)
        end)

        bufcmd('W3mSyntaxOn', function()
            w3m.change_syntax(true)
        end)
    end
    bufcmd('W3mSetUserAgent', function(opts)
        w3m.set_user_agent(opts.args)
    end, {
        nargs = 1,
        complete = 'customlist,v:lua.require("config.ui.w3m").list_user_agents',
    })
end
