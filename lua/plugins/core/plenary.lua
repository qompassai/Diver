-- /qompassai/Diver/lua/plugins/core/plenary.lua
-- -- Qompass AI Diver Plenary
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    {
        'nvim-lua/plenary.nvim',
				lazy = false,
        config = function()
            vim.api.nvim_create_autocmd('BufWritePre', {
                pattern = {'*.sh', '*.bash', '*.zsh'},
                callback = function() vim.lsp.buf.format() end
            })
        end
    }
}
