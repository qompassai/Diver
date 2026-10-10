#!/usr/bin/env lua

-- /qompassai/Diver/lua/config/lang/sf.lua
-- Qompass AI Salesforce Lang Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

---Language-specific MCP server, declared in the ai.mcp declared_servers
---entry shape. Declarative and inert: not auto-started; enabling belongs
---to the ai.mcp layer. @salesforce/mcp is Salesforce's official DX MCP
---server (repo salesforcecli/mcp, Apache-2.0): ~60 tools across org,
---metadata, data, and testing toolsets over stdio. Auth stays in the sf
---CLI's own store; this entry carries no credentials, and org/toolset
---selection is an enable-time choice. Verified 2026-10-09.
M.mcp_servers = {
    {
        args = { '-y', '@salesforce/mcp' },
        command = 'npx',
        enabled = false,
        name = 'salesforce_dx',
    },
}

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

-- selene: allow(global_usage)
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

return M
