-- #################################################################
-- /qompassai/lua/utils/codeactions.lua
-- Qompass AI Codeactions
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

local api = vim.api
local lsp = vim.lsp

local M = {}

local function report(title, lines)
  local buffer = api.nvim_create_buf(false, true)

  api.nvim_buf_set_name(buffer, ('%s-%d'):format(title, vim.uv.hrtime()))
  api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].filetype = 'markdown'
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].swapfile = false

  vim.cmd('botright new')
  api.nvim_win_set_buf(0, buffer)
end

local function action_summary(action)
  local fields = { action.title or '<untitled action>' }
  local command = action.command
  local command_id = type(command) == 'table' and command.command or command

  if action.kind then
    fields[#fields + 1] = 'kind=' .. action.kind
  end

  if action.isPreferred then
    fields[#fields + 1] = 'preferred'
  end

  if action.disabled then
    fields[#fields + 1] = 'disabled=' .. (action.disabled.reason or 'true')
  end

  if command_id then
    fields[#fields + 1] = 'command=' .. command_id
  end

  return table.concat(fields, '  |  ')
end

local function action_clients(buffer)
  return lsp.get_clients({
    bufnr = buffer,
    method = 'textDocument/codeAction',
  })
end

local function request_params(client)
  local position = vim.lsp.util.make_position_params(0, client.offset_encoding)

  return {
    textDocument = position.textDocument,
    range = {
      start = position.position,
      ['end'] = position.position,
    },
    context = {
      diagnostics = {},
    },
  }
end

local function collect_actions(done)
  local source_buffer = api.nvim_get_current_buf()
  local providers = action_clients(source_buffer)

  if #providers == 0 then
    vim.notify(
      'No attached LSP client supports textDocument/codeAction',
      vim.log.levels.WARN,
      { title = 'Code Actions' }
    )
    return
  end

  local results = {}
  local remaining = #providers

  for _, provider in ipairs(providers) do
    provider:request('textDocument/codeAction', request_params(provider), function(request_error, response)
      if request_error then
        results[#results + 1] = {
          client = provider,
          error = request_error.message or tostring(request_error),
        }
      else
        for _, code_action in ipairs(response or {}) do
          results[#results + 1] = {
            action = code_action,
            buffer = source_buffer,
            client = provider,
          }
        end
      end

      remaining = remaining - 1

      if remaining == 0 then
        vim.schedule(function()
          done(results, source_buffer)
        end)
      end
    end, source_buffer)
  end
end

local function edits_for_current_buffer(workspace_edit, source_buffer)
  if type(workspace_edit) ~= 'table' then
    return nil
  end

  local uri = vim.uri_from_bufnr(source_buffer)

  if type(workspace_edit.changes) == 'table' then
    return workspace_edit.changes[uri]
  end

  for _, change in ipairs(workspace_edit.documentChanges or {}) do
    if change.textDocument and change.textDocument.uri == uri then
      return change.edits
    end
  end

  return nil
end

local function changed_files(workspace_edit)
  local files = {}

  for uri in pairs(workspace_edit and workspace_edit.changes or {}) do
    files[#files + 1] = vim.uri_to_fname(uri)
  end

  for _, change in ipairs(workspace_edit and workspace_edit.documentChanges or {}) do
    if change.textDocument and change.textDocument.uri then
      files[#files + 1] = vim.uri_to_fname(change.textDocument.uri)
    end
  end

  table.sort(files)
  return files
end

local function byte_index(text, character, encoding)
  return vim.str_byteindex(text, encoding, character, false)
end

local function apply_text_edits(buffer, edits, encoding)
  local ordered = vim.deepcopy(edits)

  table.sort(ordered, function(left, right)
    local left_start = left.range.start
    local right_start = right.range.start

    if left_start.line ~= right_start.line then
      return left_start.line > right_start.line
    end

    return left_start.character > right_start.character
  end)

  for _, edit in ipairs(ordered) do
    local start = edit.range.start
    local finish = edit.range['end']

    local start_line = api.nvim_buf_get_lines(buffer, start.line, start.line + 1, false)[1] or ''

    local end_line = api.nvim_buf_get_lines(buffer, finish.line, finish.line + 1, false)[1] or ''

    local start_column = byte_index(start_line, start.character, encoding)

    local end_column = byte_index(end_line, finish.character, encoding)

    local replacement

    if edit.newText == '' then
      replacement = {}
    else
      replacement = vim.split(edit.newText, '\n', {
        plain = true,
      })
    end

    api.nvim_buf_set_text(buffer, start.line, start_column, finish.line, end_column, replacement)
  end
end

local function resolve_action(entry, done)
  if not entry.client:supports_method('codeAction/resolve', { bufnr = entry.buffer }) then
    done(entry.action)
    return
  end

  entry.client:request('codeAction/resolve', entry.action, function(resolve_error, resolved)
    if resolve_error then
      vim.notify(
        'Unable to resolve code action: ' .. (resolve_error.message or tostring(resolve_error)),
        vim.log.levels.WARN,
        { title = 'Code Actions' }
      )
      done(entry.action)
      return
    end

    done(resolved or entry.action)
  end, entry.buffer)
end

local function preview(entry)
  resolve_action(entry, function(action)
    local lines = {
      '# Code action preview',
      '',
      ('- Provider: `%s`'):format(entry.client.name),
      ('- Action: %s'):format(action_summary(action)),
      '',
    }

    local edits = edits_for_current_buffer(action.edit, entry.buffer)

    if not edits or #edits == 0 then
      lines[#lines + 1] = '## No previewable current-buffer edit'
      lines[#lines + 1] = ''

      if action.command then
        lines[#lines + 1] = 'This action is command-driven or changes another file.'
        lines[#lines + 1] = ''
        lines[#lines + 1] = '```lua'
        lines[#lines + 1] = vim.inspect(action.command)
        lines[#lines + 1] = '```'
      elseif action.edit then
        lines[#lines + 1] = 'This action edits files other than the current buffer:'
        lines[#lines + 1] = ''

        for _, path in ipairs(changed_files(action.edit)) do
          lines[#lines + 1] = ('- `%s`'):format(path)
        end
      else
        lines[#lines + 1] = 'The language server returned no edit or command payload.'
      end

      report('Code Action Preview', lines)
      return
    end

    local original = api.nvim_buf_get_lines(entry.buffer, 0, -1, false)
    local scratch = api.nvim_create_buf(false, true)

    api.nvim_buf_set_lines(scratch, 0, -1, false, original)

    apply_text_edits(scratch, edits, entry.client.offset_encoding or 'utf-16')

    local updated = api.nvim_buf_get_lines(scratch, 0, -1, false)
    api.nvim_buf_delete(scratch, { force = true })

    local before = table.concat(original, '\n') .. '\n'
    local after = table.concat(updated, '\n') .. '\n'
    local diff_result = vim.text.diff(before, after, {
      result_type = 'unified',
    })
    local diff = type(diff_result) == 'string' and diff_result or ''

    lines[#lines + 1] = '## Current-buffer diff'
    lines[#lines + 1] = ''
    lines[#lines + 1] = '```diff'

    if diff == '' then
      lines[#lines + 1] = 'No textual change.'
    else
      for diff_line in diff:gmatch('[^\n]+') do
        lines[#lines + 1] = diff_line
      end
    end

    lines[#lines + 1] = '```'

    report('Code Action Preview', lines)
  end)
end

function M.list_here()
  collect_actions(function(collected, source_buffer)
    local lines = {
      '# Code actions at cursor',
      '',
      ('- Buffer: `%s`'):format(api.nvim_buf_get_name(source_buffer)),
      '',
    }

    local grouped = {}

    for _, entry in ipairs(collected) do
      local name = entry.client.name
      grouped[name] = grouped[name] or {}
      grouped[name][#grouped[name] + 1] = entry
    end

    for _, provider in ipairs(action_clients(source_buffer)) do
      local entries = grouped[provider.name] or {}

      lines[#lines + 1] = ('## %s'):format(provider.name)
      lines[#lines + 1] = ''

      if #entries == 0 then
        lines[#lines + 1] = '- No actions available at this cursor position.'
      else
        for _, entry in ipairs(entries) do
          if entry.error then
            lines[#lines + 1] = ('- Request failed: `%s`'):format(entry.error)
          else
            lines[#lines + 1] = ('- %s'):format(action_summary(entry.action))
          end
        end
      end

      lines[#lines + 1] = ''
    end

    report('Code Actions', lines)
  end)
end

function M.pick_preview()
  collect_actions(function(collected)
    local choices = {}

    for _, entry in ipairs(collected) do
      if entry.action then
        choices[#choices + 1] = entry
      end
    end

    if #choices == 0 then
      vim.notify(
        'No code actions are available at this cursor position',
        vim.log.levels.INFO,
        { title = 'Code Actions' }
      )
      return
    end

    vim.ui.select(choices, {
      prompt = 'Preview code action:',
      format_item = function(entry)
        return ('[%s] %s'):format(entry.client.name, action_summary(entry.action))
      end,
    }, function(choice)
      if choice then
        preview(choice)
      end
    end)
  end)
end

function M.list_clients()
  local source_buffer = api.nvim_get_current_buf()
  local lines = {
    '# Attached LSP clients',
    '',
  }

  for _, client in ipairs(lsp.get_clients({ bufnr = source_buffer })) do
    local available = client:supports_method('textDocument/codeAction', { bufnr = source_buffer })

    lines[#lines + 1] = ('- `%s`'):format(client.name)
    lines[#lines + 1] = ('  - ID: `%d`'):format(client.id)
    lines[#lines + 1] = ('  - Code actions: `%s`'):format(available and 'yes' or 'no')
  end

  report('Code Action Clients', lines)
end

function M.list_kinds()
  local source_buffer = api.nvim_get_current_buf()
  local lines = {
    '# Advertised code-action kinds',
    '',
  }

  for _, client in ipairs(action_clients(source_buffer)) do
    local provider = client.server_capabilities.codeActionProvider
    local kinds = type(provider) == 'table' and provider.codeActionKinds or nil

    lines[#lines + 1] = ('## %s'):format(client.name)
    lines[#lines + 1] = ''

    if not kinds or #kinds == 0 then
      lines[#lines + 1] = '- No static kind catalog advertised.'
      lines[#lines + 1] = '- Use `:CodeActionsHere` on a diagnostic or selection.'
    else
      for _, kind in ipairs(kinds) do
        lines[#lines + 1] = ('- `%s`'):format(kind)
      end
    end

    lines[#lines + 1] = ''
  end

  report('Code Action Kinds', lines)
end

function M.setup()
  api.nvim_create_user_command('CodeActionsHere', M.list_here, {
    desc = 'List code actions at the cursor by LSP provider',
  })

  api.nvim_create_user_command('CodeActionClients', M.list_clients, {
    desc = 'List attached LSP clients and code-action support',
  })

  api.nvim_create_user_command('CodeActionKinds', M.list_kinds, {
    desc = 'List advertised LSP code-action kinds',
  })

  api.nvim_create_user_command('CodeActionPreview', M.pick_preview, {
    desc = 'Preview a code action without changing the current buffer',
  })

  vim.keymap.set({ 'n', 'x' }, '<leader>ca', function()
    lsp.buf.code_action()
  end, {
    desc = 'Code action',
  })

  vim.keymap.set('n', '<leader>cA', M.list_here, {
    desc = 'Code actions at cursor',
  })

  vim.keymap.set('n', '<leader>cC', M.list_clients, {
    desc = 'Code action clients',
  })

  vim.keymap.set('n', '<leader>cK', M.list_kinds, {
    desc = 'Code action kinds',
  })

  vim.keymap.set('n', '<leader>cP', M.pick_preview, {
    desc = 'Code action preview',
  })
end

return M
