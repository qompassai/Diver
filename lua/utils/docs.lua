-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Doc Utils Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local b = vim.b
local bo = vim.bo
local fn = vim.fn
local tree = vim.treesitter
local v = vim.v
function M.foldexpr()
    local buf = api.nvim_get_current_buf()
    if b[buf].ts_folds == nil then
        if bo[buf].filetype == '' then
            return '0'
        end
        if bo[buf].filetype:find('dashboard') then
            b[buf].ts_folds = false
        else
            b[buf].ts_folds = pcall(tree.get_parser, buf)
        end
    end
    return b[buf].ts_folds and tree.foldexpr() or '0'
end

function M.foldtext()
    return api.nvim_buf_get_lines(0, v.lnum - 1, v.lnum, false)[1]
end

---@return string
local function get_relative_path(filepath) ---@param filepath string
    local qompass_idx = filepath:find('/qompassai/')
    if qompass_idx then
        return filepath:sub(qompass_idx + 1)
    else
        local rel = fn.fnamemodify(filepath, ':~:.')
        return rel
    end
end
api.nvim_create_user_command('Align', function(opts)
    local start_line = opts.line1
    local end_line = opts.line2
    for lnum = start_line, end_line do
        local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
        local annotation, description = line:match('^(%s*%-%-%-@%S+%s+%S+)%s+(.*)$')
        if annotation and description then
            local aligned = string.format('%-58s %s', annotation, description)
            vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, {
                aligned,
            })
        end
    end
end, {
    range = true,
})

---@param filepath string
---@param comment string
---@return string[]
function M.make_header(filepath, comment)
    local relpath = get_relative_path(filepath)
    local description = 'Qompass AI - [ ]'
    local copyright = 'Copyright (C) 2026 Qompass AI, All rights reserved'
    local solid ---@type string
    if comment == '<!--' then
        solid = '<!-- ' .. string.rep('-', 40) .. ' -->'
        return {
            '<!-- ' .. relpath .. ' -->',
            '<!-- ' .. description .. ' -->',
            '<!-- ' .. copyright .. ' -->',
            solid,
        }
    elseif comment == '/*' then
        solid = '/* ' .. string.rep('-', 40) .. ' */'
        return {
            '/* ' .. relpath .. ' */',
            '/* ' .. description .. ' */',
            '/* ' .. copyright .. ' */',
            solid,
        }
    else
        solid = comment .. ' ' .. string.rep('-', 40)
        return {
            comment .. ' ' .. relpath,
            comment .. ' ' .. description,
            comment .. ' ' .. copyright,
            solid,
        }
    end
end

M = M or {}
api.nvim_create_autocmd('CmdlineChanged', {
    pattern = {
        ':',
        '/',
        '?',
    },
    callback = function()
        fn.wildtrigger()
    end,
})
api.nvim_create_autocmd({
    'FocusGained',
    'BufEnter',
    'CursorHold',
    'CursorHoldI',
}, {
    callback = function()
        if bo.filetype ~= '' and bo.filetype ~= 'vim' and fn.mode() ~= 'c' then
            vim.cmd('checktime')
        end
    end,
})
api.nvim_create_user_command('Json2Lua', function()
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    local json_str = table.concat(lines, '\n')
    json_str = json_str:gsub('//[^\n]*', '')
    json_str = json_str:gsub('/%*.-%*/', '')
    json_str = json_str:gsub(',(%s*[}%]])', '%1')
    local ok, lua_table = pcall(vim.json.decode, json_str)
    if not ok then
        vim.notify('Failed to parse JSON: ' .. lua_table, vim.log.levels.ERROR)
        return
    end
    local lua_str = vim.inspect(lua_table)
    vim.cmd('vnew')
    api.nvim_buf_set_lines(0, 0, -1, false, vim.split(lua_str, '\n'))
    bo.filetype = 'lua'
end, {})
api.nvim_create_user_command('JsonC2Lua', function()
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    local content = table.concat(lines, '\n')
    content = content:gsub('//[^\n]*\n', '\n')
    content = content:gsub('/%*.--%*/', '')
    content = content:gsub(',(%s*[}%]])', '%1')
    local ok, result = pcall(vim.json.decode, content)
    if not ok then
        vim.notify('JSON parse error: ' .. result, vim.log.levels.ERROR)
        vim.cmd('vnew')
        api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, '\n'))
        vim.bo.filetype = 'json'
        return
    end
    local lua_str = 'return ' .. vim.inspect(result)
    vim.cmd('vnew')
    api.nvim_buf_set_lines(0, 0, -1, false, vim.split(lua_str, '\n'))
    vim.bo.filetype = 'lua'
    vim.notify('Converted to Lua', vim.log.levels.INFO)
end, {})
return M