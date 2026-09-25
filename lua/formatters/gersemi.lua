-- ~/.config/nvim/lua/formatters/gersemi.lua
-- Native Gersemi formatter specification for Neovim 0.13+ / LuaJIT.
-- SPDX-License-Identifier: Apache-2.0
---@source https://github.com/BlankSpruce/gersemi

--- CMake formatter — tidies `CMakeLists.txt` files without breaking them.
---
--- Plain-language version: Gersemi formats CMake files. `--safe` refuses to
--- change anything it cannot prove is semantics-preserving, `--workers 1`
--- keeps a single deterministic worker, `--stdin-filepath <name>` tells
--- Gersemi the filename (used only for style decisions; the buffer itself
--- arrives on stdin, marked by the trailing `-`), so unsaved buffers format
--- correctly.
---@module 'formatters.gersemi'
-- The shared runner owns processes, deadlines, output bounds, and buffer mutation.
local fs = vim.fs

---@param context FormatterContext
---@return string[]
local function arguments(context)
    assert(type(context) == 'table', 'Gersemi requires a formatter context')
    assert(type(context.filename) == 'string', 'Gersemi requires a filename string')
    assert(type(context.cwd) == 'string', 'Gersemi requires a working directory')

    if context.filetype ~= 'cmake' then
        error('Gersemi requires a cmake buffer', 0)
    end

    local filename = context.filename
    if filename == '' then
        filename = fs.joinpath(context.cwd, 'CMakeLists.txt')
    end
    assert(not filename:find('%z'), 'Gersemi filename contains NUL')

    -- The filename is metadata only: Gersemi reads the unsaved buffer from stdin.
    -- Preserve .gersemirc style settings; explicitly enable semantic sanity checks.
    return {
        '--safe',
        '--workers',
        '1',
        '--stdin-filepath',
        filename,
        '-',
    }
end

---@type FormatterSpec
local specification = {
    cmd = 'gersemi',
    args = arguments,
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.gersemirc', '.git', 'CMakeLists.txt' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    cwd = nil,
    env = {},
    decode = nil,
    pre_transform = nil,
}

return specification
