-- #################################################################
-- ~/.config/nvim/lua/formatters/dart_format.lua
-- Native dart format Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/dart-lang/site-www/blob/HEAD/src/content/tools/dart-format.md
---
--- Tiger Style profile for Dart (dart format's canonical style already uses
--- 4-space indentation; 100-column review target). `dart format` with no
--- path arguments reads piped stdin and emits the formatted source on
--- stdout. `--line-length 100` pins the Tiger Style review width; the CLI
--- flag takes precedence over `formatter: page_width` in
--- analysis_options.yaml. `--stdin-name` names the buffer in diagnostics.

local DART_WIDTH = 100

---@param context FormatterContext
---@return string[]
local function build_args(context)
    if context.filetype ~= 'dart' then
        error('dart_format requires the dart filetype')
    end

    local name = vim.fs.basename(context.filename)
    if name == '' then
        name = 'stdin.dart'
    end

    return {
        'format',
        '--line-length',
        tostring(DART_WIDTH),
        '--stdin-name',
        name,
    }
end

---@type FormatterSpec
return {
    cmd = 'dart',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'pubspec.yaml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = nil,
    decode = nil,
    pre_transform = nil,
}
