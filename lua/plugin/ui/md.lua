-- /qompassai/Diver/lua/plugins/ui/md.lua
-- Qompass AI Markdown Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

---@param method string
---@return fun(plugin: table, opts: table?)
local function configure(method)
        return function(_, opts)
                local md = require('config.lang.md')
                local setup = md[method]

                assert(type(setup) == 'function',
                        ('config.lang.md.%s must be a function, got %s'):format(method, type(setup)))

                setup(opts or {})
        end
end

return {
        {
                'brianhuster/live-preview.nvim',
                cmd = {
                        'LivePreview',
                },
                dependencies = {
                        'ibhagwan/fzf-lua',
                        'vhyrro/luarocks.nvim',
                },
                ft = {
                        'asciidoc',
                        'html',
                        'markdown',
                },
                config = configure('md_livepreview'),
        },
        --[[
    {
        'arminveres/md-pdf.nvim',
        ft = {
            'markdown',
        },
        config = configure('md_pdf'),
    },
    --]]
}
