-- #################################################################
-- ~/.config/nvim/lua/formatters/kcl_fmt.lua
-- Qompass AI Diver KCL Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://www.kcl-lang.io/docs/next/tools/cli/kcl/fmt
---
--- A tidy-up robot for KCL (the Kusion Configuration Language).
--- `kcl fmt` rewrites the given file in place, so the runner
--- hands it a private copy of the buffer and reads the tidied
--- result back from that copy.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    return {
        'fmt',
        assert(context.tempfile),
    }
end

---@type FormatterSpec
return {
    cmd = 'kcl',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    cwd = nil,
    env = {},
    root_markers = { 'kcl.mod', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'kcl',
    decode = nil,
    pre_transform = nil,
}
