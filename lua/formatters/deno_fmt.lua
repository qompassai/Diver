-- #################################################################
-- ~/.config/nvim/lua/formatters/deno_fmt.lua
-- Native deno fmt Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://docs.deno.com/runtime/reference/cli/fmt/
---
--- deno is the JavaScript/TypeScript runtime, and `deno fmt` is its
--- built-in code tidier. When code arrives through a pipe, deno cannot
--- see a file name, so it cannot tell TypeScript from JSON from
--- Markdown. The `--ext` flag is a name tag we stick on the box
--- ("this is TypeScript"), and the trailing `-` means "read the code
--- from stdin and print the pretty version to stdout". The tag is
--- picked from the buffer's filetype, so each language gets the right
--- parser.

--- Maps the filetypes this adapter serves to deno's `--ext` values.
---@type table<string, string>
local DENO_EXTENSIONS = {
    javascript = 'js',
    javascriptreact = 'jsx',
    json = 'json',
    jsonc = 'jsonc',
    typescript = 'ts',
    typescriptreact = 'tsx',
}

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local ext = DENO_EXTENSIONS[context.filetype]
    if ext == nil then
        error('deno_fmt cannot pick a language tag for filetype: ' .. context.filetype)
    end
    return { 'fmt', '--ext', ext, '-' }
end

---@type FormatterSpec
return {
    cmd = 'deno',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'deno.json', 'deno.jsonc', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'ts',
}
