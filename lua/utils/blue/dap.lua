#!/usr/bin/env lua

-- dap.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local ns = vim.api.nvim_create_namespace("dap-virtual-text-util")
local plugin_id = "dap-virtual-text-util"
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
  virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",
  virt_lines = false,
  virt_lines_above = true,
  virt_text_win_col = nil,
  text_prefix = "",
  separator = ", ",
  error_prefix = "  ",
  info_prefix = "  ",
  filter_references_pattern = "<module",
  display_callback = function(variable, _, _, _, opts)
    local value = tostring(variable.value or ""):gsub("%s+", " ")
    if opts.virt_text_pos == "inline" then
      return " = " .. value
    end
    return string.format("%s = %s", variable.name, value)
  end,
}

local state = {
  opts = vim.deepcopy(defaults),
  last_frames = {},
  stopped_frame = nil,
  error_msg = nil,
  info_msg = nil,
}

local function get_query(lang, name)
  return vim.treesitter.query.get(lang, name)
end

local function get_parser(buf, ft)
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

local function variables_from_scopes(scopes, lang)
  local vars = {}
  for _, scope in ipairs(scopes or {}) do
    for _, v in pairs(scope.variables or {}) do
      local key = lang == "php" and v.name:gsub("^%$", "") or v.name
      if not vars[key] or vars[key].presentationHint ~= "locals" then
        vars[key] = { value = v, presentationHint = scope.presentationHint }
      end
    end
  end
  return vars
end

local function clear_buf(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.clear(frame)
  if frame and frame.source and frame.source.path then
    clear_buf(vim.uri_to_bufnr(vim.uri_from_fname(frame.source.path)))
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    clear_buf(buf)
  end
end

local function set_message(frame, msg, hl, inline)
  if not frame or not frame.source or not frame.source.path or not frame.line then
    return
  end
  local buf = vim.uri_to_bufnr(vim.uri_from_fname(frame.source.path))
  local text = msg
  if state.opts.commented then
    text = vim.bo[buf].commentstring:gsub("%%s", text)
  end
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, frame.line - 1, 0, {
    hl_mode = "combine",
    virt_text = { { text, hl } },
    virt_text_pos = inline and "eol" or state.opts.virt_text_pos,
  })
end

local function collect_nodes(buf, parser, all_references)
  local scope_nodes, def_nodes = {}, {}
  parser:parse()
  parser:for_each_tree(function(tree, ltree)
    local query = get_query(ltree:lang(), "locals")
    if not query then
      return
    end
    for _, match in query:iter_matches(tree:root(), buf, 0, -1) do
      for id, nodes in pairs(match) do
        nodes = type(nodes) == "table" and nodes or { nodes }
        local cap = query.captures[id]
        for _, node in ipairs(nodes) do
          if cap:find("scope", 1, true) then
            table.insert(scope_nodes, node)
          elseif cap:find("definition", 1, true) or (all_references and cap:find("reference", 1, true)) then
            table.insert(def_nodes, node)
          end
        end
      end
    end
  end)
  return scope_nodes, def_nodes
end

local function in_scope(scope_nodes, node, frame_line)
  local row, col = node:start()
  for _, scope in ipairs(scope_nodes) do
    local sr, sc, ერ, ec = scope:range()
    local inside_var = (row > sr or (row == sr and col >= sc)) and (row < ერ or (row == ერ and col < ec))
    local stop_row = frame_line - 1
    local inside_stop = (stop_row > sr or (stop_row == sr and 0 >= sc)) and (stop_row < ერ or (stop_row == ერ and 0 < ec))
    if inside_var and not inside_stop then
      return false
    end
  end
  return true
end

