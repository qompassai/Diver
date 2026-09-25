-- #################################################################
-- ~/.config/nvim/lua/formatters/mix_format.lua
-- Qompass AI Diver Mix Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/elixir-lang/elixir/issues/7411
---
--- Elixir's own tidy-up robot, built into the `mix` build tool.
--- `mix format -` reads Elixir code from standard input and prints
--- the tidied result to standard output, applying the project's
--- .formatter.exs rules when run from the project folder.

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
    cmd = 'mix',
    args = { 'format', '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    env = {},
    root_markers = { 'mix.exs', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'ex',
    decode = nil,
    pre_transform = nil,
}
