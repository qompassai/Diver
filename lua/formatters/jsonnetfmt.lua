-- /qompassai/lua/formatters/jsonnetfmt.lua
-- Qompass AI Diver jsonnetfmt Native Formatter Spec
---@source https://github.com/google/jsonnet

--- Jsonnet formatter — canonical layout for `.jsonnet` files.
---
--- Plain-language version: jsonnetfmt formats Jsonnet (the templating
--- language for JSON configs). The flags pin the whole style: 2-space
--- indent, at most 2 blank lines, single-quoted strings and comments,
--- pretty field names, no padding inside arrays, padding inside objects,
--- sorted imports, and implicit `+` for object extension. The trailing `-`
--- reads the buffer from stdin.
---@module 'formatters.jsonnetfmt'

-- #################################################################
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
    cmd = 'jsonnetfmt',
    args = {
        '--indent',
        '2',
        '--max-blank-lines',
        '2',
        '--string-style',
        's',
        '--comment-style',
        's',
        '--pretty-field-names',
        '--no-pad-arrays',
        '--pad-objects',
        '--sort-imports',
        '--use-implicit-plus',
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'jsonnetfile.json',
        'jsonnetfile.lock.json',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'jsonnet',
    decode = nil,
    pre_transform = nil,
}
