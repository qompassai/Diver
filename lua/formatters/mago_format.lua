-- #################################################################
-- ~/.config/nvim/lua/formatters/mago_format.lua
-- Qompass AI Diver Mago Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/carthage-software/mago/blob/HEAD/docs/content/en/tools/formatter/command-reference.md
---
--- A tidy-up robot for PHP, from the Mago toolchain.
--- `mago format --stdin-input` reads PHP from standard input and
--- prints the tidied code to standard output. `--stdin-filepath`
--- hands over the buffer's real path so mago.toml excludes and
--- diagnostics can name the right file (it is never written to).

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
    local name = context.filename ~= '' and context.filename or 'file.php'
    return {
        'format',
        '--stdin-input',
        '--stdin-filepath',
        name,
    }
end

---@type FormatterSpec
return {
    cmd = 'mago',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    env = {},
    root_markers = { 'mago.toml', 'composer.json', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'php',
    decode = nil,
    pre_transform = nil,
}
