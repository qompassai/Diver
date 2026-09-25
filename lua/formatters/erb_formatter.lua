-- #################################################################
-- ~/.config/nvim/lua/formatters/erb_formatter.lua
-- Native erb-format Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/nebulab/erb-formatter
---
--- erb-format tidies ERB templates (HTML with embedded Ruby). The
--- `--stdin` flag means "read the template from the pipe and print
--- the pretty version to stdout". (The adapter keeps the project's
--- `erb_formatter` name; the binary it calls is `erb-format`.)

---@type FormatterSpec
return {
    cmd = 'erb-format',
    args = { '--stdin' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'erb',
}
