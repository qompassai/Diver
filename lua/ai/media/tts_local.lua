-- /qompassai/Diver/lua/ai/media/tts_local.lua
-- Qompass AI Local Text-to-Speech Backend (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- REAL implementation: probes for actually-installed local TTS engines
-- in preference order (espeak-ng, piper, say on macOS) and shells out to
-- the first one that can write an audio file, argv form only. spd-say is
-- probed for honesty but cannot write audio files, so it never counts as
-- available: the reason says exactly that. Nothing is downloaded; piper
-- needs a voice model (.onnx) already on disk.

---@class AiMediaTtsEngine
---@field id string Engine id, e.g. 'espeak-ng'.
---@field label string Display label.
---@field stdin_text boolean True when the engine reads the text on stdin.
---@field detect fun(): boolean, string, string|nil Returns (ok, reason, extra).
---@field argv fun(text: string, out: string, extra: string|nil): string[]

local M = {}

local TEXT_CHARS_MAX = 4096
local GENERATE_TIMEOUT_MS = 120000
local WAV_HEADER_BYTES = 44
local MODEL_GLOB_MAX = 32

local function executable(name)
    return vim.fn.executable(name) == 1
end

-- Finds the first .onnx voice model under the conventional piper
-- directories. Returns nil when piper has no voice to speak with.
---@return string|nil
local function find_piper_model()
    local data_home = vim.env.XDG_DATA_HOME
    if type(data_home) ~= 'string' or data_home == '' then
        data_home = vim.fn.expand('~/.local/share')
    end
    local dirs = {
        data_home .. '/piper',
        data_home .. '/piper-voices',
        '/usr/share/piper-voices',
    }
    for _, dir in ipairs(dirs) do
        local matches = vim.fn.glob(dir .. '/*.onnx', false, true)
        if type(matches) == 'table' then
            local limit = math.min(#matches, MODEL_GLOB_MAX)
            for index = 1, limit do
                local candidate = matches[index]
                if type(candidate) == 'string' and candidate ~= '' then
                    return candidate
                end
            end
        end
    end
    return nil
end

local function is_darwin()
    local uname = vim.uv.os_uname()
    return type(uname) == 'table' and uname.sysname == 'Darwin'
end

---@type AiMediaTtsEngine[]
local engines = {
    {
        id = 'espeak-ng',
        label = 'espeak-ng',
        stdin_text = false,
        detect = function()
            if not executable('espeak-ng') then
                return false, 'espeak-ng not installed (apt install espeak-ng)'
            end
            return true, 'espeak-ng found on PATH'
        end,
        argv = function(text, out)
            return { 'espeak-ng', '-w', out, text }
        end,
    },
    {
        id = 'piper',
        label = 'piper',
        stdin_text = true,
        detect = function()
            if not executable('piper') then
                return false, 'piper not installed (see https://github.com/OHF-Voice/piper1-gpl/releases)'
            end
            local model = find_piper_model()
            if not model then
                return false, 'piper found but no .onnx voice model on disk; download one first'
            end
            return true, 'piper found with voice model', model
        end,
        argv = function(_, out, model)
            -- piper reads the text on stdin; it has no --input flag.
            assert(type(model) == 'string', 'piper needs a voice model path')
            return { 'piper', '--model', model, '--output_file', out }
        end,
    },
    {
        id = 'say',
        label = 'say (macOS)',
        stdin_text = false,
        detect = function()
            if not is_darwin() then
                return false, 'say is macOS-only'
            end
            if not executable('say') then
                return false, 'say not found on this Mac'
            end
            return true, 'say found (macOS built-in)'
        end,
        argv = function(text, out)
            return { 'say', '-o', out, text }
        end,
    },
    {
        id = 'spd-say',
        label = 'spd-say',
        stdin_text = false,
        detect = function()
            -- Probed for honesty only: spd-say speaks through
            -- speech-dispatcher and cannot write an audio file, so it
            -- never satisfies a file-generating backend.
            if not executable('spd-say') then
                return false, 'spd-say not installed'
            end
            return false, 'spd-say found but cannot write audio files (speech-dispatcher only)'
        end,
        argv = function()
            error('spd-say cannot generate audio files')
        end,
    },
}

---@return AiMediaTtsEngine|nil, string, string|nil
local function pick_engine()
    local reasons = {}
    for _, engine in ipairs(engines) do
        local ok, reason, extra = engine.detect()
        if ok then
            return engine, reason, extra
        end
        reasons[#reasons + 1] = engine.id .. ': ' .. reason
    end
    return nil, 'no local TTS engine available (' .. table.concat(reasons, '; ') .. ')'
end

---@param ext string File extension without the dot.
---@return string|nil, string|nil Absolute path or (nil, err).
local function default_out_path(ext)
    local cache = vim.fn.stdpath('cache')
    if type(cache) ~= 'string' or cache == '' then
        return nil, 'could not resolve stdpath cache'
    end
    local dir = cache .. '/ai-media'
    if vim.fn.mkdir(dir, 'p') == 0 then
        return nil, 'could not create output directory: ' .. dir
    end
    return dir .. '/tts-' .. tostring(os.time()) .. '.' .. ext, nil
end

-- Backend table registered under 'tts-local'.
---@return boolean available
---@return string reason
local function detect()
    local engine, reason = pick_engine()
    if not engine then
        return false, reason
    end
    return true, reason
end

---@param opts AiMediaGenerateOpts
---@param cb AiMediaCallback
local function generate(opts, cb)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(cb) == 'function', 'cb must be a function')
    local text = opts.text
    if type(text) ~= 'string' or text == '' then
        cb('no text to speak', nil)
        return
    end
    if #text > TEXT_CHARS_MAX then
        cb('text exceeds ' .. TEXT_CHARS_MAX .. ' characters', nil)
        return
    end
    local engine, reason, extra = pick_engine()
    if not engine then
        cb(reason, nil)
        return
    end
    local out = opts.out_path
    ---@type string
    local out_path
    if out == nil then
        local ext = engine.id == 'say' and 'aiff' or 'wav'
        local resolved, err = default_out_path(ext)
        if not resolved then
            cb(err, nil)
            return
        end
        out_path = resolved
    else
        assert(out ~= '', 'output path must not be empty')
        out_path = out
    end
    local argv = engine.argv(text, out_path, extra)
    local done = false
    local timer = vim.uv.new_timer()
    if not timer then
        cb('could not create TTS timeout timer', nil)
        return
    end
    ---@type vim.SystemObj?
    local handle
    local function finish(err)
        if done then
            return
        end
        done = true
        timer:stop()
        timer:close()
        vim.schedule(function()
            if err then
                cb(err, nil)
                return
            end
            local stat = vim.uv.fs_stat(out_path)
            if not stat or stat.size <= WAV_HEADER_BYTES then
                cb(engine.id .. ' produced no audio', nil)
                return
            end
            cb(nil, { path = out_path, bytes = stat.size, backend = 'tts-local' })
        end)
    end
    ---@type vim.SystemOpts
    local system_opts = { text = true }
    if engine.stdin_text then
        system_opts.stdin = text
    end
    local ok, proc = pcall(vim.system, argv, system_opts, function(outcome)
        if done then
            return
        end
        if outcome.code ~= 0 then
            local detail = outcome.stderr ~= '' and outcome.stderr or 'exit code ' .. outcome.code
            finish(engine.id .. ' failed: ' .. detail)
            return
        end
        finish(nil)
    end)
    if not ok then
        finish('could not start ' .. engine.id)
        return
    end
    handle = proc
    timer:start(GENERATE_TIMEOUT_MS, 0, function()
        if handle then
            pcall(handle.kill, handle, 9)
        end
        finish(engine.id .. ' exceeded the time limit')
    end)
end

-- Assemble the backend only once all fields exist; a partial literal
-- would trip the strict missing-fields check.
---@type AiMediaBackend
local backend = { kind = 'audio', detect = detect, generate = generate }

M.backend = backend
M.TEXT_CHARS_MAX = TEXT_CHARS_MAX

return M
