-- /qompassai/Diver/lua/utils/explorer.lua
-- Qompass AI Native File Explorer with LSP Symbols
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local levels = vim.log.levels
local map = vim.keymap.set
local notify = vim.notify
local uv = vim.uv or vim.loop
local build_file_tree
local build_symbol_tree
local create_dir
local create_file
local delete_item
local get_current_item
local get_dir_contents
local get_document_symbols
local get_git_status
local get_kind_name
--local is_dir
local jump_to_symbol
local open_file
local rename_item
local render
local setup_keymaps
local toggle_mode
local toggle_node
M.config = {
    git_status = true,
    icons = {
        file = '',
        folder_closed = '',
        folder_open = '',
        git_added = '✚',
        git_deleted = '✖',
        git_modified = '',
        git_renamed = '󰁕',
        git_untracked = '',
        symlink = '',
    },
    kinds = {
        Array = {
            icon = '󰅪',
            hl = 'Type',
        },
        Boolean = {
            icon = '',
            hl = 'Boolean',
        },
        Class = {
            icon = '󰌗',
            hl = 'Include',
        },
        Constant = {
            icon = '',
            hl = 'Constant',
        },
        Constructor = {
            icon = '',
            hl = '@constructor',
        },
        Enum = {
            icon = '󰒻',
            hl = '@number',
        },
        EnumMember = {
            icon = '',
            hl = 'Number',
        },
        Event = {
            icon = '',
            hl = 'Constant',
        },
        Field = {
            icon = '',
            hl = '@field',
        },
        File = {
            icon = '󰈙',
            hl = 'Tag',
        },
        Function = {
            icon = '󰊕',
            hl = 'Function',
        },
        Interface = {
            icon = '',
            hl = 'Type',
        },
        Key = { icon = '󰌋', hl = 'Keyword' },
        Macro = { icon = '', hl = 'Macro' },
        Method = { icon = '', hl = 'Function' },
        Module = { icon = '', hl = 'Exception' },
        Namespace = { icon = '󰌗', hl = 'Include' },
        Null = { icon = '', hl = 'Constant' },
        Number = { icon = '󰎠', hl = 'Number' },
        Object = { icon = '󰅩', hl = 'Type' },
        Operator = { icon = '󰆕', hl = 'Operator' },
        Package = { icon = '󰏖', hl = 'Label' },
        Parameter = { icon = '', hl = '@parameter' },
        Property = { icon = '󰆧', hl = '@property' },
        Root = { icon = '', hl = 'Title' },
        StaticMethod = { icon = '󰠄', hl = 'Function' },
        String = { icon = '󰀬', hl = 'String' },
        Struct = { icon = '󰌗', hl = 'Type' },
        TypeAlias = { icon = '', hl = 'Type' },
        TypeParameter = { icon = '󰊄', hl = 'Type' },
        Unknown = { icon = '?', hl = 'Comment' },
        Variable = { icon = '', hl = '@variable' },
    },
    position = 'left',
    show_hidden = false,
    width = 40,
}

local state = {
    bufnr = nil,
    cursor = 1,
    cwd = nil,
    expanded = {},
    mode = 'files', -- 'files' or 'symbols'
    source_buf = nil,
    symbols = {},
    winnr = nil,
}

---Build file tree
---@param dir string
---@param indent? integer
---@return table
build_file_tree = function(dir, indent)
    indent = math.floor(indent or 0)
    local git_status = get_git_status(dir)
    local items = get_dir_contents(dir)
    local lines = {}

    for _, item in ipairs(items) do
        local git_icon = git_status[item.name] and M.config.icons['git_' .. git_status[item.name]] or ''
        local icon = item.icon
        local prefix = string.rep('  ', indent)
        table.insert(lines, {
            indent = indent,
            is_dir = item.is_dir,
            path = item.path,
            text = prefix .. icon .. ' ' .. item.name .. ' ' .. git_icon,
        })
        if item.is_dir and state.expanded[item.path] then
            icon = M.config.icons.folder_open
            local children = build_file_tree(item.path, indent + 1)
            vim.list_extend(lines, children)
        end
    end

    return lines
