-- #################################################################
-- ~/.config/nvim/lua/formatters/ocamlformat.lua
-- Qompass AI Diver Ocamlformat Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/ocaml-ppx/ocamlformat
---
--- ocamlformat is the OCaml code formatter. When it reads from stdin
--- it cannot guess whether the text is an implementation or an
--- interface, so the caller must pass `--impl` (for .ml files) or
--- `--intf` (for .mli files). The adapter picks the flag from the
--- buffer's filename extension and refuses anything else instead of
--- guessing.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filename:match('%.mli$') then
        return { '--intf' }
    end
    if context.filename:match('%.ml$') then
        return { '--impl' }
    end
    error('ocamlformat: needs a .ml (--impl) or .mli (--intf) filename')
end

---@type FormatterSpec
return {
    cmd = 'ocamlformat',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'ml',
}
