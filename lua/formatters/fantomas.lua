-- #################################################################
-- ~/.config/nvim/lua/formatters/fantomas.lua
-- Native Fantomas Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/fsprojects/fantomas/blob/HEAD/docs/docs/end-users/UpgradeGuide.md
---
--- Fantomas tidies F# code. Current versions no longer accept code
--- through stdin (the old `--stdin`/`--stdout` flags are gone), so
--- the runner copies the buffer into a private temporary file and
--- Fantomas rewrites that file in place, like pressing "save" in an
--- editor. The runner then reads the tidied file back. The temp file
--- keeps the buffer's real extension (`.fs`, `.fsi`, …) — or
--- `buffer.fs` for unnamed buffers — because Fantomas decides how to
--- parse the code from the extension.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local tempfile = context.tempfile
    if tempfile == nil or tempfile == '' then
        error('fantomas requires a private tempfile from the formatter runner')
    end
    return { tempfile }
end

---@type FormatterSpec
return {
    cmd = 'fantomas',
    args = build_args,
    mode = 'tempfile',
    output = 'file',
    root_markers = { '.editorconfig', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'fs',
}
