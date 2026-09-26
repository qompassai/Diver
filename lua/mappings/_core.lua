-- Shared mapping ownership and native UI helpers; Neovim 0.13+ / LuaJIT.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local M = {}
local BUFFER_COUNT_MAX = 4096
local MAPPING_COUNT_MAX = 256

---@class NativeMapping
---@field lhs string
---@field rhs string|function
---@field desc string
---@field mode? string|string[]
---@field expr? boolean
---@field remap? boolean

---@class OwnedMapping
---@field mode string
---@field key string
---@field desc string
---@field callback function?
---@field rhs string|function

---@class OwnerState
---@field scopes table<integer, OwnedMapping[]>
---@field skipped table<string, string>
---@field active boolean?
---@field group integer?

---@type table<string, OwnerState>
local owners = {}

function M.notify(message, level)
    vim.notify(tostring(message), level or vim.log.levels.WARN, {
        title = 'Native mappings',
    })
end

function M.usable(bufnr)
    return api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr)
end

function M.source(bufnr)
    return M.usable(bufnr)
        and vim.bo[bufnr].buftype == ''
        and vim.bo[bufnr].filetype ~= ''
        and vim.b[bufnr].nvim_dir == nil
end

function M.supports(bufnr, method)
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if client:supports_method(method, bufnr) then
            return true
        end
    end
    return false
end

-- <Leader> becomes Alt-of-the-next-character rather than a literal
-- prefix: <Leader>ff -> <M-f>f. This ignores vim.g.mapleader entirely
-- for entries that use <Leader> -- Alt is a modifier, not a printable
-- character, so mapleader's own literal value can never represent it.
-- Anything without a leading <Leader> tag (including <LocalLeader>
-- entries) passes through unchanged.
---@param lhs string
---@return string
local function alt_leader(lhs)
    assert(type(lhs) == 'string', 'alt_leader requires a string')
    local rest = lhs:gsub('^<[Ll][Ee][Aa][Dd][Ee][Rr]>', '')
    if rest == lhs then
        return lhs
    end
    local first, remainder = rest:match('^(.)(.*)$')
    if not first then
        return lhs
    end
    return '<M-' .. first .. '>' .. remainder
end

---@param lhs string
---@return string
local function keys(lhs)
    lhs = alt_leader(lhs)
    lhs = lhs:gsub('<[Ll][Oo][Cc][Aa][Ll][Ll][Ee][Aa][Dd][Ee][Rr]>', function()
        return vim.g.maplocalleader or '\\'
    end)
    return api.nvim_replace_termcodes(lhs, true, true, true)
end

---@param scope integer
---@param mode string
---@return table[]
local function mappings(scope, mode)
    assert(type(mode) == 'string', 'mappings() requires a single mode string')
    if scope == 0 then
        return api.nvim_get_keymap(mode)
    end
    return api.nvim_buf_get_keymap(scope, mode)
end

---@param current table
---@param owned OwnedMapping
---@return boolean
local function matches(current, owned)
    return keys(current.lhs) == owned.key
        and current.desc == owned.desc
        and current.callback == owned.callback
        and current.rhs == owned.rhs
end

