-- /qompassai/Diver/lua/types/lang/zig.lua
-- Qompass AI Diver Zig Lang Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta

---@class ZigCmpSource
---@field name string

---@class ZigCmpConfig
---@field sources ZigCmpSource[]
---@field mapping table
---@field snippet table
---@field experimental table


---@class ZigConfig
---@field diagnostics fun(): nil

---@class ZigConfigModule
---@field autocmds nil
---@field zig_tools fun(): table
---@field zig_diagnostics fun(): function
---@field zig_conform fun(opts?: table): table
---@field zig_cmp fun(): table
---@field zig_lamp fun(): table
---@field zig_cfg fun(opts?: table): ZigConfig
---@field zig_vim fun(): nil