local function extmark_for_content(buf, line, chunks, inline)
  local line_text = vim.api.nvim_buf_get_lines(buf, line, line + 1, true)[1] or ""
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
      hl_mode = "combine",
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
  if ft == "" then
    ft = vim.filetype.match({ buf = buf }) or ""
    if ft == "" then
      return
    end
  end

  local parser, lang = get_parser(buf, ft)
  if not parser then
    return
  end

  local scope_nodes, def_nodes = collect_nodes(buf, parser, state.opts.all_references)
  local vars = variables_from_scopes(frame.scopes, lang)
  local last_scopes = state.last_frames[frame.id] and state.last_frames[frame.id].scopes or {}
  local last_vars = variables_from_scopes(last_scopes, lang)
  local get_node_text = vim.treesitter.get_node_text
  local inline = state.opts.virt_text_pos == "inline"
  local by_line, seen = {}, {}

  for _, node in ipairs(def_nodes) do
    local name = get_node_text(node, buf)
    local current = vars[name] and vars[name].value or nil
    local previous = last_vars[name] and last_vars[name].value or nil

    if current and not (state.opts.filter_references_pattern and tostring(current.value):find(state.opts.filter_references_pattern)) then
      if in_scope(scope_nodes, node, frame.line) then
        if state.opts.only_first_definition and not state.opts.all_references then
          vars[name] = nil
        end
        if not seen[node:id()] then
          seen[node:id()] = true
          local changed = state.opts.highlight_changed_variables
            and (current.value ~= (previous and previous.value))
            and (state.opts.highlight_new_as_changed or previous)

          local text = state.opts.display_callback(current, buf, frame, node, state.opts)
          if text then
            if state.opts.commented then
              text = vim.bo[buf].commentstring:gsub("%%s", text)
            end
            text = state.opts.text_prefix .. text
            local row = node:start()
            by_line[row] = by_line[row] or {}
            table.insert(by_line[row], {
              text,
              changed and "NvimDapVirtualTextChanged" or "NvimDapVirtualText",
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

function M.refresh(session)
  local dap = require("dap")
  session = session or dap.session()
  M.clear()
  if not state.opts.enabled or not session then
    return
  end

  if state.opts.all_frames and session.threads and session.threads[session.stopped_thread_id] then
    for _, frame in pairs(session.threads[session.stopped_thread_id].frames or {}) do
      render_frame(frame)
    end
  else
    render_frame(session.current_frame)
  end

  if state.error_msg then
    set_message(state.stopped_frame, state.error_msg, "NvimDapVirtualTextError", state.opts.virt_text_pos == "inline")
  end
  if state.info_msg then
    set_message(state.stopped_frame, state.info_msg, "NvimDapVirtualTextInfo", state.opts.virt_text_pos == "inline")
  end
end

function M.enable()
  state.opts.enabled = true
  M.refresh()
end

function M.disable()
  state.opts.enabled = false
  M.refresh()
end

function M.toggle()
  state.opts.enabled = not state.opts.enabled
  M.refresh()
end

function M.setup(opts)
  local dap = require("dap")
  state.opts = vim.tbl_deep_extend("force", state.opts, opts or {})

  vim.api.nvim_set_hl(0, "NvimDapVirtualText", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "NvimDapVirtualTextChanged", { link = "DiagnosticVirtualTextWarn", default = true })
  vim.api.nvim_set_hl(0, "NvimDapVirtualTextError", { link = "DiagnosticVirtualTextError", default = true })
  vim.api.nvim_set_hl(0, "NvimDapVirtualTextInfo", { link = "DiagnosticVirtualTextInfo", default = true })

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
    if event and event.reason == "exception" then
      state.error_msg = state.opts.error_prefix .. "Stopped due to exception"
    elseif event and event.reason == "data breakpoint" then
      state.info_msg = state.opts.info_prefix .. "Stopped due to data breakpoint"
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
    local typename = response.details and response.details.typeName or ""
    local desc = response.description or ""
    state.error_msg = state.opts.error_prefix
      .. typename
      .. ((typename ~= "" and desc ~= "") and ": " or "")
      .. desc
  end

  return M
end

return M
