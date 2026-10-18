-- lua/config/ui/illuminate.lua
-- Qompass AI Diver Illuminate Config
---Cursor-word illumination. Requiring this module has no side effects;
---call setup() to configure the plugin. setup() is idempotent.
---@module 'config.ui.illuminate'

local M = {}

---Configure vim-illuminate when it is installed; no-op otherwise.
function M.setup()
    -- Illuminate is optional: when the plugin is not installed, skip
    -- configuration instead of failing.
    local ok, illuminate = pcall(require, 'illuminate')
    if ok then
        illuminate.configure({
            case_insensitive_regex = true,
            delay = 100,
            disable_keymaps = false,
            filetype_overrides = {},
            filetypes_allowlist = {},
            filetypes_denylist = {
                'dirbuf',
                'dirvish',
                'fugitive',
            },
            large_file_cutoff = 10000,
            large_file_overrides = nil,
            min_count_to_highlight = 1,
            modes_allowlist = {},
            modes_denylist = {},
            providers = {
                'lsp',
                'regex',
                'treesitter',
            },
            providers_regex_syntax_allowlist = {},
            providers_regex_syntax_denylist = {},
            should_enable = function()
                return true
            end,
            under_cursor = true,
        })
    end
end

return M
