-- padding.lua
-- Qompass AI Diver UI Padding Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local ns = vim.api.nvim_create_namespace('SoftPadding')
local ns2 = vim.api.nvim_create_namespace('DensePadding')
local function enable_soft_padding(bufnr)
    bufnr = bufnr or 0
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local last = vim.api.nvim_buf_line_count(bufnr)
    for lnum = 0, last - 1 do
        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
            virt_lines = { { { ' ', 'Normal' } } },
            virt_lines_above = false,
        })
    end
end
local function pad_dense_regions(bufnr)
    bufnr = bufnr or 0
    vim.api.nvim_buf_clear_namespace(bufnr, ns2, 0, -1)

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local threshold = 100
    local run_min = 3

    local run_start = nil
    for i, line in ipairs(lines) do
        if #line >= threshold then
            run_start = run_start or i
        else
            if run_start and i - run_start >= run_min then
                for l = run_start - 1, i - 2 do
                    vim.api.nvim_buf_set_extmark(bufnr, ns2, l, 0, {
                        virt_lines = { { { ' ', 'Normal' } } },
                        virt_lines_above = false,
                    })
                end
            end
            run_start = nil
        end
    end
end
local enabled = false
local mode = 'soft' --- "soft" | "dense"
function M.toggle(mode_arg)
    if mode_arg == 'soft' or mode_arg == 'dense' then
        mode = mode_arg
    end
    enabled = not enabled
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, ns2, 0, -1)
    if not enabled then
        return
    end
    if mode == 'soft' then
        enable_soft_padding(bufnr)
    else
        pad_dense_regions(bufnr)
    end
end

function M.refresh(bufnr)
    if not enabled then
        return
    end
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, ns2, 0, -1)
    if mode == 'soft' then
        enable_soft_padding(bufnr)
    else
        pad_dense_regions(bufnr)
    end
end

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'TextChanged', 'TextChangedI' }, {
    group = vim.api.nvim_create_augroup('SoftPaddingAuto', { clear = true }),
    callback = function(args)
        M.refresh(args.buf)
    end,
})
return M