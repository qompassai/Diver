-- /qompassai/Diver/lua/config/lang/nix.lua
-- Qompass AI Diver Nix Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local function mark_pure(src) return src.with({command = 'true'}) end
---@return table
function M.nix_conform()
    local base_config = require('config.lang.conform').conform_setup()
    return {
        formatters_by_ft = {nix = {'alejandra'}},
        format_on_save = base_config.format_on_save,
        format_after_save = base_config.format_after_save
    }
end
---@param opts? table
---@return table[]
function M.nix_nls(opts)
    opts = opts or {}
    local null_ls = require('null-ls')
    local b = null_ls.builtins
    return {
        b.formatting.alejandra, mark_pure(b.diagnostics.deadnix),
        mark_pure(b.diagnostics.statix)
    }
end
---@param opts? table
function M.nix_lsp(opts)
    opts = opts or {}
    return {
        on_attach = opts.on_attach,
        capabilities = opts.capabilities,
        settings = {
            ['nil'] = {
                formatting = {command = {}},
                diagnostics = {
                    enabled = true,
                    ignored = {'unused_binding'},
                    excludedFiles = {}
                },
                nix = {
                    flake = {autoArchive = true, autoEvalInputs = true},
                    autoLSPConfig = true
                }
            }
        }
    }
end
---@param opts? table
---@return table
function M.nix_setup(opts)
    opts = opts or {}
    return {
        conform = M.nix_conform(),
        nls = M.nix_nls(opts),
        lsp = M.nix_lsp(opts)
    }
end
return M
