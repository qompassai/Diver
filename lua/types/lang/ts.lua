-- ~/.config/nvim/lua/types/lang/ts.lua
-- ------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

---@meta

---@class TSConfig
---@field ts_conform fun(opts?: table): table
---@field ts_lsp fun(opts?: table): table
---@field ts_linter fun(opts?: table): table
---@field ts_formatter fun(opts?: table): table[]
---@field ts_filetype_detection fun(): table
---@field ts_keymaps fun(opts?: table): table
---@field ts_project_commands fun()
---@field ts_root_dir fun(fname: string): string
---@field ts_cfg fun(opts?: table): TSConfig

