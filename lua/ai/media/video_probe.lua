-- /qompassai/Diver/lua/ai/media/video_probe.lua
-- Qompass AI Video Generation Probe (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- HONEST STUB. There is no wired text-to-video path here. detect() probes
-- for real, verifiable local text-to-video CLIs and reports what it found;
-- generate() ALWAYS refuses, because no generation argv is implemented for
-- any probed tool. ffmpeg is checked too, but it is labelled correctly:
-- an encoder is not a text-to-video generator, so its presence never
-- makes this backend available. The reason strings carry install hints
-- and provider-API pointers so the UI can show the user a way forward.

---@class AiMediaVideoTool
---@field exe string Executable name probed on PATH.
---@field label string What the tool is.
---@field hint string How to get it.

local M = {}

-- Real projects with a genuine text-to-video CLI, verified 2026-09-25:
-- rapid-mlx ships a `rapid-mlx` CLI with video generation; mere.run ships
-- a CLI for local media workflows including video.
---@type AiMediaVideoTool[]
local VIDEO_TOOLS = {
    {
        exe = 'rapid-mlx',
        label = 'Rapid-MLX',
        hint = "pip install 'rapid-mlx[video]' (Apple Silicon; needs 24GB+ unified memory)",
    },
    {
        exe = 'mere',
        label = 'mere.run',
        hint = 'install the mere.run CLI from https://mere.run/releases',
    },
}

---@return string|nil name of a detected tool, nil when none found.
local function find_tool()
    for _, tool in ipairs(VIDEO_TOOLS) do
        if vim.fn.executable(tool.exe) == 1 then
            return tool.exe
        end
    end
    return nil
end

local function ffmpeg_note()
    if vim.fn.executable('ffmpeg') == 1 then
        return 'ffmpeg is installed, but it is an encoder, not a text-to-video generator'
    end
    return 'ffmpeg is not installed either (it still would not generate video from text)'
end

---@return boolean available
---@return string reason
local function detect()
    local found = find_tool()
    local checked = {}
    for _, tool in ipairs(VIDEO_TOOLS) do
        checked[#checked + 1] = tool.exe
    end
    if found then
        -- Found a real tool, but generation is NOT wired for it: saying
        -- "available" would promise a generate() this stub cannot deliver.
        return false,
            found
                .. ' detected, but no generation path is implemented for it; '
                .. 'video generation is not wired yet. Provider APIs (e.g. OpenAI Sora) '
                .. 'or a local model via the tool itself are the current routes.'
    end
    local hints = {}
    for _, tool in ipairs(VIDEO_TOOLS) do
        hints[#hints + 1] = tool.label .. ': ' .. tool.hint
    end
    return false,
        'no local text-to-video backend detected (checked: '
            .. table.concat(checked, ', ')
            .. '). '
            .. ffmpeg_note()
            .. '. '
            .. table.concat(hints, ' | ')
end

---@param opts AiMediaGenerateOpts
---@param cb AiMediaCallback
local function generate(opts, cb)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(cb) == 'function', 'cb must be a function')
    -- This stub never generates. detect() explains why; this is the
    -- backstop so no caller can mistake the probe for a capability.
    local available, reason = detect()
    assert(available == false, 'video stub must never report available')
    cb('video generation is not implemented: ' .. reason, nil)
end

-- Assemble the backend only once all fields exist; a partial literal
-- would trip the strict missing-fields check.
---@type AiMediaBackend
local backend = { kind = 'video', detect = detect, generate = generate }

M.backend = backend

return M
