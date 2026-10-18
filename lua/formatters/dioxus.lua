-- /qompassai/Diver/lua/formatters/dioxus.lua
-- Qompass AI Diver Native Dioxus RSX Formatter
---@module 'formatters.dioxus'
---@source https://github.com/DioxusLabs/dioxus
---@source https://dioxuslabs.com/learn/0.7/guides/tools/
---@param context FormatterContext
---@return string
local function working_directory(context)
    local root = context.root
    if root == '' then
        error('dioxus: formatter context has an empty project root')
    end
    return vim.fs.normalize(root)
end

---@type FormatterSpec
return {
    cmd = 'dx',

    args = {
        'fmt',
        '-f',
        '-',
    },
    mode = 'stdin',
    output = 'stdout',
    cwd = working_directory,
    root_markers = {
        'Dioxus.toml',
        'dioxus.toml',
        'Cargo.toml',
        '.git',
    },
    env = {
        NO_COLOR = '1',
    },

    exit_codes = {
        0,
    },
    automatic = true,
    allow_empty = false,
    extension = 'rs',
}
