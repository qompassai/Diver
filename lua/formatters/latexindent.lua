-- #################################################################
-- ~/.config/nvim/lua/formatters/latexindent.lua
-- Qompass AI Diver Latexindent Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://www.tug.org/texmf/doc/support/latexindent/latexindent.pdf
---
--- A tidy-up robot for LaTeX documents. Called with no arguments,
--- `latexindent` reads your .tex source from standard input and
--- writes the nicely indented result to standard output.
--- The runner starts it in the buffer's folder so a project's own
--- localSettings.yaml is picked up automatically.

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
    cmd = { 'latexindent', 'latexindent.pl' },
    args = {},
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'tex',
    decode = nil,
    pre_transform = nil,
}
