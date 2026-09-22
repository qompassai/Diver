-- ~/.config/nvim/lua/formatters/scalafmt.lua
-- Native Scalafmt formatter specification for Neovim 0.13+ / LuaJIT.
-- SPDX-License-Identifier: Apache-2.0
-- https://github.com/scalameta/scalafmt
-- The shared runner owns processes, deadlines, output bounds, and buffer mutation.
local fs = vim.fs
local uv = vim.uv

local ANCESTOR_COUNT_MAX = 128
local CONFIG_FILENAME = '.scalafmt.conf'

---@param context FormatterContext
---@return string
local function working_directory(context)
    assert(type(context) == 'table', 'Scalafmt requires a formatter context')
    assert(type(context.filename) == 'string', 'Scalafmt requires a filename string')
    assert(type(context.cwd) == 'string', 'Scalafmt requires a working directory')

    if context.filetype ~= 'scala' and context.filetype ~= 'sbt' then
        error('Scalafmt requires a scala or sbt buffer', 0)
    end

    local directory = context.cwd
    if context.filename ~= '' then
        directory = fs.dirname(context.filename)
    end
    assert(directory ~= '', 'Scalafmt requires a nonempty directory')
    assert(not directory:find('%z'), 'Scalafmt directory contains NUL')

    -- Find nested project configuration before the repository boundary. A .git
    -- file (worktree) is a boundary too. Missing configuration never creates one.
    for _ = 1, ANCESTOR_COUNT_MAX do
        local config = fs.joinpath(directory, CONFIG_FILENAME)
        local info = uv.fs_stat(config)
        if info ~= nil then
            if info.type ~= 'file' or vim.fn.filereadable(config) ~= 1 then
                error('Scalafmt configuration is not a readable file: ' .. config, 0)
            end
            return directory
        end

        if uv.fs_stat(fs.joinpath(directory, '.git')) ~= nil then
            break
        end
        local parent = fs.dirname(directory)
        if parent == directory or parent == '' then
            break
        end
        directory = parent
    end

    error('Scalafmt requires a readable .scalafmt.conf in the project ancestry (max 128)', 0)
end

---@param context FormatterContext
---@return string[]
local function arguments(context)
    assert(type(context.filename) == 'string', 'Scalafmt requires a filename string')
    assert(type(context.cwd) == 'string', 'Scalafmt requires a working directory')

    local filename = context.filename
    if filename == '' then
        local basename = context.filetype == 'sbt' and 'build.sbt' or 'Main.scala'
        filename = fs.joinpath(context.cwd, basename)
    end
    assert(not filename:find('%z'), 'Scalafmt filename contains NUL')

    -- Keep .sbt/.sc extensions and the original path for dialect/file overrides.
    -- No positional source paths: only stdin is formatted, with output on stdout.
    return {
        '--stdin',
        '--stdout',
        '--non-interactive',
        '--no-progress-bar',
        '--config',
        fs.joinpath(context.cwd, CONFIG_FILENAME),
        '--assume-filename',
        filename,
    }
end

---@type FormatterSpec
local specification = {
    cmd = 'scalafmt',
    args = arguments,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = { '.scalafmt.conf', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
}

return specification