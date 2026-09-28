-- General editing and native directory browsing, independent of LSP attachment.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local core = require('config.mappings._core')
local M = {}
local OWNER = 'genmap'

local function buffers()
    local items = {}
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if vim.bo[bufnr].buflisted then
            local name = api.nvim_buf_get_name(bufnr)
            items[#items + 1] = {
                label = name ~= '' and name or ('[No name] ' .. bufnr),
                run = function()
                    if api.nvim_buf_is_valid(bufnr) then
                        api.nvim_set_current_buf(bufnr)
                    end
                end,
            }
        end
    end
    core.select(api.nvim_get_current_buf(), items, 'Buffers')
end

local function directory()
    local win = api.nvim_get_current_win()
    vim.ui.input({ prompt = 'Window directory: ', default = vim.fn.getcwd(), completion = 'dir' }, function(path)
        if not path or path == '' or not api.nvim_win_is_valid(win) then
            return
        end
        path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
        if vim.fn.isdirectory(path) ~= 1 then
            core.notify('Directory does not exist: ' .. path)
            return
        end
        api.nvim_win_call(win, function()
            api.nvim_cmd({ cmd = 'lcd', args = { path }, magic = { file = false, bar = false } }, {})
        end)
    end)
end

local function completion(next_item, fallback)
    return function()
        if vim.fn.wildmenumode() == 1 or vim.fn.pumvisible() == 1 then
            return next_item
        end
        return fallback
    end
end

---Move toward the Neovim window in `direction`, falling through to the
---adjacent tmux pane at the window edge. A genuine tmux failure stays
---visible; anything else is a quiet no-op (floating window focused, or no
---window in that direction while outside tmux).
---@param direction string 'left'|'right'|'up'|'down'
local function tmux_aware_navigate(direction)
    local moved, note = require('utils.tmux').navigate(direction)
    if moved == nil then
        core.notify('tmux: navigation failed: ' .. tostring(note), vim.log.levels.ERROR)
    end
end

function M.setup()
    core.teardown(OWNER)
    core.install(OWNER, 0, {
        {
            lhs = '<C-h>',
            rhs = function()
                tmux_aware_navigate('left')
            end,
            desc = 'Window left (tmux pane at edge)',
        },
        {
            lhs = '<C-j>',
            rhs = function()
                tmux_aware_navigate('down')
            end,
            desc = 'Window below (tmux pane at edge)',
        },
        {
            lhs = '<C-j>',
            mode = 'c',
            expr = true,
            rhs = completion('<C-n>', '<C-j>'),
            desc = 'Next command completion',
        },
        {
            lhs = '<C-k>',
            rhs = function()
                tmux_aware_navigate('up')
            end,
            desc = 'Window above (tmux pane at edge)',
        },
        {
            lhs = '<C-k>',
            mode = 'c',
            expr = true,
            rhs = completion('<C-p>', '<C-k>'),
            desc = 'Previous command completion',
        },
        -- Displaces the builtin <C-L> (clear/redraw) so all four directions
        -- navigate symmetrically; redraw moves to <leader>L below.
        {
            lhs = '<C-l>',
            rhs = function()
                tmux_aware_navigate('right')
            end,
            desc = 'Window right (tmux pane at edge)',
            override = true,
        },
        -- The builtin <C-L> default (displaced above): nohlsearch,
        -- diffupdate, clear multicursors, then the unmapped <C-L>
        -- clear/redraw via normal!.
        {
            lhs = '<leader>L',
            rhs = '<Cmd>nohlsearch<Bar>diffupdate'
                .. '<Bar>call nvim_buf_clear_namespace(0, nvim_create_namespace("nvim.multicursor"), 0, -1)'
                .. '<Bar>normal! <C-L><CR>',
            desc = 'Clear and redraw screen',
        },
        {
            lhs = '<C-s>',
            rhs = '<Cmd>update<CR>',
            desc = 'Save changed buffer',
        },
        { lhs = '<Esc>', rhs = '<Cmd>nohlsearch<CR><Esc>', desc = 'Clear search highlight' },
        { lhs = '<Leader>bb', rhs = buffers, desc = 'Choose buffer' },
        { lhs = '<Leader>bd', rhs = '<Cmd>bdelete<CR>', desc = 'Close buffer without force' },
        { lhs = '<Leader>cd', rhs = directory, desc = 'Change window directory' },
        {
            lhs = '<Leader>e',
            rhs = function()
                local count = vim.v.count > 0 and tostring(vim.v.count) or ''
                local keys = api.nvim_replace_termcodes(count .. '<Plug>(nvim-dir-up)', true, false, true)
                api.nvim_feedkeys(keys, 'm', false)
            end,
            desc = 'Browse parent directory (native dir)',
        },
        { lhs = '<Leader>ff', rhs = ':find ', desc = 'Find file using path and wildmenu' },
        { lhs = '<Leader>fh', rhs = ':help ', desc = 'Find help' },
        { lhs = '<Leader>fo', rhs = '<Cmd>browse oldfiles<CR>', desc = 'Choose recent file' },
        { lhs = '<Leader>gh', rhs = '<Cmd>checkhealth<CR>', desc = 'Native health checks' },
        { lhs = '<Leader>mi', rhs = core.report, desc = 'Mapping conflict report' },
        {
            lhs = '<Leader>pu',
            rhs = function()
                vim.pack.update()
            end,
            desc = 'Review package updates',
        },
        { lhs = '<Leader>ya', rhs = '<Cmd>%yank +<CR>', desc = 'Copy buffer to clipboard' },
    })
end

function M.teardown()
    core.teardown(OWNER)
end
M.setup_genmap = M.setup
return M
