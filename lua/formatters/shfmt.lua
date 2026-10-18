-- ~/.config/nvim/lua/formatters/shfmt.lua
-- Qompass AI Diver shfmt Native Formatter Spec
---@source https://github.com/mvdan/sh

--- Shell formatter — tidies sh/bash scripts piped through stdin.
---
--- Plain-language version: shfmt formats shell scripts. Every behavior flag
--- is pinned: listing, rewriting, and diff modes off (`-l`/`-w`/`-d`), no
--- simplification or minification (`-s`/`-mn`), ignore files not applied,
--- POSIX mode off, function-next-line and other layout knobs off, JSON
--- modes off. `-ln=auto` detects the shell dialect from `-filename=`,
--- `-i=0` keeps tab indentation. The buffer arrives on stdin; formatted
--- source leaves on stdout.
---@module 'formatters.shfmt'

-- Requires your native formatters/init.lua (FormatterSpec/FormatterContext).
---@param context FormatterContext
---@return string[]
local function args(context)
    return {
        '-version=false',
        '-l=false',
        '-w=false',
        '-d=false',
        '-s=false',
        '-mn=false',
        '--apply-ignore=false',
        '-ln=auto',
        '-p=false',
        '-filename=' .. context.filename,
        '-i=0',
        '-bn=false',
        '-ci=false',
        '-sr=false',
        '-kp=false',
        '-fn=false',
        '-f=false',
        '--to-json=false',
        '--from-json=false',
    }
end

---@param context FormatterContext
---@return string
local function working_directory(context)
    if context.filename ~= '' then
        local directory = vim.fs.dirname(context.filename)
        if directory then
            return directory
        end
    end
    return context.root
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = args,
    automatic = true,
    cmd = 'shfmt',
    cwd = working_directory,
    decode = nil,
    env = {
        NO_COLOR = '1',
        TERM = 'dumb',
    },
    exit_codes = {
        0,
    },
    extension = 'sh',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = {
        '.editorconfig',
        '.git',
    },
}
