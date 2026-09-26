-- #################################################################
-- /qompassai/Diver/lua/refactor/init.lua
-- Native Neovim 0.13+ refactor facade
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

local core = require('refactor.core')
local debug = require('refactor.debug')
local lsp = require('refactor.lsp')

local M = {}

local configured = false

---@class refactor.Config
---@field commands? boolean
---@field debug? refactor.DebugConfig

---@param name string
---@param visual? boolean
---@param strict_title? boolean
local function refactor(name, visual, strict_title)
    local bufnr = vim.api.nvim_get_current_buf()

    lsp.run(name, {
        bufnr = bufnr,
        range = visual and core.visual_lsp_range(bufnr) or nil,
        strict_title = strict_title,
    })
end

local function create_commands()
    vim.api.nvim_create_user_command('Refactor', function(args)
        local name = args.fargs[1]
        local ranged = args.range > 0
        local range = nil

        if ranged then
            local last = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1] or ''
            range = {
                start = { args.line1, 0 },
                ['end'] = { args.line2, #last },
            }
        end

        lsp.run(name, {
            bufnr = 0,
            range = range,
            strict_title = not args.bang,
        })
    end, {
        bang = true,
        desc = 'Native LSP refactor',
        nargs = 1,
        range = true,
        complete = function()
            return {
                'extract',
                'extract_var',
                'extract_func',
                'inline',
                'inline_var',
                'inline_func',
                'rewrite',
                'refactor',
            }
        end,
        force = true,
    })

    vim.api.nvim_create_user_command('RefactorDebug', function(args)
        local name = args.fargs[1]
        local ranged = args.range > 0
        local range = ranged and core.line_range(0, args.line1, args.line2) or nil

        if name == 'print_loc' then
            debug.print_loc({ range = range })
        elseif name == 'print_exp' then
            debug.print_exp({ range = range })
        elseif name == 'print_var' then
            debug.print_var({ range = range })
        elseif name == 'cleanup' then
            debug.cleanup({ range = range })
        else
            core.notify(('unknown debug action: %s'):format(name), vim.log.levels.ERROR)
        end
    end, {
        desc = 'Native print-debug action',
        nargs = 1,
        range = true,
        complete = function()
            return {
                'print_loc',
                'print_exp',
                'print_var',
                'cleanup',
            }
        end,
        force = true,
    })
end

---@param opts? refactor.Config
---@return table
function M.setup(opts)
    core.require_nvim_013()

    opts = opts or {}
    vim.validate('opts', opts, 'table')

    debug.setup(opts.debug)

    if opts.commands ~= false then
        create_commands()
    end

    configured = true
    return M
end

local function ensure_setup()
    if not configured then
        M.setup()
    end
end

---@param opts? {visual?: boolean}
function M.extract(opts)
    ensure_setup()
    refactor('extract', opts and opts.visual, false)
end

---@param opts? {visual?: boolean}
function M.extract_var(opts)
    ensure_setup()
    refactor('extract_var', opts and opts.visual, true)
end

---@param opts? {visual?: boolean}
function M.extract_func(opts)
    ensure_setup()
    refactor('extract_func', opts and opts.visual, true)
end

function M.inline()
    ensure_setup()
    refactor('inline', false, false)
end

function M.inline_var()
    ensure_setup()
    refactor('inline_var', false, true)
end

function M.inline_func()
    ensure_setup()
    refactor('inline_func', false, true)
end

function M.rewrite()
    ensure_setup()
    refactor('rewrite', false, false)
end

function M.code_action()
    ensure_setup()
    refactor('refactor', false, false)
end

function M.rename()
    ensure_setup()
    lsp.rename()
end

---@param opts? refactor.DebugOpts
function M.print_loc(opts)
    ensure_setup()
    debug.print_loc(opts)
end

---@param opts? refactor.DebugOpts
function M.print_exp(opts)
    ensure_setup()
    debug.print_exp(opts)
end

---@param opts? refactor.DebugOpts
function M.print_var(opts)
    ensure_setup()
    debug.print_var(opts)
end

---@param opts? refactor.CleanupOpts
function M.cleanup(opts)
    ensure_setup()
    debug.cleanup(opts)
end

return M
