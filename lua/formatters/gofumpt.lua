-- #################################################################
-- ~/.config/nvim/lua/formatters/gofumpt.lua
-- Qompass AI Diver Gofumpt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/mvdan/gofumpt

--- Stricter Go formatter — gofmt plus extra rules, import-safe.
---
--- Plain-language version: gofumpt is a stricter drop-in for gofmt. Every
--- flag is pinned off or empty so it only formats: `-l`/`-w`/`-d` never
--- list, rewrite, or diff files; `-e` still reports syntax errors;
--- `-lang=` and `-modpath=` stay empty so the language version is
--- auto-detected; `-extra`, `-s`, profiling, and rewrite rules stay off.
--- The buffer arrives on stdin and formatted source leaves on stdout; the
--- runner sets the working directory to the file's folder so module-aware
--- formatting works.
---@module 'formatters.gofumpt'

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
    cmd = 'gofumpt',
    args = {
        '-l=false',
        '-w=false',
        '-d=false',
        '-e=true',
        '-lang=',
        '-modpath=',
        '-extra=false',
        '-version=false',
        '-cpuprofile=',
        '-r=',
        '-s=false',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'go.mod',
        'go.work',
        '.git',
    },
    env = {
        NO_COLOR = '1',
        GOTOOLCHAIN = 'local',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'go',
    decode = nil,
    pre_transform = nil,
}
