-- #################################################################
-- ~/.config/nvim/lua/formatters/clang_format.lua
-- Qompass AI Diver Native Clang-Format Formatter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
local CONFIG = {
    executable = 'clang-format',
    style = 'file',
    fallback_style = 'LLVM',
}

---@type table<string, string>
local EXTENSIONS = {
    c = 'c',
    cpp = 'cpp',
    cuda = 'cu',
    objc = 'm',
    objcpp = 'mm',
    proto = 'proto',
}

---@param context FormatterContext
---@return string[]
local function arguments(context)
    local extension = EXTENSIONS[context.filetype]
    if not extension then
        error('clang_format: unsupported filetype ' .. context.filetype)
    end
    local filename = context.filename
    if filename == '' then
        filename = vim.fs.joinpath(context.root, 'stdin.' .. extension)
    end
    return {
        '--style=' .. CONFIG.style,
        '--fallback-style=' .. CONFIG.fallback_style,
        '--assume-filename=' .. filename,
        '--fail-on-incomplete-format',
        '--Werror',
    }
end

---@param context FormatterContext
---@return string
local function working_directory(context)
    return context.root
end

---@type FormatterSpec
return {
    cmd = CONFIG.executable,
    args = arguments,
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        '.clang-format',
        '_clang-format',
        '.clangd',
        'compile_commands.json',
        'compile_flags.txt',
        'CMakeLists.txt',
        '.git',
    },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'cpp',
}
