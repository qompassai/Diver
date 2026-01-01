-- /qompassai/Diver/lsp/vectorcode_ls.lua
-- Qompass AI VectorCode LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/Davidyz/VectorCode
--pip install "VectorCode[lsp,mcp]"
local vc = require('vectorcode')
vim.keymap.set('n', '<leader>vq', function()
    local results = vc.query('summarise this file', {
        n_query = 5,
    })
    vim.notify(('VectorCode: %d results'):format(#results), vim.log.levels.INFO)
end, {
    desc = 'VectorCode query',
})
local cacher_backend = require('vectorcode.config').get_cacher_backend()
vim.api.nvim_create_autocmd('BufReadPost', {
    callback = function(ev)
        cacher_backend.register_buffer(ev.buf, {
            n_query = 3,
            notify = false,
        })
    end,
})
vim.keymap.set('n', '<leader>vc', function()
    local prompt = cacher_backend.make_prompt_component(0).content
    vim.fn.setreg('+', prompt)
    vim.notify('VectorCode prompt copied to clipboard', vim.log.levels.INFO)
end, {
    desc = 'VectorCode cached prompt',
})
---@type vim.lsp.Config
return {
    cmd = {
        'vectorcode-server',
    },
    root_markers = {
        '.vectorcode',
        '.git',
    },
    settings = {},
}
