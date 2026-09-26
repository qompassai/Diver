-- /qompassai/Diver/lua/ai/media/commands.lua
-- Qompass AI Media User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- User commands and keymaps for media generation: AiTts (speak
-- text/buffer/selection via the local TTS backend), AiImage (generate an
-- image from a prompt), AiVideo (video availability, always honest),
-- AiMedia (the backend picker). Command bodies stay thin; probing,
-- limits and subprocess work live in the backend modules. Keymaps live
-- here rather than in lua/mappings/aimap.lua: that module is for
-- buffer-local LSP/inline-completion maps installed per buffer, while
-- these are global media commands.

local registry = require('ai.media.registry')
local tts = require('ai.media.tts_local')
local ui = require('ai.media.ui')

local M = {}

local did_setup = false

local function notify(message, level)
    assert(type(message) == 'string', 'notification must be a string')
    vim.notify(message, level or vim.log.levels.INFO, { title = 'AI media' })
end

-- Best-effort playback of a generated audio file. Returns true when a
-- player was found and launched; never fails the command when none is.
---@param path string
---@return boolean
local function try_play(path)
    assert(type(path) == 'string' and path ~= '', 'path must be a string')
    local uname = vim.uv.os_uname()
    local darwin = type(uname) == 'table' and uname.sysname == 'Darwin'
    ---@type string[][]
    local candidates = {}
    if darwin then
        candidates[#candidates + 1] = { 'afplay', path }
    end
    candidates[#candidates + 1] = { 'aplay', path }
    candidates[#candidates + 1] = { 'paplay', path }
    candidates[#candidates + 1] = { 'ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', path }
    for _, argv in ipairs(candidates) do
        if vim.fn.executable(argv[1]) == 1 then
            vim.system(argv, { detach = true })
            return true
        end
    end
    return false
end

---@param name string Backend registry name.
---@param text string
local function speak_with(name, text)
    assert(type(name) == 'string' and name ~= '', 'backend name required')
    if text:match('^%s*$') then
        notify('nothing to speak', vim.log.levels.WARN)
        return
    end
    if #text > tts.TEXT_CHARS_MAX then
        notify('text truncated to ' .. tts.TEXT_CHARS_MAX .. ' characters', vim.log.levels.WARN)
        text = text:sub(1, tts.TEXT_CHARS_MAX)
    end
    local backend = registry.get(name)
    if not backend then
        notify('backend not registered: ' .. name, vim.log.levels.ERROR)
        return
    end
    local available, reason = backend.detect()
    if not available then
        notify(name .. ' unavailable: ' .. reason, vim.log.levels.WARN)
        return
    end
    backend.generate({ text = text }, function(err, result)
        if err then
            notify('TTS failed: ' .. err, vim.log.levels.ERROR)
            return
        end
        assert(result ~= nil, 'TTS success must carry a result')
        local suffix = try_play(result.path) and ' (playing)' or ' (no audio player found)'
        notify('audio saved to ' .. result.path .. suffix)
    end)
end

---@param name string Backend registry name.
---@param prompt string
local function image_with(name, prompt)
    assert(type(name) == 'string' and name ~= '', 'backend name required')
    if prompt:match('^%s*$') then
        notify('no prompt given', vim.log.levels.WARN)
        return
    end
    local backend = registry.get(name)
    if not backend then
        notify('backend not registered: ' .. name, vim.log.levels.ERROR)
        return
    end
    local available, reason = backend.detect()
    if not available then
        notify(name .. ' unavailable: ' .. reason, vim.log.levels.WARN)
        return
    end
    notify('generating image…')
    backend.generate({ prompt = prompt }, function(err, result)
        if err then
            notify('image generation failed: ' .. err, vim.log.levels.ERROR)
            return
        end
        assert(result ~= nil, 'image success must carry a result')
        notify('image saved to ' .. result.path .. ' (' .. result.bytes .. ' bytes)')
    end)
end

---@param cmd_opts table User-command options (args/range/line1/line2).
---@return string
local function gather_text(cmd_opts)
    assert(type(cmd_opts) == 'table', 'command options must be a table')
    if type(cmd_opts.args) == 'string' and cmd_opts.args ~= '' then
        return cmd_opts.args
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local lines
    if cmd_opts.range == 2 then
        local line1 = math.max(1, cmd_opts.line1 or 1)
        local line2 = math.max(line1, cmd_opts.line2 or line1)
        lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
    else
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    end
    return table.concat(lines, '\n')
end

---@type AiMediaPickHandlers
local handlers = {
    audio = function(name)
        vim.ui.input({ prompt = 'Text to speak: ' }, function(input)
            if type(input) == 'string' and input ~= '' then
                speak_with(name, input)
            end
        end)
    end,
    image = function(name)
        vim.ui.input({ prompt = 'Image prompt: ' }, function(input)
            if type(input) == 'string' and input ~= '' then
                image_with(name, input)
            end
        end)
    end,
    video = function(name)
        -- Unreachable while the video backend is a stub (it never reports
        -- available), kept so the picker cannot silently drop a kind.
        notify(name .. ': video generation is not implemented', vim.log.levels.WARN)
    end,
}

function M.setup()
    if did_setup then
        return
    end
    did_setup = true

    vim.api.nvim_create_user_command('AiTts', function(cmd_opts)
        speak_with('tts-local', gather_text(cmd_opts))
    end, {
        nargs = '?',
        range = true,
        desc = 'Speak args, visual selection, or buffer (local TTS)',
    })

    vim.api.nvim_create_user_command('AiImage', function(cmd_opts)
        image_with('image-openai', table.concat(cmd_opts.fargs, ' '))
    end, { nargs = '+', desc = 'Generate an image from a prompt (OpenAI images API)' })

    vim.api.nvim_create_user_command('AiVideo', function()
        ui.open(handlers, 'video')
    end, { nargs = 0, desc = 'Video generation: shows honest availability' })

    vim.api.nvim_create_user_command('AiMedia', function()
        ui.open(handlers)
    end, { nargs = 0, desc = 'Pick an AI media backend (audio/image/video)' })

    vim.keymap.set('n', '<leader>am', '<cmd>AiMedia<CR>', { desc = 'AI media backend picker' })
    vim.keymap.set('n', '<leader>at', '<cmd>AiTts<CR>', { desc = 'AI: speak buffer as audio' })
    vim.keymap.set('v', '<leader>at', ':AiTts<CR>', { desc = 'AI: speak selection as audio' })
    vim.keymap.set('n', '<leader>ai', ':AiImage ', { desc = 'AI: generate image from prompt' })
    vim.keymap.set('n', '<leader>av', '<cmd>AiVideo<CR>', { desc = 'AI: video generation status' })
end

return M
