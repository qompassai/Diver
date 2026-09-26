-- #################################################################
-- ~/.config/nvim/lua/formatters/biome.lua
-- Native Biome Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://next.biomejs.dev/reference/cli/
---
--- Biome is the all-in-one code tidier for JavaScript, TypeScript and JSON:
--- it rewrites code with clean, consistent style.
---
--- `format` is the formatting subcommand. `--stdin-file-path=<path>` means:
--- "read the code I hand you through stdin and print the tidied code back
--- to stdout, but pretend the code lives at <path> so you pick the right
--- settings and know which language it is." The official CLI docs document
--- exactly this: the path does not need to exist, only its extension
--- matters. An unnamed buffer has no path, so we refuse it loudly instead
--- of guessing.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    assert(context.filename ~= '', 'biome requires a filename for --stdin-file-path')
    return {
        'format',
        '--stdin-file-path=' .. context.filename,
    }
end

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
    cmd = 'biome',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'biome.json',
        'biome.jsonc',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'js',
}
