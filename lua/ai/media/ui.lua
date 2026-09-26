-- /qompassai/Diver/lua/ai/media/ui.lua
-- Qompass AI Media Backend Picker (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The `AiMedia` picker: lists every registered backend grouped by kind
-- with its live availability and reason. Unavailable entries are shown
-- with WHY they are unavailable and the install hint -- the picker never
-- hides a missing tool behind a spinner. Picking an available backend
-- hands off to the caller's per-kind handler; picking an unavailable
-- one shows the reason instead of pretending to work.

local registry = require('ai.media.registry')

local M = {}

local KIND_ORDER = { audio = 1, image = 2, video = 3 }

---@class AiMediaPickHandlers
---@field audio fun(name: string) Called when an available audio backend is picked.
---@field image fun(name: string) Called when an available image backend is picked.
---@field video fun(name: string) Called when an available video backend is picked.

---@param handlers AiMediaPickHandlers
---@param kind_filter? 'audio'|'image'|'video' When set, only that kind is listed.
function M.open(handlers, kind_filter)
    assert(type(handlers) == 'table', 'handlers must be a table')
    assert(type(handlers.audio) == 'function', 'handlers.audio must be a function')
    assert(type(handlers.image) == 'function', 'handlers.image must be a function')
    assert(type(handlers.video) == 'function', 'handlers.video must be a function')
    assert(kind_filter == nil or KIND_ORDER[kind_filter] ~= nil, 'kind_filter must be audio, image, video or nil')
    local detections = registry.detect_all()
    ---@type AiMediaDetection[]
    local shown = {}
    for _, detection in ipairs(detections) do
        if kind_filter == nil or detection.kind == kind_filter then
            shown[#shown + 1] = detection
        end
    end
    table.sort(shown, function(a, b)
        if a.kind ~= b.kind then
            return KIND_ORDER[a.kind] < KIND_ORDER[b.kind]
        end
        return a.name < b.name
    end)
    if #shown == 0 then
        vim.notify('no media backends registered', vim.log.levels.WARN, { title = 'AI media' })
        return
    end
    local function label(detection)
        local state = detection.available and 'available' or 'UNAVAILABLE'
        return string.format('[%s] %s: %s -- %s', detection.kind, detection.name, state, detection.reason)
    end
    vim.ui.select(shown, {
        prompt = 'AI media backend',
        format_item = label,
    }, function(choice)
        if choice == nil then
            return
        end
        if not choice.available then
            local message = choice.name .. ' is unavailable: ' .. choice.reason
            vim.notify(message, vim.log.levels.WARN, { title = 'AI media' })
            return
        end
        local handler = handlers[choice.kind]
        assert(type(handler) == 'function', 'missing handler for kind ' .. choice.kind)
        handler(choice.name)
    end)
end

return M
