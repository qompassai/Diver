-- /qompassai/lua/diver/utils/ux/transparency.lua
-- Qompass AI Diver Transparency Utility
---@module 'config.ui.transparency'
local M = {}

local augroup = vim.api.nvim_create_augroup('UtilsTransparency', { clear = true })

local default = {
    auto = true,
    excludes = {},
    extra_groups = {},
    groups = {
        'Comment',
        'Conditional',
        'Constant',
        'CursorLine',
        'CursorLineNr',
        'EndOfBuffer',
        'FloatBorder',
        'FoldColumn',
        'Function',
        'Identifier',
        'LineNr',
        'NonText',
        'Normal',
        'NormalFloat',
        'NormalNC',
        'Operator',
        'Pmenu',
        'PreProc',
        'Repeat',
        'SignColumn',
        'Special',
        'Statement',
        'StatusLine',
        'StatusLineNC',
        'String',
        'Structure',
        'Todo',
        'Type',
        'Underlined',
        'VertSplit',
    },
    keymaps = {
        disable = '<leader>ub',
        enable = '<leader>uT',
        toggle = '<leader>ut',
    },
}
M.config = vim.deepcopy(default)
M.state = {
    enabled = true,
}
local function considerable(name)
    if vim.tbl_contains(M.config.excludes, name) then
        return false
    end
    if vim.tbl_contains(M.config.groups, name) then
        return true
    end
    if vim.tbl_contains(M.config.extra_groups, name) then
        return true
    end
    return false
end
local function clear_backgrounds()
    if not M.state.enabled then
        return
    end
    for name, attrs in pairs(vim.api.nvim_get_hl(0, {})) do
        if considerable(name) and (attrs.bg or attrs.ctermbg) then
            local new_attr = vim.tbl_extend('force', attrs, {
                bg = 'NONE',
                ctermbg = 'NONE',
            })
            vim.api.nvim_set_hl(0, name, new_attr)
        end
    end
end
local function set_commands()
    vim.api.nvim_create_user_command('TransparentDisable', M.disable, { desc = 'Disable transparent background' })
    vim.api.nvim_create_user_command('TransparentEnable', M.enable, { desc = 'Enable transparent background' })
    vim.api.nvim_create_user_command('TransparentToggle', M.toggle, { desc = 'Toggle transparent background' })
end
local function set_keymaps()
    local km = M.config.keymaps or {}
    if km.disable then
        vim.keymap.set('n', km.disable, M.disable, {
            desc = 'Disable transparency',
        })
    end
    if km.enable then
        vim.keymap.set('n', km.enable, M.enable, {
            desc = 'Enable transparency',
        })
    end
    if km.toggle then
        vim.keymap.set('n', km.toggle, M.toggle, {
            desc = 'Toggle transparency',
        })
    end
end

function M.disable()
    if not M.state.enabled then
        return
    end
    M.state.enabled = false
    if vim.g.colors_name then
        vim.cmd('colorscheme ' .. vim.g.colors_name)
    end
end
function M.enable()
    if M.state.enabled then
        return
    end
    M.state.enabled = true
    clear_backgrounds()
end
function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', vim.deepcopy(default), opts or {})

    set_commands()
    set_keymaps()

    if M.config.auto then
        vim.api.nvim_create_autocmd({
            'ColorScheme',
            'UIEnter',
        }, {
            group = augroup,
            desc = 'Clear background colors',
            callback = clear_backgrounds,
        })
        clear_backgrounds()
    end
end

function M.toggle()
    if M.state.enabled then
        M.disable()
    else
        M.enable()
    end
end
return M
