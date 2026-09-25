-- #################################################################
-- ~/.config/nvim/lua/formatters/buf_format.lua
-- Native Buf Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://buf.build/docs/format/
---
--- Buf is the toolkit for Protocol Buffers; `buf format` is its code tidier
--- for `.proto` files. Unlike most formatters it cannot read from stdin, so
--- we hand it a private copy of the buffer (mode='tempfile') and read the
--- tidied text it prints to stdout. Your real file is never touched.
---
--- It runs with the project root as its working directory so it can find the
--- workspace's buf.yaml settings.

---@param context FormatterContext
---@return string[]
local function build_args(context)
    local tempfile = context.tempfile
    if not tempfile or tempfile == '' then
        error('buf_format requires a private tempfile from the native formatter runner')
    end
    return {
        'format',
        tempfile,
    }
end

---@param context FormatterContext
---@return string
local function working_directory(context)
    return context.root
end

---@type FormatterSpec
return {
    cmd = 'buf',
    args = build_args,
    mode = 'tempfile',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'buf.yaml',
        'buf.work.yaml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'proto',
}
