--- Native floating command-line (no plugins).
---
--- Emulates noice.nvim's centered cmdline_popup using vim.ui_attach
--- with ext_cmdline. Based on observed noice behavior:
--- - relative='editor', centered, width=52, height=1
--- - border='rounded', style='minimal', noautocmd=true
--- - NO zindex (noice doesn't set it for the popup)
--- - Buffer: buftype='nofile'
--- - Window: wrap=false, foldenable=false

local M = {}

local win = nil
local buf = nil
local ns_id = nil
local attached = false

-- Popupmenu state
local pum_win = nil
local pum_buf = nil
local pum_selected = -1

--- Hide the floating cmdline window
local function hide()
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    win = nil
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
    end
    buf = nil
    -- Also hide popupmenu
    if pum_win ~= nil and vim.api.nvim_win_is_valid(pum_win) then
        vim.api.nvim_win_close(pum_win, true)
    end
    pum_win = nil
    if pum_buf ~= nil and vim.api.nvim_buf_is_valid(pum_buf) then
        vim.api.nvim_buf_delete(pum_buf, { force = true })
    end
    pum_buf = nil
    pum_selected = -1
end

--- Show the floating cmdline window with the given text
---@param text string The cmdline text to display
local function show(text)
    hide()

    -- Create buffer (like nui.nvim does)
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buftype = 'nofile'

    -- Get editor dimensions
    local ui = vim.api.nvim_list_uis()[1]
    local editor_width = ui and ui.width or vim.o.columns
    local editor_height = ui and ui.height or vim.o.lines

    -- Centered position (matches noice's 52x1 at 13,17 in 87x27)
    local width = math.min(math.floor(editor_width * 0.6), 80)
    local height = 1
    local row = math.floor((editor_height - height) / 2)
    local col = math.floor((editor_width - width) / 2)

    -- Create window with noice's exact parameters (no zindex!)
    local ok, result = pcall(vim.api.nvim_open_win, buf, false, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        noautocmd = true,
    })
    if not ok then
        vim.notify('Native cmdline float failed: ' .. tostring(result), vim.log.levels.ERROR)
        return
    end
    win = result

    -- Set window options (like nui.nvim does)
    vim.wo[win].wrap = false
    vim.wo[win].foldenable = false
    vim.wo[win].cursorline = false
    vim.wo[win].scrolloff = 0
    vim.wo[win].sidescrolloff = 0

    if text ~= nil and text ~= '' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
    end

    -- Force UI redraw (like noice does) - critical for Foot terminal
    -- Without this, the window is created but not visible
    if vim.api.nvim__redraw ~= nil then
        pcall(vim.api.nvim__redraw, { win = win, flush = true })
    end
end

--- Update the floating cmdline content
---@param text string
local function update(text)
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text or '' })
    -- Force redraw on content update (like noice does)
    if win ~= nil and vim.api.nvim_win_is_valid(win) and vim.api.nvim__redraw ~= nil then
        pcall(vim.api.nvim__redraw, { win = win, flush = true })
    end
end

