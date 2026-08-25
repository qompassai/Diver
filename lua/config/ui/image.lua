#!/usr/bin/env lua

-- image.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
M.state = {
    enabled = false,
    win = nil,
    buf = nil,
    img = nil,
    path = nil,
}
local function has_img()
    return vim.ui and vim.ui.img ~= nil
end
local function is_image(path)
    return path and path:match('%.png$')
        or path and path:match('%.jpe?g$')
        or path and path:match('%.webp$')
        or path and path:match('%.gif$')
        or path and path:match('%.avif$')
        or path and path:match('%.svg$')
end
local function current_image_path()
    local path = vim.api.nvim_buf_get_name(0)
    if is_image(path) then
        return path
    end
    return nil
end

local function ensure_preview_window()
    if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
        return M.state.win
    end

    M.state.buf = vim.api.nvim_create_buf(false, true)

    local editor_w = vim.o.columns
    local editor_h = vim.o.lines - vim.o.cmdheight
    local width = math.floor(editor_w * 0.32)
    local height = math.floor(editor_h * 0.70)

    M.state.win = vim.api.nvim_open_win(M.state.buf, false, {
        relative = 'editor',
        row = 2,
        col = editor_w - width - 2,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' Image Preview ',
        title_pos = 'center',
        focusable = false,
        zindex = 60,
    })

    vim.api.nvim_set_option_value('winblend', 0, {
        win = M.state.win,
    })
    return M.state.win
end
local function clear_image()
    if M.state.img then
        pcall(function()
            M.state.img:clear()
        end)
        M.state.img = nil
    end
end

local function close_preview_window()
    clear_image()
    if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
        pcall(vim.api.nvim_win_close, M.state.win, true)
    end
    M.state.win = nil
    M.state.buf = nil
    M.state.path = nil
end

function M.render(path)
    if not has_img() then
        vim.notify('vim.ui.img not available in this Neovim build', vim.log.levels.WARN)
        return
    end
    path = path or current_image_path()
    if not path or not is_image(path) then
        return
    end
    local win = ensure_preview_window()
    clear_image()
    local ok, img = pcall(vim.ui.img.open, path)
    if not ok or not img then
        vim.notify('Failed to open image: ' .. path, vim.log.levels.ERROR)
        return
    end
    M.state.img = img
    M.state.path = path
    pcall(function()
        img:show({ win = win })
    end)
end

function M.refresh()
    if not M.state.enabled then
        return
    end
    local path = current_image_path()
    if not path then
        clear_image()
        return
    end
    if path ~= M.state.path then
        M.render(path)
    end
end

function M.toggle()
    M.state.enabled = not M.state.enabled
    if not M.state.enabled then
        close_preview_window()
        return
    end
    M.refresh()
end

vim.api.nvim_create_user_command('ImagePreviewToggle', function()
    M.toggle()
end, {})

vim.api.nvim_create_user_command('ImagePreviewRefresh', function()
    M.refresh()
end, {})

vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    callback = function()
        M.refresh()
    end,
})

vim.api.nvim_create_autocmd('VimResized', {
    callback = function()
        if M.state.enabled then
            close_preview_window()
            M.refresh()
        end
    end,
})

return M
