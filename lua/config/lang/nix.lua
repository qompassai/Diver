-- /qompassai/Diver/lua/config/lang/nix.lua
-- Qompass AI Diver Nix Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
---@module 'config.lang.nix'
local M = {}
---@param opts? table
function M.nix_autocmds(opts) ---@return nil|string[]
    opts = opts or {}
    vim.api.nvim_create_user_command('SetNixFormatter', function(args)
        vim.g.nix_formatter = args.args
    end, {
        nargs = 1,
        complete = function()
            return {
                'alejandra',
                'nixfmt',
                'nixpkgs-fmt',
            }
        end,
    })
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'nix',
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
        vim.opt_local.conceallevel = 2
    end,
})

---@param opts? table
function M.nix_cfg(opts)
    opts = opts
end

return M