end

---Build symbol tree
---@param symbols table
---@param indent? integer
---@return table
build_symbol_tree = function(symbols, indent)
    indent = math.floor(indent or 0)
    local lines = {}
    for _, symbol in ipairs(symbols) do
        local kind_name = get_kind_name(symbol.kind)
        local kind_config = M.config.kinds[kind_name] or M.config.kinds.Unknown
        local prefix = string.rep('  ', indent)
        table.insert(lines, {
            hl = kind_config.hl,
            indent = indent,
            kind = kind_name,
            symbol = symbol,
            text = string.format('%s%s %s', prefix, kind_config.icon, symbol.name),
        })
        if symbol.children and state.expanded[symbol.name] then
            local children = build_symbol_tree(symbol.children, indent + 1)
            vim.list_extend(lines, children)
        end
    end

    return lines
end
create_dir = function()
    if state.mode == 'symbols' then
        return
    end
    local item = get_current_item()
    local dir = item and item.is_dir and item.path or state.cwd
    vim.ui.input({ prompt = 'New directory: ', default = dir .. '/' }, function(input)
        if not input then
            return
        end
        if uv.fs_mkdir(input, 493) then -- 493 = 0755
            notify('Created: ' .. input, levels.INFO)
            render()
        else
            notify('Failed to create: ' .. input, levels.ERROR)
        end
    end)
end
create_file = function()
    if state.mode == 'symbols' then
        return
    end
    local item = get_current_item()
    local dir = item and item.is_dir and item.path or state.cwd
    vim.ui.input({ prompt = 'New file: ', default = dir .. '/' }, function(input)
        if not input then
            return
        end
        local file = io.open(input, 'w')
        if file then
            file:close()
            notify('Created: ' .. input, levels.INFO)
            render()
        else
            notify('Failed to create: ' .. input, levels.ERROR)
        end
    end)
end
delete_item = function()
    if state.mode == 'symbols' then
        return
    end
    local item = get_current_item()
    if not item then
        return
    end
    vim.ui.input({ prompt = 'Delete ' .. item.name .. '? (y/n): ' }, function(input)
        if input ~= 'y' then
            return
        end
        local success = item.is_dir and fn.delete(item.path, 'rf') == 0 or fn.delete(item.path) == 0
        if success then
            notify('Deleted: ' .. item.name, levels.INFO)
            render()
        else
            notify('Failed to delete: ' .. item.name, levels.ERROR)
        end
    end)
end
get_current_item = function() ---@return table|nil
    local cursor = api.nvim_win_get_cursor(state.winnr)
    local line_num = cursor[1]

    local lines
    if state.mode == 'symbols' then
        lines = build_symbol_tree(state.symbols)
    else
        lines = build_file_tree(state.cwd)
    end

    return lines[line_num]
end

---@return table
get_dir_contents = function(dir) ---@param dir string
    local handle = uv.fs_scandir(dir)
    local items = {}
    if not handle then
        return items
    end
    while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then
            break
        end
        local is_directory = type == 'directory'
        local path = dir .. '/' .. name

        if M.config.show_hidden or not name:match('^%.') then
            table.insert(items, {
                icon = is_directory and M.config.icons.folder_closed or M.config.icons.file,
                is_dir = is_directory,
                name = name,
                path = path,
            })
        end
    end

    table.sort(items, function(a, b)
        if a.is_dir ~= b.is_dir then
            return a.is_dir
        end
        return a.name < b.name
    end)

    return items
end

get_document_symbols = function(bufnr) ---@param bufnr integer
    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, function(err, result, _, _)
        if err or not result then
            notify('No symbols found', levels.WARN)
            return
        end
        state.symbols = result
        if state.mode == 'symbols' then
            render()
        end
    end)
end

---Get git status for directory
---@param dir string
---@return table
get_git_status = function(dir)
    if not M.config.git_status then
        return {}
    end
    local result = fn.systemlist('git -C ' .. fn.shellescape(dir) .. ' status --porcelain 2>/dev/null')
    local status = {}
    for _, line in ipairs(result) do
        local file = line:sub(4)
        local flag = line:sub(1, 2)
        status[file] = flag
    end

    return status
