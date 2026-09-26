--- TypeScript language config — settings for editing TypeScript/JavaScript.
---
--- Plain-language version: when you open a TypeScript or JavaScript file, this module applies the project's
--- TypeScript settings. It runs on TS/JS filetypes.
---@module 'config.lang.ts'
-- qompassai/Diver/lua/config/lang/ts.lua
-- Qompass AI Diver Typescript Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
-- A2A SDK: <LocalLeader>aa* maps (card/send/stream/get/cancel/install)
-- are wired for this filetype by ai.a2a.sdks.setup().
---Build the TypeScript language configuration table.
---@param _opts? table unused option overrides
---@return table cfg the TypeScript config table
function M.ts_cfg(_opts)
    return {}
end

return M
