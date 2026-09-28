-- /qompassai/Diver/lsp/vectorcode_ls.lua
-- Qompass AI Diver VectorCode LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- VectorCode: code context provider. Requires the vectorcode Neovim plugin.
-- If the plugin is not installed, the keymaps are skipped and only the
-- LSP config is returned.

local function setup_vectorcode_keymaps()
    local ok, vc = pcall(require, 'vectorcode')
    if not ok then
        return
    end
    vim.keymap.set('n', '<leader>vq', function()
        local results = vc.query(
            'summarise this file',
            {
                n_query = 5,
            }
        )
        vim.notify(('VectorCode: %d results'):format(#results), vim.log.levels.INFO)
    end, {
        desc = 'VectorCode query',
    })
    local ok_cfg, vc_config = pcall(require, 'vectorcode.config')
    if not ok_cfg then
        return
    end
    local cacher_backend = vc_config.get_cacher_backend()
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
end

setup_vectorcode_keymaps()

---@type vim.lsp.Config
return {
    cmd = {
        'vectorcode-server',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '.vectorcode',
        '.git',
    },
    settings = {},
}
