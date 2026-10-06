-- /qompassai/Diver/lua/config/lang/TEMPLATE.lua
-- Qompass AI Diver Lang Module Template (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------------------
--
-- HOW TO USE: copy this file to <lang>.lua, replace LANG/ft/pattern
-- placeholders, fill in the sections. Delete sections you don't need.
--
-- RULES (Tiger Style):
-- 1. Alphabetical order everywhere: requires, locals, constants,
--    functions, autocmds, user commands, keymaps, replacement tables.
--    Dependency order wins only where Lua requires it (locals before use).
-- 2. NO side effects at require time. No augroup creation, no autocmd
--    registration, no formatters.register_stage at module top level.
--    Everything goes inside M.setup(), guarded by a once-flag.
-- 3. init.lua lazy-loads via FileType autocmd: require + setup() run
--    only when a buffer of that filetype actually opens.
-- 4. Keep requires minimal and alphabetical. Prefer vim.* builtins.
--
---@module 'config.lang.LANG'

local M = {}

-- ── 1. Locals (alphabetical) ──────────────────────────────────────
local api = vim.api
local fn = vim.fn
local formatters = require('formatters')
local modernize = require('config.lang.modernize')

-- ── 2. Constants (alphabetical) ───────────────────────────────────
local FILETYPE = 'LANG'
local GROUP = 'lang_LANG'

-- ── 3. Local helpers (alphabetical) ───────────────────────────────
---Create a buffer-local user command when a LANG buffer opens.
---@param name string command name
---@param rhs function|string command implementation
---@param opts? table nvim_create_user_command options
local function create_user_command(name, rhs, opts)
    api.nvim_create_autocmd('FileType', {
        pattern = FILETYPE,
        desc = ('Buffer-local command: %s'):format(name),
        callback = function(args)
            api.nvim_buf_create_user_command(args.buf, name, rhs, opts or {})
        end,
    })
end

-- ── 4. Deprecation replacements (alphabetical by pattern) ─────────
-- Each entry: { lua_pattern, replacement_string_or_function }.
-- Keep patterns anchored and specific; prefer false negatives over
-- false positives. Test every pattern against adversarial input.
local REPLACEMENTS = {
    -- { 'old_pattern', 'new_replacement' },
}

-- ── 5. Public API (alphabetical) ──────────────────────────────────
---Modernize deprecated LANG syntax in the current buffer.
function M.modernize()
    modernize.buffer(FILETYPE, REPLACEMENTS, 'LANG')
end

---Set up LANG tooling. Idempotent: safe to call multiple times.
function M.setup()
    if M._setup_done then
        return
    end
    M._setup_done = true

    local group = api.nvim_create_augroup(GROUP, { clear = true })

    -- Autocmds (alphabetical by event, then pattern)
    -- ...

    -- Formatter stages (alphabetical by name, ascending priority)
    formatters.register_stage({
        name = 'LANG_modernize',
        priority = 100,
        patterns = { '*.ext' },
        desc = 'Modernize deprecated LANG syntax before save',
        run = function(bufnr)
            modernize.apply(bufnr, REPLACEMENTS)
        end,
    })

    -- User commands (alphabetical)
    create_user_command('LangModernize', M.modernize, {
        desc = 'Modernize deprecated LANG syntax in current buffer',
    })

    -- Keymaps (alphabetical by lhs)
    -- vim.keymap.set('n', '<leader>m...', M.modernize, { desc = '...' })
end

return M
