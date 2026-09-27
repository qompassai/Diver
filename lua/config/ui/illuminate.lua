-- lua/config/ui/illuminate.lua
-- Qompass AI Diver Illuminate Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
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
            providers = {
                'lsp',
                'treesitter',
                'regex',
            },
            delay = 100,
            filetype_overrides = {},
            filetypes_denylist = {
                'dirbuf',
                'dirvish',
                'fugitive',
            },
            filetypes_allowlist = {},
            modes_denylist = {},
            modes_allowlist = {},
            providers_regex_syntax_denylist = {},
            providers_regex_syntax_allowlist = {},
            under_cursor = true,
            large_file_cutoff = 10000,
            large_file_overrides = nil,
            min_count_to_highlight = 1,
            should_enable = function()
                return true
            end,
            case_insensitive_regex = true,
            disable_keymaps = false,
        })
    end
end

return M
