--[[
# #################################################################
# /qompassai/lua/dap/ui.lua
# Qompass AI Ui
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
--]]
local api = vim.api
local utils = require('dap.utils')
local if_nil = utils.if_nil
local M = {}

---Shared namespaces for all UI layers. Extmarks are buffer-scoped already,
---so one module-level pair replaces the per-buffer namespaces.
---@type integer
local layer_ns = api.nvim_create_namespace('dap.ui_layer')

---@type integer
local layer_hl_ns = api.nvim_create_namespace('dap.ui_layer_hl')

---@param buf integer
---@return integer line count, excluding the prompt line for prompt buffers
local function line_count(buf)
    if vim.bo[buf].buftype ~= 'prompt' then
        return api.nvim_buf_line_count(buf)
    end
    if vim.fn.has('nvim-0.12') == 1 then
        local ok, mark = pcall(api.nvim_buf_get_mark, buf, ':')
        if ok then
            return mark[1] - 1
        end
    end
    return api.nvim_buf_line_count(buf) - 1
end

---@param buf integer
---@param extmarks table[] extmarks as returned by nvim_buf_get_extmarks
---@param marks table<number, dap.ui.LineInfo>
local function remove_marks(buf, extmarks, marks)
    for _, mark in pairs(extmarks) do
        local mark_id = mark[1]
        marks[mark_id] = nil
        api.nvim_buf_del_extmark(buf, layer_ns, mark_id)
    end
end

