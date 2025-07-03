-- /qompassai/Diver/lua/types/cmp.lua
-- Qompass AI Diver CMP Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@meta

---@class cmp.SourceConfig
---@field name string
---@field option? table

---@class cmp.ConfigSchema
---@field sources cmp.SourceConfig[]
---@field mapping? table
---@field completion? { keyword_length: number }
---@field window? { documentation: { border: string } }
