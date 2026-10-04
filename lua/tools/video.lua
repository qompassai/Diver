--- video.lua — Video-to-tokens conversion for AI review.
---
--- Plain-language version: when Matt sends a screen recording (like a README
--- walkthrough), this module converts it into something an AI can actually
--- read — extracted frames, audio transcription, and on-screen text. Instead
--- of trying to "watch" the video, the AI gets a Markdown summary with
--- timestamps it can reason about.
---
--- Backend: `video-tokens.py` (ffmpeg + Whisper + EasyOCR).
---@module 'tools.video'

local M = {}

local SCRIPT_PATH = vim.fn.expand('~/workspace/tools/video-tokens.py')

---@class tools.VideoOptions
---@field fps? integer Frames per second to extract (default 1).
---@field whisper_model? string Whisper model size (default 'base').
---@field out_dir? string Output directory (default: video name + '-tokens').

---Convert a video file to AI-consumable tokens.
---@param video_path string Path to the input video.
---@param opts? tools.VideoOptions
---@param on_done? fun(success: boolean, out_dir: string)
function M.convert(video_path, opts, on_done)
    assert(type(video_path) == 'string', 'video_path must be a string')
    opts = opts or {}

    if vim.fn.filereadable(video_path) ~= 1 then
        vim.notify('Video file not found: ' .. video_path, vim.log.levels.ERROR)
        if on_done then
            on_done(false, '')
        end
        return
    end

    if vim.fn.filereadable(SCRIPT_PATH) ~= 1 then
        vim.notify('video-tokens.py not found at ' .. SCRIPT_PATH, vim.log.levels.ERROR)
        if on_done then
            on_done(false, '')
        end
        return
    end

    local fps = opts.fps or 1
    local model = opts.whisper_model or 'base'
    local out_dir = opts.out_dir
    if not out_dir then
        local base = vim.fn.fnamemodify(video_path, ':t:r')
        local dir = vim.fn.fnamemodify(video_path, ':h')
        out_dir = dir .. '/' .. base .. '-tokens'
    end

    local cmd = {
        'python3',
        SCRIPT_PATH,
        video_path,
        '--fps',
        tostring(fps),
        '--out-dir',
        out_dir,
        '--whisper-model',
        model,
    }

    vim.notify('Converting video to tokens...', vim.log.levels.INFO)

    vim.system(cmd, { text = true }, function(res)
        vim.schedule(function()
            if res.code == 0 then
                vim.notify('Video tokens ready: ' .. out_dir, vim.log.levels.INFO)
                -- Open the summary in a new buffer
                local summary = out_dir .. '/summary.md'
                if vim.fn.filereadable(summary) == 1 then
                    vim.cmd('edit ' .. vim.fn.fnameescape(summary))
                end
            else
                vim.notify('Video conversion failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
            end
            if on_done then
                on_done(res.code == 0, out_dir)
            end
        end)
    end)
end

---Convert the video under cursor (if in a directory buffer) or prompt for path.
function M.convert_interactive()
    local path = vim.fn.expand('<cfile>')
    if path == '' or vim.fn.filereadable(path) ~= 1 then
        -- Prompt for path
        vim.ui.input({ prompt = 'Video path: ' }, function(input)
            if input and input ~= '' then
                M.convert(vim.fn.expand(input))
            end
        end)
    else
        M.convert(path)
    end
end

function M.setup()
    vim.api.nvim_create_user_command('VideoTokens', function(args)
        local video = args.args
        if video == '' then
            M.convert_interactive()
        else
            M.convert(vim.fn.expand(video))
        end
    end, {
        nargs = '?',
        complete = 'file',
        desc = 'Convert video to AI-consumable tokens (frames + transcript + OCR)',
    })
end

return M
