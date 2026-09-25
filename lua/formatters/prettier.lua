-- #################################################################
-- ~/.config/nvim/lua/formatters/prettier.lua
-- Qompass AI Diver Prettier Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/keyz/prettier/blob/HEAD/docs/cli.md
---
--- Prettier is the opinionated formatter for JavaScript, TypeScript,
--- CSS, Markdown and friends. `--stdin-filepath` makes it read the
--- source from stdin while pretending it came from the given path,
--- so the parser is inferred and project config still applies. An
--- unnamed buffer cannot pick a parser, so the adapter refuses it
--- instead of guessing one.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filename == '' then
        error('prettier: --stdin-filepath needs a filename to infer the parser')
    end
    return { '--stdin-filepath', context.filename }
end

---@type FormatterSpec
return {
    cmd = 'prettier',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'js',
}
