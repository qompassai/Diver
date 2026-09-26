-- /qompassai/Diver/lua/ai/media/registry.lua
-- Qompass AI Media Backend Registry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Named registry of media-generation backends (audio/image/video).
-- Detection is runtime probing only: a backend is available when its
-- detect() says so, never by assumption. A detect() that raises is
-- reported as unavailable with the error as its reason, so one broken
-- probe can never take down the picker.

---@class AiMediaGenerateOpts
---@field text? string Input text for audio backends.
---@field prompt? string Generation prompt for image/video backends.
---@field out_path? string Absolute destination file; backend picks a default.
---@field size? string Image size hint, e.g. '1024x1024'.

---@class AiMediaResult
---@field path string Absolute path of the generated file.
---@field bytes integer Size of the generated file in bytes.
---@field backend string Name of the backend that produced it.

---@alias AiMediaCallback fun(err: string|nil, result: AiMediaResult|nil)

---@class AiMediaBackend
---@field kind 'audio'|'image'|'video' Media kind this backend produces.
---@field detect fun(): boolean, string Returns (available, reason).
---@field generate fun(opts: AiMediaGenerateOpts, cb: AiMediaCallback)

---@class AiMediaDetection
---@field name string Registry name of the backend.
---@field kind 'audio'|'image'|'video'
---@field available boolean
---@field reason string Human-readable reason, incl. install hint when false.

local M = {}

---@type table<string, AiMediaBackend>
local backends = {}
---@type string[]
local order = {}

---@param name string Registry name, e.g. 'tts-local'.
---@param backend AiMediaBackend
function M.register(name, backend)
    assert(type(name) == 'string', 'backend name must be a string')
    assert(name ~= '', 'backend name must not be empty')
    assert(type(backend) == 'table', 'backend must be a table')
    assert(
        backend.kind == 'audio' or backend.kind == 'image' or backend.kind == 'video',
        'backend.kind must be audio, image or video'
    )
    assert(type(backend.detect) == 'function', 'backend.detect must be a function')
    assert(type(backend.generate) == 'function', 'backend.generate must be a function')
    assert(backends[name] == nil, 'backend already registered: ' .. name)
    backends[name] = backend
    order[#order + 1] = name
end

---@param name string
---@return AiMediaBackend|nil
function M.get(name)
    assert(type(name) == 'string', 'backend name must be a string')
    return backends[name]
end

---@return string[] names in registration order.
function M.names()
    local names = {}
    for index = 1, #order do
        names[index] = order[index]
    end
    return names
end

-- Runs every backend's detect() and reports truthfully. A raising detect()
-- becomes `available = false` with the error text as the reason.
---@return AiMediaDetection[]
function M.detect_all()
    local detections = {}
    for index = 1, #order do
        local name = order[index]
        local backend = backends[name]
        assert(backend ~= nil, 'registry order out of sync')
        local ok, available, reason = pcall(backend.detect)
        if not ok then
            available, reason = false, 'detect() raised: ' .. tostring(available)
        end
        if type(available) ~= 'boolean' then
            available, reason = false, 'detect() did not return a boolean'
        end
        if type(reason) ~= 'string' or reason == '' then
            reason = 'no reason given'
        end
        detections[#detections + 1] = {
            name = name,
            kind = backend.kind,
            available = available,
            reason = reason,
        }
    end
    return detections
end

return M