---Render items into a buffer region. All text is produced in Lua arrays
---first, then written with a single nvim_buf_set_lines call, then extmarks
---are placed. A render_fn failure aborts before any buffer mutation.
---@param buf integer
---@param xs any[]
---@param render_fn fun(item: any): string, table?
---@param context table?
---@param start integer?
---@param end_ integer?
---@param marks table<number, dap.ui.LineInfo>
local function render_items(buf, xs, render_fn, context, start, end_, marks)
    if not start and not end_ then
        start = line_count(buf)
        -- Avoid inserting a new line at the end of the buffer. The case of no
        -- lines and one empty line are ambiguous: set_lines(buf, 0, 0) would
        -- "preserve" the "empty buffer line" while set_lines(buf, 0, -1)
        -- replaces it. Use regular end_ = start in other cases to support
        -- injecting lines everywhere else.
        if start == 1 and (api.nvim_buf_get_lines(buf, 0, -1, true))[1] == '' then
            start = 0
            end_ = -1
        else
            end_ = start
        end
    else
        start = start or (line_count(buf) - 1)
        end_ = end_ or start
    end
    if end_ > start then
        local replaced =
            api.nvim_buf_get_extmarks(buf, layer_ns, { start, 0 }, { end_ - 1, -1 }, {})
        remove_marks(buf, replaced, marks)
    elseif end_ == -1 then
        local replaced = api.nvim_buf_get_extmarks(buf, layer_ns, { start, 0 }, { -1, -1 }, {})
        remove_marks(buf, replaced, marks)
    end
    local lines = {}
    local hl_regions_all = {}
    for i, item in ipairs(xs) do
        local text, hl_regions = render_fn(item)
        if not text then
            local debuginfo = debug.getinfo(render_fn)
            error(
                'render function must return a string, got nil instead. render_fn: '
                    .. debuginfo.short_src
                    .. ':'
                    .. debuginfo.linedefined
                    .. ' '
                    .. vim.inspect(xs)
            )
        end
        lines[i] = text:gsub('\n', '\\n')
        hl_regions_all[i] = hl_regions
    end
    api.nvim_buf_set_lines(buf, start, end_, true, lines)
    if start == -1 then
        start = line_count(buf) - #lines
    end
    for i = 1, #lines do
        local lnum = start + i - 1
        local text = lines[i]
        local hl_regions = hl_regions_all[i]
        if hl_regions then
            for _, hl_region in pairs(hl_regions) do
                local end_col = hl_region[3]
                if end_col == -1 then
                    end_col = #text
                end
                api.nvim_buf_set_extmark(buf, layer_hl_ns, lnum, hl_region[2], {
                    end_row = lnum,
                    end_col = end_col,
                    hl_group = hl_region[1],
                })
            end
        end
        local end_col = math.max(0, #text - 1)
        local mark_id = api.nvim_buf_set_extmark(buf, layer_ns, lnum, 0, { end_col = end_col })
        marks[mark_id] = { mark_id = mark_id, item = xs[i], context = context }
    end
end
---@param win integer
---@param opts table<string, any>?
function M.apply_winopts(win, opts)
    if not opts then
        return
    end
    assert(type(opts) == 'table', 'winopts must be a table, not ' .. type(opts))
    for k, v in pairs(opts) do
        if k == 'width' then
            api.nvim_win_set_config(win, { width = v })
        elseif k == 'height' then
            api.nvim_win_set_config(win, { height = v })
        elseif vim.tbl_contains({ 'border', 'title' }, k) then
            api.nvim_win_set_config(win, { [k] = v })
        else
            vim.wo[win][k] = v
        end
    end
end

--- Same as M.pick_one except that it skips the selection prompt if `items`
--  contains exactly one item.
---@generic T
---@param items T[]
---@param prompt string
---@param label_fn fun(item: T): string
---@param cb? fun(item: T?)
---@return T? picked item when called without a callback and not in dual-mode
function M.pick_if_many(items, prompt, label_fn, cb)
    if #items == 1 then
        if not cb then
            return items[1]
        else
            cb(items[1])
        end
    else
        return M.pick_one(items, prompt, label_fn, cb)
    end
end

---@generic T
---@param items T[]
---@param prompt string
---@param label_fn fun(item: T): string
---@return T? picked item or nil on invalid choice
function M.pick_one_sync(items, prompt, label_fn)
    local choices = { prompt }
    for i, item in ipairs(items) do
        table.insert(choices, string.format('%d: %s', i, label_fn(item)))
    end
    local choice = vim.fn.inputlist(choices)
    if choice < 1 or choice > #items then
        return nil
    end
    return items[choice]
end

---Dual-mode: without a callback and inside a coroutine, yields and returns the
---picked item; otherwise delivers it to `cb`.
---@param items any[]
---@param prompt string
---@param label_fn fun(item: any): string
---@param cb? fun(item: any?)
function M.pick_one(items, prompt, label_fn, cb)
    local co, is_main = coroutine.running()
    -- Only yield on a real sub-coroutine: yielding on the main thread (or
    -- outside any coroutine) raises "attempt to yield from outside a
    -- coroutine" instead of awaiting the selection.
    local synchronous = cb == nil and co ~= nil and not is_main
    if synchronous then
        cb = function(item)
            coroutine.resume(co, item)
        end
    end
    assert(cb ~= nil, 'pick_one needs a callback when not called from a coroutine')
    cb = vim.schedule_wrap(cb)
    if vim.ui then
        vim.ui.select(items, {
            prompt = prompt,
            format_item = label_fn,
        }, cb)
    else
        local result = M.pick_one_sync(items, prompt, label_fn)
        cb(result)
    end
    if synchronous then
        -- Intentional await-in-sync: pick_one is dual-mode (only yields when
        -- called without a callback inside a coroutine); marking it async
        -- would falsely taint sync callers.
        return coroutine.yield()
    end
end

local function with_indent(indent, fn)
    local move_cols = function(hl_group)
        local end_col = hl_group[3] == -1 and -1 or hl_group[3] + indent
        return { hl_group[1], hl_group[2] + indent, end_col }
    end
    return function(...)
        local text, hl_groups = fn(...)
        return string.rep(' ', indent) .. text, vim.tbl_map(move_cols, hl_groups or {})
    end
end

---@class dap.ui.TreeOpts
---@field render_parent fun(item: any): string, table?
---@field render_child? fun(item: any): string, table?
---@field get_children fun(item: any): any[]
---@field has_children fun(item: any): boolean
---@field get_key? fun(item: any): any
---@field fetch_children? fun(item: any, cb: fun(children: any[]))
---@field compute_actions? fun(info: table): table[]
---@field extra_context? table<string, any>
---@field implicit_expand_action? boolean
---@field is_lazy? fun(item: any): boolean
---@field load_value? fun(item: any, cb: fun(value: any))

---@param opts dap.ui.TreeOpts
---@return table<string, any> tree with toggle() and render() entry points
function M.new_tree(opts)
    assert(opts.render_parent, 'opts for tree requires a `render_parent` function')
    assert(opts.get_children, 'opts for tree requires a `get_children` function')
    assert(opts.has_children, 'opts for tree requires a `has_children` function')
    local get_key = opts.get_key or function(x)
        return x
    end
    opts.fetch_children = opts.fetch_children or function(item, cb)
        cb(opts.get_children(item))
    end
    opts.render_child = opts.render_child or opts.render_parent
    local compute_actions = opts.compute_actions or function()
        return {}
    end
    local extra_context = opts.extra_context or {}
    local implicit_expand_action = if_nil(opts.implicit_expand_action, true)
    local is_lazy = opts.is_lazy or function(_)
        return false
    end
    local load_value = opts.load_value or function(_, _)
        assert(false, 'load_value not implemented')
    end

    local self -- forward reference

    -- tree supports to re-draw with new data while retaining previously
    -- expansion information.
    --
    -- Since the data is completely changed, the expansion information must be
    -- held separately.
    --
    -- The structure must supports constructs like this:
    --
    --         root
    --       /     \
    --      a      b
    --     /       \
    --    x        x
    --   / \
    --  aa bb
    --
    -- It must be possible to distinguish the two `x`
    -- This assumes that `get_key` within a level is unique and that it is
    -- deterministic between two `render` operations.
    local expanded_root = {}

    ---Maximum __parent hops get_expanded follows. Tree data can reference
    ---itself through workspace-controlled values; the bound plus cycle
    ---detection keeps the walk from looping forever.
    ---@type integer
    local PARENT_WALK_MAX = 100

    local function get_expanded(item)
        local ancestors = {}
        local seen = {}
        local parent = item
        for _ = 1, PARENT_WALK_MAX do
            parent = parent.__parent
            if parent == nil or seen[parent] then
                break
            end
            seen[parent] = true
            table.insert(ancestors, parent.key)
        end
        local expanded = expanded_root
        for i = #ancestors, 1, -1 do
            local parent_expanded = expanded[ancestors[i]]
            if parent_expanded then
                expanded = parent_expanded
            else
                break
            end
        end
        return expanded
    end

    local function set_expanded(item, value)
        local expanded = get_expanded(item)
        expanded[get_key(item)] = value
    end

    local function is_expanded(item)
        local expanded = get_expanded(item)
        return expanded[get_key(item)] ~= nil
    end

    local expand = function(layer, value, lnum, context)
        set_expanded(value, {})
        opts.fetch_children(value, function(children)
            local ctx = {
                actions = context.actions,
                indent = context.indent + 2,
                compute_actions = context.compute_actions,
                tree = self,
            }
            ctx = vim.tbl_deep_extend('keep', ctx, extra_context)
            for _, child in pairs(children) do
                if opts.has_children(child) then
                    child.__parent = { key = get_key(value), __parent = value.__parent }
                end
            end
            local render = with_indent(ctx.indent, opts.render_child)
            layer.render(children, render, ctx, lnum + 1)
        end)
    end

    local function eager_fetch_expanded_children(value, cb, ctx)
        ctx = ctx or { to_traverse = 1 }
        opts.fetch_children(value, function(children)
            ctx.to_traverse = ctx.to_traverse + #children
            for _, child in pairs(children) do
                if opts.has_children(child) then
                    child.__parent = { key = get_key(value), __parent = value.__parent }
                end
                if is_expanded(child) then
                    eager_fetch_expanded_children(child, cb, ctx)
                else
                    ctx.to_traverse = ctx.to_traverse - 1
                end
            end
            ctx.to_traverse = ctx.to_traverse - 1
            if ctx.to_traverse == 0 then
                cb()
            end
        end)
    end

    local function render_all_expanded(layer, value, indent)
        indent = indent or 2
        local context = {
            actions = implicit_expand_action and { { label = 'Expand', fn = self.toggle } } or {},
            indent = indent,
            compute_actions = compute_actions,
            tree = self,
        }
        context = vim.tbl_deep_extend('keep', context, extra_context)
        for _, child in pairs(opts.get_children(value)) do
            layer.render({ child }, with_indent(indent, opts.render_child), context)
            if is_expanded(child) then
                render_all_expanded(layer, child, indent + 2)
            end
        end
    end

    ---Maximum nodes collapse visits. Bounds pathological tree depth without
    ---recursion.
    ---@type integer
    local COLLAPSE_NODES_MAX = 10000

    local collapse = function(layer, value, lnum, context)
        if not is_expanded(value) then
            return
        end
        local num_vars = 1
        -- Explicit stack instead of recursion: each node is visited twice,
        -- once to count it and push its children, once to clear its
        -- expansion state on the way back up.
        local stack = {}
        for _, child in ipairs(opts.get_children(value)) do
            stack[#stack + 1] = { node = child, visited = false }
        end
        local visited = 0
        while #stack > 0 and visited < COLLAPSE_NODES_MAX do
            visited = visited + 1
            local frame = stack[#stack]
            if not frame.visited then
                frame.visited = true
                num_vars = num_vars + 1
                if is_expanded(frame.node) then
                    for _, child in pairs(opts.get_children(frame.node)) do
                        stack[#stack + 1] = { node = child, visited = false }
                    end
                end
            else
                stack[#stack] = nil
                if is_expanded(frame.node) then
                    set_expanded(frame.node, nil)
                end
            end
        end
        set_expanded(value, nil)
        layer.render({}, tostring, context, lnum + 1, lnum + num_vars)
    end

    self = {
        toggle = function(layer, value, lnum, context)
            if is_lazy(value) then
                load_value(value, function(var)
                    local render = with_indent(context.indent, opts.render_child)
                    layer.render({ var }, render, context, lnum, lnum + 1)
                end)
            elseif is_expanded(value) then
                collapse(layer, value, lnum, context)
            elseif opts.has_children(value) then
                expand(layer, value, lnum, context)
            else
                utils.notify(
                    'No children on line ' .. tostring(lnum) .. ". Can't expand",
                    vim.log.levels.INFO
                )
            end
        end,

        render = function(layer, value, on_done, lnum, end_)
            layer.render({ value }, opts.render_parent, nil, lnum, end_)
            if not opts.has_children(value) then
                if on_done then
                    on_done()
                end
                return
            end
            if not is_expanded(value) then
                set_expanded(value, {})
            end
            eager_fetch_expanded_children(value, function()
                render_all_expanded(layer, value)
                if on_done then
                    on_done()
                end
            end)
        end,
    }
    return self
end

---@param new_buf fun(view: table<string, any>): integer buffer factory; must return the bufnr
---@param new_win fun(buf: integer, ...: any): integer window factory; must return the winnr
---@param opts? view hooks: before_open(view, ...) and after_open(view, before_open_result, ...)
---@return table<string, any> view with open/toggle/close/_init_buf
function M.new_view(new_buf, new_win, opts)
    assert(new_buf, 'new_buf must not be nil')
    assert(new_win, 'new_win must not be nil')
    opts = opts or {}
    local self
    self = {
        buf = nil,
        win = nil,

        toggle = function(...)
            if not self.close({ mode = 'toggle' }) then
                self.open(...)
            end
        end,

        close = function(close_opts)
            close_opts = close_opts or {}
            local closed = false
            local win = self.win
            local buf = self.buf
            if win and api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf then
                api.nvim_win_close(win, true)
                self.win = nil
                closed = true
            end
            local hide = close_opts.mode == 'toggle'
            if buf and not hide then
                -- Retain self.buf when deletion fails: clearing it would leak
                -- the buffer while pretending it is gone.
                local ok, err = pcall(api.nvim_buf_delete, buf, { force = true })
                if ok then
                    self.buf = nil
                else
                    utils.notify(
                        'Failed to delete DAP view buffer: ' .. tostring(err),
                        vim.log.levels.WARN
                    )
                end
            end
            return closed
        end,
        ---@return integer
        _init_buf = function()
            if self.buf then
                return self.buf
            end
            local buf = new_buf(self)
            assert(buf, 'The `new_buf` function is supposed to return a buffer')
            api.nvim_buf_attach(buf, false, {
                on_detach = function()
                    self.buf = nil
                end,
            })
            self.buf = buf
            return buf
        end,

        open = function(...)
            local win = self.win
            local before_open_result
            if opts.before_open then
                before_open_result = opts.before_open(self, ...)
            end
            local buf = self._init_buf()
            if not win or not api.nvim_win_is_valid(win) then
                win = new_win(buf, ...)
            end
            api.nvim_win_set_buf(win, buf)

            -- Trigger filetype again to ensure ftplugin files can change window settings
            local ft = vim.bo[buf].filetype
            vim.bo[buf].filetype = ft

            self.buf = buf
            self.win = win
            if opts.after_open then
                opts.after_open(self, before_open_result, ...)
            end
            return buf, win
        end,
    }
    return self
end

---@param opts? { mode?: string, filter?: string|fun(action: table): boolean }
function M.trigger_actions(opts)
    opts = opts or {}
    local buf = api.nvim_get_current_buf()
    local layer = M.get_layer(buf)
    if not layer then
        return
    end
    local lnum = table.unpack(api.nvim_win_get_cursor(0))
    lnum = lnum - 1
    local info = layer.get(lnum, 0) or {}
    local context = info.context or {}
    local actions = {}
    vim.list_extend(actions, context.actions or {})
    if context.compute_actions then
        vim.list_extend(actions, context.compute_actions(info))
    end
    if opts.filter then
        local filter = (
            type(opts.filter) == 'function' and opts.filter
            or function(x)
                return x.label == opts.filter
            end
        )
        actions = vim.tbl_filter(filter, actions)
    end
    if #actions == 0 then
        utils.notify(
            'No action possible on: ' .. api.nvim_buf_get_lines(buf, lnum, lnum + 1, true)[1],
            vim.log.levels.INFO
        )
        return
    end
    if opts.mode == 'first' then
        local action = actions[1]
        action.fn(layer, info.item, lnum, info.context)
        return
    end
    M.pick_if_many(actions, 'Actions> ', function(x)
        return type(x.label) == 'string' and x.label or x.label(info.item)
    end, function(action)
        if action then
            action.fn(layer, info.item, lnum, info.context)
        end
    end)
end

---@type table<number, dap.ui.Layer>
local layers = {}

--- Return an existing layer
---
---@param buf integer
---@return nil|dap.ui.Layer
function M.get_layer(buf)
    return layers[buf]
end

---@class dap.ui.LineInfo
---@field mark_id number
---@field item any
---@field context table|nil

--- Returns a layer, creating it if it's missing.
---@param buf integer
---@return dap.ui.Layer
function M.layer(buf)
    assert(buf, 'Need a buffer to operate on')
    local layer = layers[buf]
    if layer then
        return layer
    end

    ---@type table<number, dap.ui.LineInfo>
    local marks = {}

    ---@class dap.ui.Layer
    layer = {
        buf = buf,
        __marks = marks,

        --- Render the items and associate each item to the rendered line
        ---  The item and context can then be retrieved using `.get(lnum)`
        ---
        ---  lines between start and end_ are replaced
        ---  If start == end_, new lines are inserted at the given position
        ---  If start == nil, appends to the end of the buffer
        ---
        ---@generic T
        ---@param xs T[]
        ---@param render_fn? fun(T):string
        ---@param context table|nil
        ---@param start nil|integer 0-indexed
        ---@param end_ nil|integer 0-indexed exclusive
        render = function(xs, render_fn, context, start, end_)
            if not api.nvim_buf_is_valid(buf) then
                return
            end
            local modifiable = vim.bo[buf].modifiable
            vim.bo[buf].modifiable = true
            -- Protected body: `modifiable` is always restored, and a render
            -- error propagates only after restoration.
            local render = render_fn or tostring
            local ok, err = pcall(render_items, buf, xs, render, context, start, end_, marks)
            vim.bo[buf].modifiable = modifiable
            if not ok then
                error(err, 0)
            end
        end,

        --- Get the information associated with a line
        ---
        ---@param lnum integer 0-indexed line number
        ---@param start_col nil|number
        ---@param end_col nil|number
        ---@return nil|dap.ui.LineInfo
        get = function(lnum, start_col, end_col)
            local line = api.nvim_buf_get_lines(buf, lnum, lnum + 1, true)[1]
            start_col = start_col or 0
            end_col = end_col or #line
            local start = { lnum, start_col }
            local end_ = { lnum, end_col }
            local extmarks = api.nvim_buf_get_extmarks(buf, layer_ns, start, end_, {})
            if not extmarks or #extmarks == 0 then
                return
            end
            local msg = 'Expecting only a single mark per line and region: '
                .. vim.inspect(extmarks)
            assert(#extmarks == 1, msg)
            local extmark = extmarks[1]
            return marks[extmark[1]]
        end,
    }
    layers[buf] = layer
    api.nvim_buf_attach(buf, false, {
        on_detach = function(_, b)
            layers[b] = nil
        end,
    })
    return layer
end

return M
