-- #################################################################
-- ~/.config/nvim/lua/formatters/ormolu.lua
-- Qompass AI Diver Ormolu Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/tweag/ormolu/blob/HEAD/README.md
---
--- Ormolu is the opinionated Haskell code formatter. With no input
--- file argument it reads Haskell source from stdin and prints the
--- formatted source to stdout. `--stdin-input-file` hands it the
--- real filename so it can find the enclosing Cabal project and any
--- `.ormolu` settings; it is skipped for unnamed buffers.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filename ~= '' then
        return { '--stdin-input-file', context.filename }
    end
    return {}
end

---@type FormatterSpec
return {
    allow_empty = false,
    args = build_args,
    automatic = true,
    cmd = 'ormolu',
    exit_codes = { 0 },
    extension = 'hs',
    mode = 'stdin',
    output = 'stdout',
}
