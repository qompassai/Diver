-- #################################################################
-- /qompassai/diver/lua/utils/blue/dap.lua
-- Qompass AI Dap
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

local M = {}
local ns = vim.api.nvim_create_namespace('dap-virtual-text-util')
local plugin_id = 'dap-virtual-text-util'
local defaults = {
  enabled = true,
  all_frames = false,
  clear_on_continue = false,
  commented = false,
  only_first_definition = true,
  all_references = false,
  highlight_changed_variables = true,
  highlight_new_as_changed = false,
  show_stop_reason = true,
  virt_text_pos = vim.fn.has('nvim-0.10') == 1 and 'inline' or 'eol',
  virt_lines = false,
  virt_lines_above = true,
  virt_text_win_col = nil,
  text_prefix = '',
  separator = ', ',
  error_prefix = ' ',
  info_prefix = ' ',
  filter_references_pattern = nil,
  display_callback = function(variable)
    if not variable then
      return nil
    end
    local value = variable.value
    if value == nil then
      return nil
    end
    return tostring(value)
  end,
}

local state = {
  opts = vim.deepcopy(defaults),
  last_frames = {},
  stopped_frame = nil,
  error_msg = nil,
  info_msg = nil,
  registered = false,
}

local function get_dap()
  local ok, dap = pcall(require, 'dap')
  if not ok or type(dap) ~= 'table' then
    return nil
  end
  if type(dap.listeners) ~= 'table' then
    return nil
  end
  return dap
end

local function get_parser(buf, ft)
  if type(ft) ~= 'string' or ft == '' then
    return nil, nil
  end

  local lang = vim.treesitter.language.get_lang(ft)
  if not lang then
    return nil, nil
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if not ok then
    return nil, nil
  end

  return parser, lang
end

local function set_message(frame, msg, hl, inline)
  if not frame or not frame.source or not frame.source.path or not frame.line then
    return
  end

  local buf = vim.uri_to_bufnr(vim.uri_from_fname(frame.source.path))
  local text = msg or ''

  if state.opts.commented then
    local commentstring = vim.bo[buf].commentstring
    if type(commentstring) ~= 'string' or commentstring == '' then
      commentstring = '%s'
    end
    text = commentstring:gsub('%%s', text)
  end

  pcall(vim.api.nvim_buf_set_extmark, buf, ns, frame.line - 1, 0, {
    hl_mode = 'combine',
    virt_text = { { text, hl } },
    virt_text_pos = inline and 'eol' or state.opts.virt_text_pos,
  })
end

local function variables_from_scopes(scopes, _lang)
  local vars = {}
  for _, scope in pairs(scopes or {}) do
    for _, variable in pairs(scope.variables or {}) do
      if variable and variable.name then
        vars[variable.name] = variable
      end
    end
  end
  return vars
end

