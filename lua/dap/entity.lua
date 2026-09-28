-- lua/dap/entity.lua
--
-- Purpose: rendering helpers and tree specs for DAP entities (stack frames,
-- variables, scopes, threads) consumed by the REPL and the dap.ui widgets.
--
-- Consumed as:
--   * require('dap.entity').frames.render_item   (dap/repl.lua)
--   * require('dap.entity').variable.tree_spec    (dap/repl.lua)
--   * require('dap.entity').scope.tree_spec       (dap/repl.lua, dap/ui/widgets.lua)
--   * require('dap.entity').threads.tree_spec     (dap/repl.lua)
--
-- Every tree_spec follows the dap.ui.new_tree contract: render_parent,
-- get_children and has_children are required; fetch_children, get_key and
-- render_child are optional. Variable/scope children are fetched lazily with
-- a single DAP `variables` round-trip per node and cached on the item, so
-- expand/collapse never re-requests.

---@class dap.entity.TreeSpec
---@field render_parent fun(item: table): string renders one item as one line
---@field get_children fun(item: table): table[] cached children of item
---@field has_children fun(item: table): boolean whether item can have children
---@field fetch_children? fun(item: table, cb: fun()) ensures children are loaded, then calls cb
---@field get_key? fun(item: table): any stable per-level key for expansion bookkeeping
---@field render_child? fun(item: table): string defaults to render_parent

local M = {}

---The native backend owns session state. require('dap') is the multi-backend
---dispatcher (lua/dap/init.lua) and does not expose session(); go straight to
---the backend that owns it.
---@return dap.Session|nil
local function get_session()
    return require('dap.dap').session()
end

---Ensure a scope's or variable's children are loaded, then call cb.
---Results are cached on the item, so repeated expands cost nothing.
---@param item table DAP scope or variable carrying variablesReference
---@param cb fun() called once children are available (possibly immediately)
local function fetch_variables(item, cb)
    assert(cb, 'fetch_variables requires a callback')
    if item.variables then
        cb()
        return
    end
    local ref = item.variablesReference or 0
    local session = get_session()
    if ref == 0 or not session then
        cb()
        return
    end
    session:request('variables', { variablesReference = ref }, function(err, resp)
        if not err and resp and resp.variables then
            item.variables = resp.variables
        else
            vim.notify(
                '[dap] variables request failed: ' .. tostring(err),
                vim.log.levels.WARN
            )
        end
        cb()
    end)
end

-- ---------------------------------------------------------------------------
-- Stack frames
-- ---------------------------------------------------------------------------

M.frames = {}

---Render one stack frame as a single REPL line.
---@param frame dap.StackFrame
---@return string
function M.frames.render_item(frame)
    local name = frame.name or '?'
    local src = frame.source and frame.source.name or nil
    if src and frame.line then
        return string.format('  %s (%s:%d)', name, src, frame.line)
    elseif frame.line then
        return string.format('  %s (line %d)', name, frame.line)
    elseif src then
        return string.format('  %s (%s)', name, src)
    end
    return '  ' .. name
end

-- ---------------------------------------------------------------------------
-- Variables
-- ---------------------------------------------------------------------------

---@param var dap.Variable
---@return string
local function render_variable(var)
    local text = (var.name or '?') .. ' = ' .. (var.value or '')
    if var.type and var.type ~= '' then
        text = text .. ' (' .. var.type .. ')'
    end
    return text
end

---@param var dap.Variable
---@return boolean
local function variable_has_children(var)
    return (var.variablesReference or 0) > 0
end

---@param var dap.Variable
---@return table[]
local function variable_get_children(var)
    return var.variables or {}
end

---@param var dap.Variable
---@return string
local function variable_get_key(var)
    return var.name or '?'
end

M.variable = {
    ---@type dap.entity.TreeSpec
    tree_spec = {
        render_parent = render_variable,
        get_children = variable_get_children,
        has_children = variable_has_children,
        fetch_children = fetch_variables,
        get_key = variable_get_key,
    },
}

-- ---------------------------------------------------------------------------
-- Scopes
-- ---------------------------------------------------------------------------

---@param scope dap.Scope
---@return string
local function render_scope(scope)
    return scope.name or '?'
end

---@param scope dap.Scope
---@return boolean
local function scope_has_children(scope)
    return (scope.variablesReference or 0) > 0
end

---@param scope dap.Scope
---@return table[]
local function scope_get_children(scope)
    return scope.variables or {}
end

---@param scope dap.Scope
---@return string
local function scope_get_key(scope)
    return scope.name or '?'
end

M.scope = {
    ---@type dap.entity.TreeSpec
    tree_spec = {
        render_parent = render_scope,
        get_children = scope_get_children,
        has_children = scope_has_children,
        fetch_children = fetch_variables,
        get_key = scope_get_key,
    },
}

-- ---------------------------------------------------------------------------
-- Threads
-- ---------------------------------------------------------------------------

---@param thread dap.Thread
---@return string
local function render_thread(thread)
    if thread.name and thread.name ~= '' then
        return thread.name
    end
    return 'thread ' .. tostring(thread.id)
end

---@param thread dap.Thread
---@return table[]
local function thread_get_children(thread)
    return thread.frames or {}
end

---@param thread dap.Thread
---@return boolean
local function thread_has_children(thread)
    return #(thread.frames or {}) > 0
end

---@param thread dap.Thread
---@return number|string
local function thread_get_key(thread)
    return thread.id
end

M.threads = {
    ---@type dap.entity.TreeSpec
    tree_spec = {
        -- Frames ride on the thread object (populated on stop events); nothing
        -- to fetch. Explicit so the spec stays directly callable like the
        -- variable/scope specs instead of relying on new_tree's default.
        fetch_children = function(_, cb)
            cb()
        end,
        render_parent = render_thread,
        get_children = thread_get_children,
        has_children = thread_has_children,
        get_key = thread_get_key,
    },
}

return M
