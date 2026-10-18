-- /qompassai/diver/lua/config/nav/motion.lua
-- Qompass AI Diver Motion Pack (Tiger Style)
---@module 'config.nav.motion'
--
-- Enhanced cursor motions: diagnostics, quickfix/location lists, and
-- treesitter method jumps — all centered, all count-aware.
--
-- Contract:
-- - Every jump centers the cursor line (zz) so context is never lost.
-- - Counts work: `3]d` jumps three diagnostics forward.
-- - Treesitter jumps degrade to search-based fallback when no parser
--   is available; they never error.
-- - Requiring this module registers nothing; M.setup() creates commands
--   and keymaps.

local M = {}

local api = vim.api

local setup_done = false

---Jump and center.
---@param fn function Zero-arg jump to perform.
local function centered(fn)
    fn()
    vim.cmd('normal! zz')
end

---Diagnostic jump with count and severity filter.
---@param direction 1| -1
---@param severity vim.diagnostic.Severity?|nil
function M.diag_jump(direction, severity)
    local count = vim.v.count1
    for _ = 1, count do
        centered(function()
            vim.diagnostic.jump({
                count = direction,
                severity = severity,
                float = false,
            })
        end)
    end
end

---Quickfix / location-list jump with count and wrap.
---@param list 'qf'|'loc'
---@param direction 1| -1
function M.list_jump(list, direction)
    local count = vim.v.count1
    local cmd = list == 'qf' and (direction > 0 and 'cnext' or 'cprev') or (direction > 0 and 'lnext' or 'lprev')
    for _ = 1, count do
        local ok = pcall(function()
            vim.cmd('silent! ' .. cmd)
        end)
        if not ok then
            break
        end
        vim.cmd('normal! zz')
    end
end

---Treesitter-aware method/function jump; falls back to [[ / ]].
---@param direction 1| -1
function M.method_jump(direction)
    local has_ts, ts_move = pcall(require, 'nvim-treesitter.textobjects.move')
    if has_ts and ts_move ~= nil then
        local ok = pcall(ts_move.goto_next_start or ts_move.goto_previous_start, '@function.outer')
        if ok then
            vim.cmd('normal! zz')
            return
        end
    end
    -- Fallback: section jumps.
    centered(function()
        vim.cmd('silent! normal! ' .. (direction > 0 and ']]' or '[['))
    end)
end

function M.setup()
    if setup_done then
        return
    end
    setup_done = true

    api.nvim_create_user_command('NavDiagNext', function()
        M.diag_jump(1)
    end, { desc = 'Next diagnostic (count-aware, centered)' })
    api.nvim_create_user_command('NavDiagPrev', function()
        M.diag_jump(-1)
    end, { desc = 'Previous diagnostic (count-aware, centered)' })
    api.nvim_create_user_command('NavErrorNext', function()
        M.diag_jump(1, vim.diagnostic.severity.ERROR)
    end, { desc = 'Next error diagnostic' })
    api.nvim_create_user_command('NavErrorPrev', function()
        M.diag_jump(-1, vim.diagnostic.severity.ERROR)
    end, { desc = 'Previous error diagnostic' })
    api.nvim_create_user_command('NavLocNext', function()
        M.list_jump('loc', 1)
    end, { desc = 'Next location-list entry' })
    api.nvim_create_user_command('NavLocPrev', function()
        M.list_jump('loc', -1)
    end, { desc = 'Previous location-list entry' })
    api.nvim_create_user_command('NavQfNext', function()
        M.list_jump('qf', 1)
    end, { desc = 'Next quickfix entry' })
    api.nvim_create_user_command('NavQfPrev', function()
        M.list_jump('qf', -1)
    end, { desc = 'Previous quickfix entry' })
    api.nvim_create_user_command('NavMethodNext', function()
        M.method_jump(1)
    end, { desc = 'Next method/function' })
    api.nvim_create_user_command('NavMethodPrev', function()
        M.method_jump(-1)
    end, { desc = 'Previous method/function' })

    -- Keymaps: ]d / [d diagnostics, ]e / [e errors, ]m / [m methods, ]q / [q quickfix.
    local map = vim.keymap.set
    map('n', ']d', function()
        M.diag_jump(1)
    end, { silent = true, desc = 'Next diagnostic' })
    map('n', '[d', function()
        M.diag_jump(-1)
    end, { silent = true, desc = 'Previous diagnostic' })
    map('n', ']e', function()
        M.diag_jump(1, vim.diagnostic.severity.ERROR)
    end, { silent = true, desc = 'Next error' })
    map('n', '[e', function()
        M.diag_jump(-1, vim.diagnostic.severity.ERROR)
    end, { silent = true, desc = 'Previous error' })
    map('n', ']m', function()
        M.method_jump(1)
    end, { silent = true, desc = 'Next method' })
    map('n', '[m', function()
        M.method_jump(-1)
    end, { silent = true, desc = 'Previous method' })
    map('n', ']q', function()
        M.list_jump('qf', 1)
    end, { silent = true, desc = 'Next quickfix' })
    map('n', '[q', function()
        M.list_jump('qf', -1)
    end, { silent = true, desc = 'Previous quickfix' })
end

return M
