-- #################################################################
-- ~/.config/nvim/lua/formatters/goimports.lua
-- Qompass AI Diver Goimports Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://pkg.go.dev/golang.org/x/tools/cmd/goimports

--- Go import manager — adds missing imports, drops unused ones.
---
--- Plain-language version: goimports formats Go code like gofmt and also
--- fixes the import block. The flags pin a format-only pipeline: `-l`/`-w`
--- never touch files, `-d` returns source instead of a diff, `-e` reports
--- parse errors, `-v` stays quiet, `-format-only=false` keeps the import
--- fixing on, `-local=` sets no special import prefixes, `-srcdir=` tells
--- goimports the file's directory for module-aware import resolution, and
--- profiling/tracing stay disabled.
---@module 'formatters.goimports'

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
local function arguments(context)
    local filename = context.filename
    if filename == '' then
        filename = vim.fs.joinpath(context.root, 'stdin.go')
    end
    return {
        '-l=false', -- Do not list changed filenames.
        '-w=false', -- Never overwrite the source file.
        '-d=false', -- Return source, not a diff.
        '-e=true', -- Report all parse errors on stderr.
        '-v=false', -- Disable verbose import-resolution logging.
        '-format-only=false', -- Add missing imports and remove unused imports.
        '-local=', -- No special local import prefixes.
        '-srcdir=' .. filename,
        '-cpuprofile=', -- Disabled: no profiling files.
        '-memprofile=',
        '-memrate=0',
        '-trace=', -- gc-build trace flag; disabled.
    }
end

---@type FormatterSpec
return {
    cmd = 'goimports',
    args = arguments,
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
