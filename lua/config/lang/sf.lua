#!/usr/bin/env lua

-- sf.lua
-- Qompass AI Salesforce Lang Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        'apex',
    },
    callback = function()
        -- foldmethod/foldexpr are window-local: vim.bo[buf] raises E5108
        -- ("'buf' cannot be passed for window-local option") at runtime.
        vim.wo.foldmethod = 'expr'
        vim.wo.foldexpr = 'v:lua.apex_foldexpr()'
    end,
})

_G.apex_foldexpr = function(lnum)
    local line = vim.fn.getline(lnum)
    if line:match('^%s*//%s*#region%b') or line:match('^%s*%(%*%s*#region.*%*%)') then
        return 'a1'
    elseif line:match('^%s*//%s*#endregion%b') or line:match('^%s*%(%*%s*#endregion%s*%*%)') then
        return 's1'
    else
        return '='
    end
end
