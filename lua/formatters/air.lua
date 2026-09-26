-- #################################################################
-- ~/.config/nvim/lua/formatters/air.lua
-- Native Air Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://posit-dev.github.io/air/cli.html
---
--- Air is the code tidier for the R language: it rewrites messy R code with
--- clean, consistent spacing and indentation, the same way for everyone.
---
--- `air format` is the formatting subcommand. `--stdin-file-path <path>`
--- means: "read the code I hand you through stdin and print the tidied code
--- back to stdout, but pretend the code lives at <path> so you pick the
--- right settings." The path never has to exist; its directory and extension
--- are what matter. An unnamed buffer has no path, so we refuse it loudly
--- instead of guessing.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    assert(context.filename ~= '', 'air requires a filename for --stdin-file-path')
    return {
        'format',
        '--stdin-file-path',
        context.filename,
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
    cmd = 'air',
    args = build_args,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'air.toml',
        'DESCRIPTION',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'R',
}