--- Convert cmdline_show content to text
local function content_to_text(content, firstc)
    local parts = { firstc or '' }
    if content ~= nil then
        for _, chunk in ipairs(content) do
            if type(chunk) == 'table' and chunk[2] ~= nil then
                parts[#parts + 1] = chunk[2]
            end
        end
    end
    return table.concat(parts, '')
end

--- Show the completion popupmenu below the cmdline float
---@param items table List of [word, kind, menu, info] tuples
---@param selected number Index of selected item (0-based, -1 for none)
local function pum_show(items, selected)
    -- Hide existing popupmenu
    if pum_win ~= nil and vim.api.nvim_win_is_valid(pum_win) then
        vim.api.nvim_win_close(pum_win, true)
    end
    if pum_buf ~= nil and vim.api.nvim_buf_is_valid(pum_buf) then
        vim.api.nvim_buf_delete(pum_buf, { force = true })
    end

    if items == nil or #items == 0 then
        pum_win = nil
        pum_buf = nil
        return
    end

    pum_selected = selected or -1

    -- Create buffer with completion items
    pum_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[pum_buf].bufhidden = 'wipe'
    vim.bo[pum_buf].buftype = 'nofile'

    local lines = {}
    local max_width = 0
    for _, item in ipairs(items) do
        local word = type(item) == 'table' and item[1] or tostring(item)
        lines[#lines + 1] = word
        if #word > max_width then
            max_width = #word
        end
    end
    vim.api.nvim_buf_set_lines(pum_buf, 0, -1, false, lines)

    -- Position below the cmdline float (if it exists)
    local ui = vim.api.nvim_list_uis()[1]
    local editor_width = ui and ui.width or vim.o.columns
    local editor_height = ui and ui.height or vim.o.lines

    local pum_width = math.min(max_width + 2, 40)
    local pum_height = math.min(#lines, 10)
    local pum_row, pum_col

    if win ~= nil and vim.api.nvim_win_is_valid(win) then
        local pos = vim.api.nvim_win_get_position(win)
        -- Position below the cmdline, aligned left
        pum_row = pos[1] + 3 -- cmdline height (1) + border (2)
        pum_col = pos[2]
    else
        -- Fallback: center below
        pum_row = math.floor(editor_height / 2) + 2
        pum_col = math.floor((editor_width - pum_width) / 2)
    end

    -- Ensure popupmenu stays on screen
    if pum_row + pum_height > editor_height then
        pum_row = editor_height - pum_height - 1
    end
    if pum_col + pum_width > editor_width then
        pum_col = editor_width - pum_width - 1
    end

    local ok, result = pcall(vim.api.nvim_open_win, pum_buf, false, {
        relative = 'editor',
        width = pum_width,
        height = pum_height,
        row = math.max(0, pum_row),
        col = math.max(0, pum_col),
        style = 'minimal',
        border = 'rounded',
        noautocmd = true,
    })
    if not ok then
        return
    end
    pum_win = result
    vim.wo[pum_win].wrap = false
    vim.wo[pum_win].cursorline = true

    -- Highlight selected item
    if pum_selected >= 0 and pum_selected < #lines then
        vim.api.nvim_buf_add_highlight(pum_buf, -1, 'PmenuSel', pum_selected, 0, -1)
    end

    if vim.api.nvim__redraw ~= nil then
        pcall(vim.api.nvim__redraw, { win = pum_win, flush = true })
    end
end

--- Hide the completion popupmenu
local function pum_hide()
    if pum_win ~= nil and vim.api.nvim_win_is_valid(pum_win) then
        vim.api.nvim_win_close(pum_win, true)
    end
    pum_win = nil
    if pum_buf ~= nil and vim.api.nvim_buf_is_valid(pum_buf) then
        vim.api.nvim_buf_delete(pum_buf, { force = true })
    end
    pum_buf = nil
    pum_selected = -1
end

--- Update popupmenu selection highlight
---@param selected number Index of selected item (0-based, -1 for none)
local function pum_select(selected)
    if pum_buf == nil or not vim.api.nvim_buf_is_valid(pum_buf) then
        return
    end
    pum_selected = selected or -1
    -- Clear existing highlights
    vim.api.nvim_buf_clear_namespace(pum_buf, -1, 0, -1)
    -- Highlight selected
    if pum_selected >= 0 then
        vim.api.nvim_buf_add_highlight(pum_buf, -1, 'PmenuSel', pum_selected, 0, -1)
    end
    if pum_win ~= nil and vim.api.nvim_win_is_valid(pum_win) and vim.api.nvim__redraw ~= nil then
        pcall(vim.api.nvim__redraw, { win = pum_win, flush = true })
    end
end

--- UI event handler
local function on_event(event, ...)
    if event == 'cmdline_show' then
        local content, _, firstc = ...
        local text = content_to_text(content, firstc)
        if win == nil or not vim.api.nvim_win_is_valid(win) then
            local ok, err = pcall(show, text)
            if not ok then
                vim.notify('Cmdline show failed: ' .. tostring(err), vim.log.levels.ERROR)
            end
        else
            update(text)
        end
        return true
    elseif event == 'cmdline_hide' then
        hide()
        return true
    elseif event == 'popupmenu_show' then
        local items, selected = ...
        pcall(pum_show, items, selected)
        return true
    elseif event == 'popupmenu_hide' then
        pum_hide()
        return true
    elseif event == 'popupmenu_select' then
        local selected = ...
        pcall(pum_select, selected)
        return true
    end
    return nil
end

--- Trigger command-line completion popup as-you-type (native, no plugin).
local function maybe_trigger_completion()
    if vim.fn.getcmdtype() ~= ':' then
        return
    end
    if vim.fn.pumvisible() == 1 then
        return
    end
    if #vim.fn.getcmdline() >= 1 then
        vim.fn.wildtrigger()
    end
end

--- Perform the actual vim.ui_attach (deferred to avoid startup flicker).
---@return boolean ok
---@return string|nil err
local function do_attach()
    if attached then
        return true, nil
    end
    ns_id = vim.api.nvim_create_namespace('DiverNativeCmdline')
    local ok, err = pcall(vim.ui_attach, ns_id, { ext_cmdline = true, ext_popupmenu = true }, on_event)
    if not ok then
        vim.notify('Native cmdline ui_attach failed: ' .. tostring(err), vim.log.levels.ERROR)
        return false, tostring(err)
    end
    attached = true
    return true, nil
end

--- Setup the native floating cmdline.
--- Defers vim.ui_attach to VimEnter to avoid startup flicker.
---@return boolean ok True if setup initiated
---@return string|nil err Error message on failure
function M.setup()
    if attached then
        return true, nil
    end

    -- Trigger completion as-you-type via CmdlineChanged autocmd (no UI change, safe at startup)
    local group = vim.api.nvim_create_augroup('DiverNativeCmdlineWild', { clear = true })
    vim.api.nvim_create_autocmd('CmdlineChanged', {
        group = group,
        callback = function()
            maybe_trigger_completion()
        end,
    })

    -- Defer ui_attach until after startup to avoid flicker
    -- Defer ui_attach until UI is ready to avoid flicker
    -- UIEnter fires when the UI attaches; vim.schedule ensures we run after the initial draw completes
    vim.api.nvim_create_autocmd('UIEnter', {
        once = true,
        callback = function()
            vim.schedule(do_attach)
        end,
    })

    return true, nil
end

--- Teardown the native floating cmdline (for switching back to noice).
--- Idempotent: safe to call multiple times.
function M.teardown()
    if attached and ns_id ~= nil then
        pcall(vim.ui_detach, ns_id)
        attached = false
        ns_id = nil
    end
    pcall(vim.api.nvim_del_augroup_by_name, 'DiverNativeCmdlineWild')
    -- selene: allow(global_usage)
    local attach_timer = _G._diver_cmdline_attach_timer
    if attach_timer ~= nil then
        pcall(vim.fn.timer_stop, attach_timer)
        -- selene: allow(global_usage)
        _G._diver_cmdline_attach_timer = nil
    end
    hide()
    pum_hide()
end

return M
