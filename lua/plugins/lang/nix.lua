-- /qompassai/Diver/lua/plugins/lang/nix.lua
-- Qompass AI Diver Nix Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    {
        'nvim-treesitter/nvim-treesitter',
        opts = function(_, opts)
            opts.ensure_installed = opts.ensure_installed or {}
            vim.list_extend(opts.ensure_installed, {'nix'})
        end
    }, {
        'neovim/nvim-lspconfig',
        ft = 'nix',
        config = function() require('config.lang.nix').nix_lsp() end
    }, {
        'nvimtools/none-ls.nvim',
        ft = 'nix',
        opts = function(_, opts)
            local nls = require('config.lang.nix').nix_nls()
            opts.sources = vim.list_extend(opts.sources or {}, nls)
        end
    }, {
        'stevearc/conform.nvim',
        ft = 'nix',
        opts = function(_, opts)
            local conform = require('config.lang.nix').nix_conform()
            opts.formatters_by_ft = vim.tbl_deep_extend('force',
                                                        opts.formatters_by_ft or
                                                            {},
                                                        conform.formatters_by_ft)
            opts.format_on_save = conform.format_on_save
            opts.format_after_save = conform.format_after_save
        end
    }
}