end

---@return string
get_kind_name = function(kind) ---@param kind integer
    local kinds = {
        [1] = 'File',
        [2] = 'Module',
        [3] = 'Namespace',
        [4] = 'Package',
        [5] = 'Class',
        [6] = 'Method',
        [7] = 'Property',
        [8] = 'Field',
        [9] = 'Constructor',
        [10] = 'Enum',
        [11] = 'Interface',
        [12] = 'Function',
        [13] = 'Variable',
        [14] = 'Constant',
        [15] = 'String',
        [16] = 'Number',
        [17] = 'Boolean',
        [18] = 'Array',
        [19] = 'Object',
        [20] = 'Key',
        [21] = 'Null',
        [22] = 'EnumMember',
        [23] = 'Struct',
        [24] = 'Event',
        [25] = 'Operator',
        [26] = 'TypeParameter',
    }
    return kinds[kind] or 'Unknown'
end

---@param path string
---@return boolean
is_dir = function(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == 'directory' or false
end
jump_to_symbol = function()
    if state.mode ~= 'symbols' then
        return
    end
    local item = get_current_item()
    if not item or not item.symbol then
        return
    end
    local range = item.symbol.selectionRange or item.symbol.range
    if not range or not state.source_buf then
        return
    end
    local wins = fn.win_findbuf(state.source_buf)
    if #wins > 0 then
        api.nvim_set_current_win(wins[1])
    else
        cmd('wincmd p')
    end
    local pos = range.start
    api.nvim_win_set_cursor(0, { pos.line + 1, pos.character })
    cmd('normal! zz')
end
open_file = function(how)
    if state.mode == 'symbols' then
        jump_to_symbol()
        return
    end
    local item = get_current_item()
    if not item then
        return
    end
    if item.is_dir then
        toggle_node()
        return
    end
    M.close()
    if how == 'split' then
        cmd('split ' .. fn.fnameescape(item.path))
    elseif how == 'vsplit' then
        cmd('vsplit ' .. fn.fnameescape(item.path))
    elseif how == 'tab' then
        cmd('tabnew ' .. fn.fnameescape(item.path))
    else
        cmd('edit ' .. fn.fnameescape(item.path))
    end
end
rename_item = function()
    if state.mode == 'symbols' then
        return
    end
    local item = get_current_item()
    if not item then
        return
    end
    vim.ui.input({ prompt = 'Rename to: ', default = item.name }, function(input)
        if not input or input == item.name then
            return
        end
        local new_path = fn.fnamemodify(item.path, ':h') .. '/' .. input

        if uv.fs_rename(item.path, new_path) then
            notify('Renamed to: ' .. input, levels.INFO)
            render()
        else
            notify('Failed to rename: ' .. item.name, levels.ERROR)
        end
    end)
end
render = function()
    if not state.bufnr or not api.nvim_buf_is_valid(state.bufnr) then
        return
    end

    local highlights = {}
    local lines
    local text_lines = {}

    if state.mode == 'symbols' then
        lines = build_symbol_tree(state.symbols)
    else
        lines = build_file_tree(state.cwd)
    end

    for i, line in ipairs(lines) do
        table.insert(text_lines, line.text)
        if line.hl then
            table.insert(highlights, { hl_group = line.hl, line_num = i - 1 })
        end
    end

    vim.bo[state.bufnr].modifiable = true
    api.nvim_buf_set_lines(state.bufnr, 0, -1, false, text_lines)
    vim.bo[state.bufnr].modifiable = false

    -- Apply highlights
    local ns_id = api.nvim_create_namespace('explorer_symbols')
    api.nvim_buf_clear_namespace(state.bufnr, ns_id, 0, -1)

    for _, hl in ipairs(highlights) do
        api.nvim_buf_set_extmark(state.bufnr, ns_id, hl.line_num, 0, {
            end_col = 0,
            hl_group = hl.hl_group,
            line_hl_group = hl.hl_group,
        })
    end
    if state.cursor <= #text_lines then
        api.nvim_win_set_cursor(state.winnr, { state.cursor, 0 })
    end
end
setup_keymaps = function()
    local opts = {
        buffer = state.bufnr,
        nowait = true,
        silent = true,
    }
    map('n', '<CR>', open_file, opts)
    map('n', '<2-LeftMouse>', open_file, opts)
    map('n', '<Space>', toggle_node, opts)
    map('n', '?', function()
        notify(
            'Keymaps:\n'
                .. '<CR>/click: Open/Jump\n'
                .. '<Space>: Toggle\n'
                .. 's/v/t: Split/VSplit/Tab\n'
                .. 'a/A: New file/dir\n'
                .. 'd: Delete\n'
                .. 'r: Rename\n'
                .. 'S: Toggle Files/Symbols\n'
                .. 'H: Toggle hidden\n'
                .. 'R: Refresh\n'
                .. 'q: Close',
            levels.INFO
        )
    end, opts)
    map('n', 'a', create_file, opts)
    map('n', 'A', create_dir, opts)
    map('n', 'd', delete_item, opts)
    map('n', 'H', function()
        M.config.show_hidden = not M.config.show_hidden
        render()
    end, opts)
    map('n', 'q', M.close, opts)
    map('n', 'r', rename_item, opts)
    map('n', 'R', render, opts)
    map('n', 's', function()
        open_file('split')
    end, opts)
    map('n', 'S', toggle_mode, opts)
    map('n', 't', function()
        open_file('tab')
    end, opts)
    map('n', 'v', function()
        open_file('vsplit')
    end, opts)
end
toggle_node = function()
    local item = get_current_item()
    if not item then
        return
    end
    if state.mode == 'symbols' then
        if item.symbol and item.symbol.children then
            state.expanded[item.symbol.name] = not state.expanded[item.symbol.name]
            render()
        end
    else
        if item.is_dir then
            state.expanded[item.path] = not state.expanded[item.path]
            render()
        end
    end
end
toggle_mode = function()
    if state.mode == 'files' then
        state.mode = 'symbols'
        state.source_buf = fn.bufnr('#')
        get_document_symbols(state.source_buf)
    else
        state.mode = 'files'
        render()
    end
end
function M.close()
    if state.winnr and api.nvim_win_is_valid(state.winnr) then
        api.nvim_win_close(state.winnr, true)
    end
    state.bufnr = nil
    state.mode = 'files'
    state.winnr = nil
end

function M.create_commands()
    local ucmd = api.nvim_create_user_command
    ucmd('Explorer', M.toggle, {
        desc = 'Toggle file explorer',
    })
    ucmd('ExplorerClose', M.close, {
        desc = 'Close file explorer',
    })
    ucmd('ExplorerOpen', M.open, {
        desc = 'Open file explorer',
    })
end

function M.open()
    if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
        M.close()
        return
    end
    state.bufnr = api.nvim_create_buf(false, true)
    state.cwd = fn.getcwd()
    if M.config.position == 'left' then
        cmd('topleft vsplit')
        api.nvim_win_set_width(0, M.config.width)
    elseif M.config.position == 'right' then
        cmd('botright vsplit')
        api.nvim_win_set_width(0, M.config.width)
    else
        cmd('split')
    end
    state.winnr = api.nvim_get_current_win()
    api.nvim_win_set_buf(state.winnr, state.bufnr)
    vim.bo[state.bufnr].bufhidden = 'wipe'
    vim.bo[state.bufnr].buftype = 'nofile'
    vim.bo[state.bufnr].filetype = 'explorer'
    vim.bo[state.bufnr].swapfile = false
    api.nvim_buf_set_name(state.bufnr, 'Explorer: ' .. state.cwd)
    vim.wo[state.winnr].cursorline = true
    vim.wo[state.winnr].number = false
    vim.wo[state.winnr].relativenumber = false
    setup_keymaps()
    render()
end

---@param opts? table
function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

function M.toggle()
    if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
        M.close()
    else
        M.open()
    end
end

return M