function M.clear(owner, scope)
    local state = owners[owner]
    local previous = state and state.scopes[scope]
    if not previous then
        return
    end
    if scope == 0 or api.nvim_buf_is_valid(scope) then
        for _, owned in ipairs(previous) do
            for _, current in ipairs(mappings(scope, owned.mode)) do
                if matches(current, owned) then
                    local opts = scope ~= 0 and {
                        buffer = scope,
                    } or {}
                    vim.keymap.del(owned.mode, current.lhs, opts)
                    break
                end
            end
        end
    end
    state.scopes[scope] = nil
    local prefix = scope .. ':'
    for key in pairs(state.skipped) do
        if key:sub(1, #prefix) == prefix then
            state.skipped[key] = nil
        end
    end
end

---@param scope integer
---@param mode string
---@param key string
---@return string?
local function conflict(scope, mode, key)
    for _, existing in ipairs(mappings(scope, mode)) do
        local other = keys(existing.lhs)
        if key:sub(1, #other) == other or other:sub(1, #key) == key then
            return existing.lhs
        end
    end
    return nil
end

---@param mode string|string[]|nil
---@return string[]
local function resolve_modes(mode)
    if type(mode) == 'table' then
        return mode
    end
    return { mode or 'n' }
end

---@param owner string
---@param scope integer Zero means global; otherwise use an actual buffer id.
---@param definitions NativeMapping[]
function M.install(owner, scope, definitions)
    assert(type(owner) == 'string' and owner ~= '')
    assert(#definitions <= MAPPING_COUNT_MAX, 'Too many mappings')
    owners[owner] = owners[owner] or { scopes = {}, skipped = {} }
    M.clear(owner, scope)
    local state = owners[owner]
    state.scopes[scope] = {}
    local ordered = vim.list_slice(definitions)
    table.sort(ordered, function(a, b)
        if a.lhs:lower() ~= b.lhs:lower() then
            return a.lhs:lower() < b.lhs:lower()
        end
        return a.lhs < b.lhs
    end)
    for _, entry in ipairs(ordered) do
        assert(type(entry.rhs) == 'string' or type(entry.rhs) == 'function')
        local modes = resolve_modes(entry.mode)
        -- Resolve <Leader> to its Alt-wrapped form once; <LocalLeader>
        -- still expands natively (via vim.g.maplocalleader) inside
        -- vim.keymap.set itself, exactly as before.
        local resolved_lhs = alt_leader(entry.lhs)
        for _, mode in ipairs(modes) do
            assert(type(mode) == 'string', 'Each resolved mode must be a single string')
            local key = keys(entry.lhs)
            local occupied = conflict(scope, mode, key)
            if occupied then
                state.skipped[scope .. ':' .. mode .. ':' .. entry.lhs] = occupied
            else
                local opts = {
                    desc = owner .. ': ' .. entry.desc,
                    silent = true,
                    expr = entry.expr or false,
                    remap = entry.remap or false,
                }
                if scope ~= 0 then
                    opts.buffer = scope
                end
                vim.keymap.set(mode, resolved_lhs, entry.rhs, opts)
                for _, current in ipairs(mappings(scope, mode)) do
                    if keys(current.lhs) == key then
                        ---@type OwnedMapping
                        local recorded = {
                            mode = mode,
                            key = key,
                            desc = current.desc,
                            callback = current.callback,
                            rhs = current.rhs,
                        }
                        table.insert(state.scopes[scope], recorded)
                        break
                    end
                end
            end
        end
    end
end

function M.teardown(owner)
    local state = owners[owner]
    if not state then
        return
    end
    state.active = false
    if state.group then
        api.nvim_del_augroup_by_id(state.group)
    end
    for _, scope in ipairs(vim.tbl_keys(state.scopes)) do
        M.clear(owner, scope)
    end
    owners[owner] = nil
end

function M.watch(owner, attach, events)
    M.teardown(owner)
    ---@type OwnerState
    local state = { scopes = {}, skipped = {}, active = true }
    owners[owner] = state
    state.group = api.nvim_create_augroup('NativeMappings_' .. owner, { clear = true })
    local function refresh(bufnr)
        if state.active and M.usable(bufnr) then
            local ok, err = pcall(attach, bufnr)
            if not ok then
                M.notify(owner .. ': ' .. tostring(err), vim.log.levels.ERROR)
            end
        end
    end
    api.nvim_create_autocmd(events or {
        'BufEnter',
        'FileType',
        'LspAttach',
        'LspDetach',
    }, {
        group = state.group,
        callback = function(event)
            if event.event == 'LspDetach' then
                vim.schedule(function()
                    refresh(event.buf)
                end)
            else
                refresh(event.buf)
            end
        end,
    })
    api.nvim_create_autocmd('BufWipeout', {
        group = state.group,
        callback = function(event)
            M.clear(owner, event.buf)
        end,
    })
    local buffers = api.nvim_list_bufs()
    for index = 1, math.min(#buffers, BUFFER_COUNT_MAX) do
        refresh(buffers[index])
    end
end

function M.report()
    local lines = { 'Preserved existing mappings (owner: scope:mode:key -> existing key)' }
    for _, owner in ipairs(vim.fn.sort(vim.tbl_keys(owners))) do
        for _, key in ipairs(vim.fn.sort(vim.tbl_keys(owners[owner].skipped))) do
            lines[#lines + 1] = owner .. ': ' .. key .. ' -> ' .. owners[owner].skipped[key]
        end
    end
    M.show(lines, 'Mapping report')
end

function M.show(lines, title)
    local bufnr = api.nvim_create_buf(false, true)
    vim.bo[bufnr].bufhidden = 'wipe'
    vim.bo[bufnr].swapfile = false
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    vim.b[bufnr].native_mapping_title = title
    vim.cmd('botright split')
    api.nvim_win_set_buf(0, bufnr)
end

function M.select(bufnr, items, title)
    if #items == 0 then
        M.notify('No available actions for this buffer')
        return
    end
    table.sort(items, function(a, b)
        return a.label < b.label
    end)
    local filetype = vim.bo[bufnr].filetype
    local tick = api.nvim_buf_get_changedtick(bufnr)
    vim.ui.select(items, {
        prompt = title,
        format_item = function(item)
            return item.label
        end,
    }, function(item)
        if not item then
            return
        end
        if
            not M.usable(bufnr)
            or api.nvim_get_current_buf() ~= bufnr
            or vim.bo[bufnr].filetype ~= filetype
            or api.nvim_buf_get_changedtick(bufnr) ~= tick
        then
            M.notify('Buffer changed during selection; invoke the action again')
            return
        end
        local ok, err = pcall(item.run)
        if not ok then
            M.notify(err, vim.log.levels.ERROR)
        end
    end)
end

function M.command(name)
    return function()
        if vim.fn.exists(':' .. name) ~= 2 then
            M.notify('Command unavailable: ' .. name)
            return
        end
        api.nvim_cmd({ cmd = name }, {})
    end
end

return M
