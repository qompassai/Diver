-- #################################################################
-- ~/.config/nvim/lua/formatters/julia_formatter.lua
-- Qompass AI Diver Julia Formatter Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/juliaeditorsupport/juliaformatter.jl/blob/HEAD/docs/src/cli.md
---
--- The official tidy-up robot for Julia, shipped as the `jlfmt`
--- program. Piped code comes in on standard input and the tidied
--- code goes out on standard output.
--- `--config-dir` tells it where to look for a project's
--- .JuliaFormatter.toml, so we point it at the buffer's folder.

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
local function build_args(context)
    return {
        '--config-dir=' .. working_directory(context),
    }
end

---@type FormatterSpec
return {
    cmd = 'jlfmt',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    env = {},
    root_markers = { '.JuliaFormatter.toml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'jl',
    decode = nil,
    pre_transform = nil,
}
