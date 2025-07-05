-- /qompassai/Diver/lua/types/lang/nix.lua
-- Qompass AI Diver Nix Lang Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta

---@class NixConformConfig
---@field formatters_by_ft table
---@field format_on_save table
---@field format_after_save table

---@class NixLangConfig
---@field nix_conform fun(): NixConformConfig
---@field nix_nls fun(opts?: table): table
---@field nix_lsp fun(opts?: table): table
---@field nix_cfg fun(opts?: table): { conform: NixConformConfig, nls: table, lsp: table }
