-- /qompassai/Diver/lua/config/markdown/render.lua
-- Qompass AI Diver Markdown Decorations
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Native extmark decorations. Image rendering is delegated to config.ui.image,
-- which uses vim.ui.img and has no image.nvim dependency.

local M = {}
local namespace = vim.api.nvim_create_namespace('markdown_render')

local function clear(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

---@param bufnr integer
---@return vim.treesitter.LanguageTree?
local function parser_for(bufnr)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'markdown')
    return ok and parser or nil
end

---@param bufnr integer
local function refresh_image(bufnr)
    local ok, image = pcall(require, 'config.ui.image')
    if ok and type(image.refresh) == 'function' and vim.api.nvim_get_current_buf() == bufnr then
        image.refresh()
    end
end

---@param bufnr integer
local function render(bufnr)
    clear(bufnr)

    local parser = parser_for(bufnr)
    if not parser then
        refresh_image(bufnr)
        return
    end

    local parsed_ok, trees = pcall(parser.parse, parser)
    local tree = parsed_ok and trees and trees[1] or nil
    if not tree then
        refresh_image(bufnr)
        return
    end

    local query_ok, query = pcall(
        vim.treesitter.query.parse,
        'markdown',
        [[
    (atx_heading) @heading
    (setext_heading) @heading
    (task_list_marker_unchecked) @checkbox_unchecked
    (task_list_marker_checked) @checkbox_checked
    (image) @image
  ]]
    )
    if not query_ok then
        refresh_image(bufnr)
        return
    end

    for id, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
        local capture = query.captures[id]
        local row, column, end_row, end_column = node:range()

        if capture == 'heading' then
            local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
            local hashes = line:match('^(#+)')
            local level = hashes and #hashes or 1

            vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
                virt_text = { { string.rep('▌', level) .. ' ', 'Title' } },
                virt_text_pos = 'overlay',
            })

            vim.api.nvim_buf_set_extmark(bufnr, namespace, end_row, 0, {
                virt_lines = { { { string.rep('─', math.max(10, #line)), 'Comment' } } },
            })
        elseif capture == 'checkbox_unchecked' or capture == 'checkbox_checked' then
            local icon = capture == 'checkbox_checked' and ' ' or ' '
            vim.api.nvim_buf_set_extmark(bufnr, namespace, row, column, {
                end_col = end_column,
                virt_text = { { icon, 'Identifier' } },
                virt_text_pos = 'overlay',
            })
        elseif capture == 'image' then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, row, column, {
                virt_text = { { '🖼 ', 'Special' } },
                virt_text_pos = 'overlay',
            })
        end
    end

    refresh_image(bufnr)
end

---@param bufnr integer
local function attach(bufnr)
    local group = vim.api.nvim_create_augroup('MarkdownRender' .. bufnr, { clear = true })

    vim.api.nvim_create_autocmd({
        'BufEnter',
        'CursorMoved',
        'InsertLeave',
        'TextChanged',
    }, {
        buffer = bufnr,
        group = group,
        callback = function(args)
            render(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd('BufWipeout', {
        buffer = bufnr,
        group = group,
        callback = function(args)
            clear(args.buf)
            local ok, image = pcall(require, 'config.ui.image')
            if ok and type(image.clear) == 'function' then
                image.clear()
            end
        end,
    })

    render(bufnr)
end

function M.enable()
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.bo[bufnr].filetype
    if filetype == 'markdown' or filetype == 'markdown.mdx' then
        attach(bufnr)
    end
end

function M.disable()
    local bufnr = vim.api.nvim_get_current_buf()
    pcall(vim.api.nvim_del_augroup_by_name, 'MarkdownRender' .. bufnr)
    clear(bufnr)

    local ok, image = pcall(require, 'config.ui.image')
    if ok and type(image.clear) == 'function' then
        image.clear()
    end
end

function M.toggle()
    local bufnr = vim.api.nvim_get_current_buf()
    local group = 'MarkdownRender' .. bufnr
    local attached = #vim.api.nvim_get_autocmds({ group = group }) > 0
    if attached then
        M.disable()
    else
        M.enable()
    end
end

return M
