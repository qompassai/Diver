-- Purpose: BiDi log module. Subscribes to log.entryAdded and turns each
-- entry into a quickfix item. _to_qf_item is pure and unit-tested; the
-- Neovim quickfix sink lives here too, fed by bidi/init wiring.

local M = {}

local LEVEL_TO_QFTYPE = {
    error = 'E',
    warning = 'W',
    info = 'I',
    debug = 'I',
}

---Turn a log.entryAdded params table into a quickfix item. Pure: unknown
---or misshapen params become a best-effort item, never an error.
---@param params table
---@return table qf item {text, type}
function M._to_qf_item(params)
    if type(params) ~= 'table' then
        return { text = '(malformed log entry)', type = 'E' }
    end
    local text = params.text
    if type(text) ~= 'string' then
        text = '(log entry without text)'
    end
    local level = params.level
    local qftype = LEVEL_TO_QFTYPE[level] or 'I'
    local source = params.source
    if type(source) == 'table' and type(source.realm) == 'string' then
        text = '[' .. source.realm:sub(1, 24) .. '] ' .. text
    end
    return { text = text, type = qftype }
end

---Append one entry to the quickfix list (Neovim sink).
---@param params table log.entryAdded params
function M.append_qf(params)
    local item = M._to_qf_item(params)
    vim.fn.setqflist({}, 'a', {
        title = 'BiDi console',
        items = {
            { text = item.text, type = item.type },
        },
    })
end

---Subscribe to log.entryAdded; each event goes to on_entry.
---@param conn table BidiConn facade
---@param contexts? string[] scope to these browsing contexts
---@param on_entry fun(params: table)
---@param callback fun(err: string?)
function M.stream(conn, contexts, on_entry, callback)
    assert(type(on_entry) == 'function', 'on_entry must be a function')
    assert(type(callback) == 'function', 'callback must be a function')
    if conn == nil or type(conn.send) ~= 'function' then
        callback('conn.send must be a function')
        return
    end
    local params = { events = { 'log.entryAdded' } }
    if contexts ~= nil then
        params.contexts = contexts
    end
    local ok, serr = conn:send('session.subscribe', params, function(err)
        if err ~= nil then
            callback('log subscribe failed: ' .. err)
            return
        end
        callback(nil)
    end)
    if not ok then
        callback(serr)
        return
    end
    -- Route events through the wire handler table.
    local wire = require('dev.browser.bidi.wire')
    wire.on_event(conn.wire_state, 'log.entryAdded', on_entry)
end

return M