local function collect_nodes(_buf, parser, all_references)
  if not parser then
    return {}, {}
  end

  local ok, trees = pcall(parser.parse, parser)
  if not ok or not trees or not trees[1] then
    return {}, {}
  end

  local root = trees[1]:root()
  if not root then
    return {}, {}
  end

  local scope_nodes = { root }
  local def_nodes = {}

  local function walk(node)
    if not node then
      return
    end

    local t = node:type()
    if t == 'identifier' then
      def_nodes[#def_nodes + 1] = node
    elseif all_references and (t:find('identifier') or t:find('name')) then
      def_nodes[#def_nodes + 1] = node
    end

    for child in node:iter_children() do
      walk(child)
    end
  end

  walk(root)
  return scope_nodes, def_nodes
end

local function in_scope(scope_nodes, node, frame_line)
  if not node or not frame_line then
    return false
  end

  local row = node:start()
  if row == nil then
    return false
  end

  if row > (frame_line - 1) then
    return false
  end

  if not scope_nodes or #scope_nodes == 0 then
    return true
  end

  for _, scope in ipairs(scope_nodes) do
    local sr, _, er, _ = scope:range()
    local stop_row = frame_line - 1
    local inside_scope = (stop_row >= sr) and (stop_row <= er)
    local inside_var = (row >= sr) and (row <= er)
    if inside_scope and inside_var then
      return true
    end
  end

  return false
end

local function extmark_for_content(buf, line, chunks, inline)
  local line_text = vim.api.nvim_buf_get_lines(buf, line, line + 1, true)[1] or ''
  local win_col = math.max(state.opts.virt_text_win_col or 0, #line_text + 1)

  for i, item in ipairs(chunks) do
    local text, hl, node = item[1], item[2], item.node
    local sr, sc, er, ec = node:range()

    if i < #chunks and not inline then
      text = text .. state.opts.separator
    end

    vim.api.nvim_buf_set_extmark(buf, ns, inline and er or sr, inline and ec or sc, {
      end_line = er,
      end_col = ec,
      hl_mode = 'combine',
      virt_text = { { text, hl } },
      virt_text_pos = state.opts.virt_text_pos,
      virt_text_win_col = state.opts.virt_text_win_col and win_col or nil,
    })

    win_col = win_col + #text + 1
  end
end

local function render_frame(frame)
  if not frame or not frame.scopes or not frame.source or not frame.source.path then
    return
  end

  local buf = vim.fn.bufnr(frame.source.path, false)
  if buf == -1 then
    buf = vim.uri_to_bufnr(vim.uri_from_fname(frame.source.path))
  end

  local ft = vim.bo[buf].filetype
  if ft == '' then
    ft = vim.filetype.match({ buf = buf }) or ''
    if ft == '' then
      return
    end
  end

  local parser = get_parser(buf, ft)
  if not parser then
    return
  end

  local scope_nodes, def_nodes = collect_nodes(buf, parser, state.opts.all_references)
  local vars = variables_from_scopes(frame.scopes)
  local last_scopes = state.last_frames[frame.id] and state.last_frames[frame.id].scopes or {}
  local last_vars = variables_from_scopes(last_scopes)
  local get_node_text = vim.treesitter.get_node_text
  local inline = state.opts.virt_text_pos == 'inline'
  local by_line, seen = {}, {}

  for _, node in ipairs(def_nodes) do
    local name = get_node_text(node, buf)
    local current = vars[name]
    local previous = last_vars[name]

    if
      current
      and not (
        state.opts.filter_references_pattern
        and tostring(current.value):find(state.opts.filter_references_pattern)
      )
    then
      if in_scope(scope_nodes, node, frame.line) then
        if state.opts.only_first_definition and not state.opts.all_references then
          vars[name] = nil
        end

        if not seen[node:id()] then
          seen[node:id()] = true

          local changed = state.opts.highlight_changed_variables
            and (current.value ~= (previous and previous.value or nil))
            and (state.opts.highlight_new_as_changed or previous)

          local text = state.opts.display_callback(current, buf, frame, node, state.opts)
          if text then
            if state.opts.commented then
              local commentstring = vim.bo[buf].commentstring
              if type(commentstring) ~= 'string' or commentstring == '' then
                commentstring = '%s'
              end
              text = commentstring:gsub('%%s', text)
            end

            text = state.opts.text_prefix .. text
            local row = node:start()
            by_line[row] = by_line[row] or {}
            table.insert(by_line[row], {
              text,
              changed and 'NvimDapVirtualTextChanged' or 'NvimDapVirtualText',
              node = node,
            })
          end
        end
      end
    end
  end

  for line, chunks in pairs(by_line) do
    if state.opts.all_references then
      local dedup, filtered = {}, {}
      for _, c in ipairs(chunks) do
        if not dedup[c[1]] then
          dedup[c[1]] = true
          table.insert(filtered, c)
        end
      end
      chunks = filtered
    end

    if state.opts.virt_lines then
      local virt = {}
      for _, c in ipairs(chunks) do
        table.insert(virt, { c[1], c[2] })
      end
      vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
        virt_lines = { virt },
        virt_lines_above = state.opts.virt_lines_above,
      })
    else
      extmark_for_content(buf, line, chunks, inline)
    end
  end
end

local function register_dap_listeners()
  local dap = get_dap()
  if not dap or state.registered then
    return false
  end

  dap.listeners.after.event_terminated[plugin_id] = function()
    M.clear()
    state.last_frames = {}
    state.stopped_frame = nil
    state.error_msg = nil
    state.info_msg = nil
  end

  dap.listeners.after.event_exited[plugin_id] = dap.listeners.after.event_terminated[plugin_id]

  local on_continue = function()
    state.error_msg = nil
    state.info_msg = nil
    state.stopped_frame = nil
    if state.opts.clear_on_continue then
      M.clear()
    end
  end

  dap.listeners.before.event_continued[plugin_id] = on_continue
  dap.listeners.before.continue[plugin_id] = on_continue

  dap.listeners.before.event_stopped[plugin_id] = function(session)
    for _, thread in pairs(session.threads or {}) do
      for _, frame in pairs(thread.frames or {}) do
        if frame and frame.id then
          state.last_frames[frame.id] = frame
        end
      end
    end
  end

  dap.listeners.after.event_stopped[plugin_id] = function(_, event)
    if not state.opts.show_stop_reason then
      return
    end
    if event and event.reason == 'exception' then
      state.error_msg = state.opts.error_prefix .. 'Stopped due to exception'
    elseif event and event.reason == 'data breakpoint' then
      state.info_msg = state.opts.info_prefix .. 'Stopped due to data breakpoint'
    end
  end

  dap.listeners.after.variables[plugin_id] = function(session)
    M.refresh(session)
  end

  dap.listeners.after.stackTrace[plugin_id] = function(session, body)
    if not state.opts.enabled then
      return
    end

    local thread = session.stopped_thread_id and session.threads[session.stopped_thread_id] or nil
    local frames = thread and thread.frames or {}
    local with_source = vim.tbl_filter(function(f)
      return f.source and f.source.path
    end, frames)
    state.stopped_frame = with_source[1]

    if state.opts.all_frames and body then
      local requested = {}
      for _, f in pairs(body.stackFrames or {}) do
        if not requested[f.name] then
          if not f.scopes or #f.scopes == 0 then
            pcall(session._request_scopes, session, f)
          end
          requested[f.name] = true
        end
      end
    end
  end

  dap.listeners.after.exceptionInfo[plugin_id] = function(_, _, response)
    if not state.opts.enabled or not response then
      return
    end
    local typename = response.details and response.details.typeName or ''
    local desc = response.description or ''
    state.error_msg = state.opts.error_prefix .. typename .. ((typename ~= '' and desc ~= '') and ': ' or '') .. desc
  end

  state.registered = true
  return true
end

function M.clear()
  pcall(vim.api.nvim_buf_clear_namespace, 0, ns, 0, -1)

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
  end
end

function M.refresh(session)
  M.clear()

  if not state.opts.enabled then
    return
  end

  if session then
    if state.opts.all_frames and session.threads and session.threads[session.stopped_thread_id] then
      for _, frame in pairs(session.threads[session.stopped_thread_id].frames or {}) do
        render_frame(frame)
      end
    else
      render_frame(session.current_frame)
    end
  else
    local dap = get_dap()
    if not dap then
      return
    end

    local active = dap.session and dap.session() or nil
    if not active then
      return
    end

    if state.opts.all_frames and active.threads and active.threads[active.stopped_thread_id] then
      for _, frame in pairs(active.threads[active.stopped_thread_id].frames or {}) do
        render_frame(frame)
      end
    else
      render_frame(active.current_frame)
    end
  end

  if state.error_msg then
    set_message(state.stopped_frame, state.error_msg, 'NvimDapVirtualTextError', state.opts.virt_text_pos == 'inline')
  end

  if state.info_msg then
    set_message(state.stopped_frame, state.info_msg, 'NvimDapVirtualTextInfo', state.opts.virt_text_pos == 'inline')
  end
end

function M.enable()
  state.opts.enabled = true
  M.refresh()
end

function M.disable()
  state.opts.enabled = false
  M.clear()
end

function M.toggle()
  state.opts.enabled = not state.opts.enabled
  if state.opts.enabled then
    M.refresh()
  else
    M.clear()
  end
end

function M.setup(opts)
  state.opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), state.opts, opts or {})

  vim.api.nvim_set_hl(0, 'NvimDapVirtualText', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'NvimDapVirtualTextChanged', {
    link = 'DiagnosticVirtualTextWarn',
    default = true,
  })
  vim.api.nvim_set_hl(0, 'NvimDapVirtualTextError', { link = 'DiagnosticVirtualTextError', default = true })
  vim.api.nvim_set_hl(0, 'NvimDapVirtualTextInfo', { link = 'DiagnosticVirtualTextInfo', default = true })

  register_dap_listeners()
  return M
end

function M.render(frame)
  if not state.opts.enabled then
    return
  end
  render_frame(frame)
end

function M.set_error(frame, msg)
  state.stopped_frame = frame or state.stopped_frame
  state.error_msg = msg
  if state.stopped_frame and msg then
    set_message(state.stopped_frame, msg, 'NvimDapVirtualTextError', state.opts.virt_text_pos == 'inline')
  end
end
function M.set_info(frame, msg)
  state.stopped_frame = frame or state.stopped_frame
  state.info_msg = msg
  if state.stopped_frame and msg then
    set_message(state.stopped_frame, msg, 'NvimDapVirtualTextInfo', state.opts.virt_text_pos == 'inline')
  end
end

function M.set_frame(frame)
  state.stopped_frame = frame
end

function M.set_last_frames(frames)
  state.last_frames = frames or {}
end

return M
