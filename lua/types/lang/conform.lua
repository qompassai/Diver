-- /qompassai/Diver/lua/types/lang/conform.lua
-- Qompass AI Diver Conform Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-------------------------------------------------------------------
---@meta

---@class ConformConfig
---@field default_format_opts? table
---@field formatters? table<string, table>
---@field formatters_by_ft? table<string, string[]>
---@field format_on_save? boolean|table
---@field format_after_save? boolean|table
---@field notify_on_error? boolean
---@field notify_no_formatters? boolean
---@field log_level? integer
