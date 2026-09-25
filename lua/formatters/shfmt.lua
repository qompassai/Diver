-- #################################################################
-- ~/.config/nvim/lua/formatters/shfmt.lua
-- Qompass AI Diver shfmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
-- Requires your native formatters/init.lua (FormatterSpec/FormatterContext).
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

---@type FormatterSpec
return {
    cmd = 'shfmt',
    args = args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        '.editorconfig',
        '.git',
    },
    env = {
        NO_COLOR = '1',
        TERM = 'dumb',
    },
    exit_codes = {
        0,
    },
    automatic = true,
    allow_empty = false,
    extension = 'sh',
}
