-- /qompassai/Diver/lua/types/core/plenary.lua
-- Qompass AI Plenary Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta

---@class PlenaryPath
---@field filename string
---@field _absolute boolean
---@field is_dir fun(self: PlenaryPath): boolean
---@field is_file fun(self: PlenaryPath): boolean
---@field read fun(self: PlenaryPath): string
---@field stem fun(self: PlenaryPath): string
---@field make_relative fun(self: PlenaryPath, base: string): string

---@class PlenaryPathClass
---@field new fun(self: PlenaryPathClass, path: string): PlenaryPath

---@type PlenaryPathClass
Path = {}