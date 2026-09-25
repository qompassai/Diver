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

        assert(type(setup) == 'function', ('config.lang.md.%s must be a function, got %s'):format(method, type(setup)))

        setup(opts or {})
    end
end

-- NOTE: 3rd/image.nvim was removed from this spec (2026-09-25). Its rockspec
-- build fails (missing luarocks hererocks lua), which made lazy.nvim retry
-- the install every startup. Image rendering is handled natively by
-- config.ui.image (vim.ui.img); see lua/config/ui/image.lua.
-- NOTE: 3rd/diagram.nvim was removed from this spec (2026-09-25). It requires
-- image.nvim (its lua/diagram/hover.lua requires the 'image' module), so it
-- cannot function without it. config.lang.md.md_diagram now degrades
-- gracefully when the plugin is unavailable.
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
    {
        'arminveres/md-pdf.nvim',
        ft = {
            'markdown',
        },
        config = configure('md_pdf'),
    },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = {
            'nvim-tree/nvim-web-devicons',
            'vhyrro/luarocks.nvim',
        },
        ft = {
            'markdown',
            'mdx',
        },
        config = configure('md_rendermd'),
    },
}
