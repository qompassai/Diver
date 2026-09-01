-- /qompassai/Diver/lua/config/core/lsp.lua
-- Qompass AI Diver Native LSP Core Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- -----------------------------------------------------
local M = {}
local api = vim.api
local diagnostic = vim.diagnostic
local g = vim.g
local levels = vim.log.levels
local lsp = vim.lsp
local uv = vim.uv
local traceback = debug.traceback
local lspmap = require('mappings.lspmap')
assert(type(lspmap.on_attach) == 'function', 'mappings.lspmap.on_attach must be a function')
local MODULE_NAME = 'config.core.lsp'
local METHOD = {
  completion = 'textDocument/completion',
  document_color = 'textDocument/documentColor',
  formatting = 'textDocument/formatting',
  inlay_hint = 'textDocument/inlayHint',
  inline_completion = 'textDocument/inlineCompletion',
  will_save_wait_until = 'textDocument/willSaveWaitUntil',
}
local GROUP = {
  core = api.nvim_create_augroup('LspCore', {
    clear = true,
  }),

  format = api.nvim_create_augroup('LspFormat', {
    clear = true,
  }),
}

local DIAGNOSTIC_ICONS = {
  [diagnostic.severity.ERROR] = ' ',
  [diagnostic.severity.HINT] = ' ',
  [diagnostic.severity.INFO] = ' ',
  [diagnostic.severity.WARN] = ' ',
}
local state = {
  attached = {},
  format_buffers = {},
  lsp_init_loaded = false,
  progress_at = {},
  setup = false,
}

local function feature_enabled(name, default)
  local value = g[name]

  if value == nil then
    return default
  end

  return value == true or value == 1
end

local function bounded_integer(value, default, minimum, maximum)
  local parsed = tonumber(value)

  if parsed == nil then
    return default
  end

  local result = math.floor(parsed)

  if result < minimum then
    return minimum
  end

  if result > maximum then
    return maximum
  end

  return result
end

local function valid_buffer(bufnr)
  return api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr)
end

local function buffer_scope(bufnr)
  return {
    bufnr = bufnr,
  }
end

local function supports(client, method, bufnr)
  if client:is_stopped() then
    return false
  end

  return client:supports_method(method, bufnr)
end

local function mark_attached(bufnr, client_id)
  local clients = state.attached[bufnr]

  if clients == nil then
    clients = {}

    state.attached[bufnr] = clients
  end

  if clients[client_id] then
    return false
  end

  clients[client_id] = true

  return true
end

local function unmark_attached(bufnr, client_id)
  local clients = state.attached[bufnr]

  if clients == nil then
    return
  end

  clients[client_id] = nil

  if next(clients) == nil then
    state.attached[bufnr] = nil
  end
end

local function set_global_option(name, value)
  api.nvim_set_option_value(name, value, {
    scope = 'global',
  })
end

local function setup_completion_options()
  set_global_option('autocomplete', true)

  set_global_option('autocompletedelay', 0)

  set_global_option('autocompletetimeout', 80)

  set_global_option('completetimeout', 150)

  set_global_option('completeitemalign', 'abbr,kind,menu')

  set_global_option('completeopt', 'menu,menuone,noselect,fuzzy')

  set_global_option('pumheight', 15)

  set_global_option('complete', '.^20,b^10,w^10')
end

local function setup_diagnostics()
  diagnostic.config({
    float = {
      border = 'rounded',
      focusable = false,
      scope = 'line',

      severity = {
        min = diagnostic.severity.WARN,
      },

      source = 'if_many',
    },

    severity_sort = true,

    signs = {
      numhl = {
        [diagnostic.severity.ERROR] = 'DiagnosticError',

        [diagnostic.severity.HINT] = 'DiagnosticHint',

        [diagnostic.severity.INFO] = 'DiagnosticInfo',

        [diagnostic.severity.WARN] = 'DiagnosticWarn',
      },

      severity = {
        min = diagnostic.severity.WARN,
      },

      text = {
        [diagnostic.severity.ERROR] = '󰅚 ',

        [diagnostic.severity.HINT] = '󰌶 ',

        [diagnostic.severity.INFO] = '󰋽 ',

        [diagnostic.severity.WARN] = '󰀪 ',
      },
    },

    underline = {
      severity = {
        min = diagnostic.severity.WARN,
      },
    },

    update_in_insert = false,
    virtual_lines = true,

    virtual_text = {
      prefix = function(item, index, total)
        local icon = DIAGNOSTIC_ICONS[item.severity] or DIAGNOSTIC_ICONS[diagnostic.severity.HINT]

        return string.format('%s%d/%d ', icon, index, total)
      end,

      severity = {
        min = diagnostic.severity.WARN,
      },

      source = 'if_many',
      spacing = 2,
    },
  })

  diagnostic.enable(true)
end

M.capabilities = vim.tbl_deep_extend('force', lsp.protocol.make_client_capabilities(), {
  textDocument = {
    completion = {
      completionItem = {
        commitCharactersSupport = true,

        deprecatedSupport = true,

        documentationFormat = {
          'markdown',
          'plaintext',
        },

        insertReplaceSupport = true,

        labelDetailsSupport = true,

        preselectSupport = true,

        resolveSupport = {
          properties = {
            'additionalTextEdits',
            'command',
            'detail',
            'documentation',
          },
        },

        snippetSupport = true,
      },

      contextSupport = true,
    },

    semanticTokens = {
      multilineTokenSupport = true,
    },
  },
})

local function configure_completion(client, bufnr)
  if not supports(client, METHOD.completion, bufnr) then
    return
  end

  local inline_only = supports(client, METHOD.inline_completion, bufnr)
    and feature_enabled('lsp_inline_completion', false)

  local popup_enabled = feature_enabled('lsp_popup_completion', true) and not inline_only

  if popup_enabled then
    lsp.completion.enable(true, client.id, bufnr, {
      autotrigger = true,
      commit_characters = true,
    })

    return
  end

  lsp.completion.enable(false, client.id, bufnr)
end

local function configure_document_colors(client, bufnr)
  local document_color = lsp.document_color

  if document_color == nil then
    return
  end

  if not supports(client, METHOD.document_color, bufnr) then
    return
  end

  document_color.enable(feature_enabled('lsp_document_colors', false), buffer_scope(bufnr))
end

local function configure_inlay_hints(client, bufnr)
  if not supports(client, METHOD.inlay_hint, bufnr) then
    return
  end

  lsp.inlay_hint.enable(feature_enabled('lsp_inlay_hints', false), buffer_scope(bufnr))
end

local function configure_inline_completion(client, bufnr)
  if not supports(client, METHOD.inline_completion, bufnr) then
    return
  end

  lsp.inline_completion.enable(feature_enabled('lsp_inline_completion', false), buffer_scope(bufnr))
end

local function configure_semantic_tokens(client, bufnr)
  if client.server_capabilities.semanticTokensProvider == nil then
    return
  end

  lsp.semantic_tokens.enable(feature_enabled('semantic_tokens_enabled', true), buffer_scope(bufnr))
end

local function formatting_clients(bufnr, include_will_save)
  local clients = lsp.get_clients({
    bufnr = bufnr,
    method = METHOD.formatting,
  })

  local result = {}

  for _, client in ipairs(clients) do
    local will_save = supports(client, METHOD.will_save_wait_until, bufnr)

    if include_will_save or not will_save then
      result[#result + 1] = client
    end
  end

  table.sort(result, function(left, right)
    return left.id < right.id
  end)

  return result
end

local function get_format_preference(bufnr)
  local ok, value = pcall(api.nvim_buf_get_var, bufnr, 'lsp_format_client')

  if not ok then
    return nil
  end

  if type(value) == 'string' then
    return value
  end

  if type(value) == 'number' then
    return tostring(value)
  end

  return nil
end

local function clear_format_preference(bufnr)
  pcall(api.nvim_buf_del_var, bufnr, 'lsp_format_client')
end

local function set_format_preference(bufnr, value)
  api.nvim_buf_set_var(bufnr, 'lsp_format_client', value)
end

local function select_format_client(bufnr, include_will_save)
  local clients = formatting_clients(bufnr, include_will_save)

  if #clients == 0 then
    return nil
  end

  local preferred = get_format_preference(bufnr)

  if preferred ~= nil then
    for _, client in ipairs(clients) do
      if client.name == preferred or tostring(client.id) == preferred then
        return client
      end
    end
  end

  return clients[1]
end

local function format_buffer(bufnr, include_will_save)
  if not valid_buffer(bufnr) then
    return false
  end

  local modifiable = api.nvim_get_option_value('modifiable', {
    buf = bufnr,
  })

  if modifiable ~= true then
    return false
  end

  local client = select_format_client(bufnr, include_will_save)

  if client == nil then
    return false
  end

  lsp.buf.format({
    async = false,
    bufnr = bufnr,
    id = client.id,

    timeout_ms = bounded_integer(g.lsp_format_timeout_ms, 1000, 100, 10000),
  })

  return true
end

local function ensure_format_autocmd(bufnr)
  if state.format_buffers[bufnr] then
    return
  end

  state.format_buffers[bufnr] = true

  api.nvim_create_autocmd('BufWritePre', {
    buffer = bufnr,

    callback = function(event)
      if not feature_enabled('lsp_format_on_save', true) then
        return
      end

      format_buffer(event.buf, false)
    end,

    desc = 'Format once with the selected native LSP client',

    group = GROUP.format,
  })
end

function M.on_attach(client, bufnr)
  if not valid_buffer(bufnr) then
    return
  end

  if not mark_attached(bufnr, client.id) then
    return
  end

  local ok, err = xpcall(function()
    configure_completion(client, bufnr)

    configure_document_colors(client, bufnr)

    configure_inlay_hints(client, bufnr)

    configure_inline_completion(client, bufnr)

    configure_semantic_tokens(client, bufnr)

    if supports(client, METHOD.formatting, bufnr) and not supports(client, METHOD.will_save_wait_until, bufnr) then
      ensure_format_autocmd(bufnr)
    end

    lspmap.on_attach({
      buf = bufnr,

      data = {
        client_id = client.id,
      },
    })
  end, traceback)

  if ok then
    return
  end

  unmark_attached(bufnr, client.id)

  vim.schedule(function()
    vim.notify(string.format('LSP attach failed for %s: %s', client.name, tostring(err)), levels.ERROR)
  end)
end

local function setup_commands()
  api.nvim_create_user_command('LspComplete', function()
    lsp.completion.get()
  end, {
    desc = 'Request native LSP completion',

    force = true,
  })

  api.nvim_create_user_command('LspFormat', function()
    local bufnr = api.nvim_get_current_buf()

    if not format_buffer(bufnr, true) then
      vim.notify('No attached LSP client supports document formatting', levels.WARN)
    end
  end, {
    desc = 'Format with the selected native LSP client',

    force = true,
  })

  api.nvim_create_user_command('LspFormatClient', function(command)
    local bufnr = api.nvim_get_current_buf()

    local argument = vim.trim(command.args)

    local clients = formatting_clients(bufnr, true)

    if argument == '' then
      local selected = select_format_client(bufnr, true)

      local names = {}

      for _, client in ipairs(clients) do
        names[#names + 1] = string.format('%s[%d]', client.name, client.id)
      end

      vim.notify(
        string.format(
          'Format client: %s; available: %s',
          selected and string.format('%s[%d]', selected.name, selected.id) or 'none',
          #names > 0 and table.concat(names, ', ') or 'none'
        )
      )

      return
    end

    if argument == 'auto' then
      clear_format_preference(bufnr)

      vim.notify('LSP formatter selection reset to first attached client')

      return
    end

    for _, client in ipairs(clients) do
      if client.name == argument or tostring(client.id) == argument then
        set_format_preference(bufnr, client.name)

        vim.notify(string.format('LSP formatter set to %s[%d]', client.name, client.id))

        return
      end
    end

    vim.notify(string.format('No attached formatting client matches %q', argument), levels.ERROR)
  end, {
    complete = function()
      local values = {
        'auto',
      }

      local bufnr = api.nvim_get_current_buf()

      for _, client in ipairs(formatting_clients(bufnr, true)) do
        values[#values + 1] = client.name

        values[#values + 1] = tostring(client.id)
      end

      table.sort(values)

      return values
    end,

    desc = 'Show or select the buffer LSP formatter; use auto to reset',

    force = true,

    nargs = '?',
  })

  api.nvim_create_user_command('LspInlayHintsToggle', function()
    local filter = buffer_scope(api.nvim_get_current_buf())

    lsp.inlay_hint.enable(not lsp.inlay_hint.is_enabled(filter), filter)
  end, {
    desc = 'Toggle native LSP inlay hints for the current buffer',

    force = true,
  })

  api.nvim_create_user_command('LspInlineCompletionToggle', function()
    local bufnr = api.nvim_get_current_buf()

    local filter = buffer_scope(bufnr)

    local enabled = not lsp.inline_completion.is_enabled(filter)

    lsp.inline_completion.enable(enabled, filter)

    local clients = lsp.get_clients({
      bufnr = bufnr,
    })

    for _, client in ipairs(clients) do
      if supports(client, METHOD.inline_completion, bufnr) and supports(client, METHOD.completion, bufnr) then
        if enabled then
          lsp.completion.enable(false, client.id, bufnr)
        elseif feature_enabled('lsp_popup_completion', true) then
          lsp.completion.enable(true, client.id, bufnr, {
            autotrigger = true,

            commit_characters = true,
          })
        end
      end
    end
  end, {
    desc = 'Toggle native LSP inline completion for the current buffer',

    force = true,
  })

  api.nvim_create_user_command('LspSemanticTokensToggle', function()
    local filter = buffer_scope(api.nvim_get_current_buf())

    lsp.semantic_tokens.enable(not lsp.semantic_tokens.is_enabled(filter), filter)
  end, {
    desc = 'Toggle native LSP semantic tokens for the current buffer',

    force = true,
  })

  api.nvim_create_user_command('LspVirtualLinesToggle', function()
    local config = diagnostic.config()

    local virtual_lines = config ~= nil and config.virtual_lines or false

    local enabled = virtual_lines == true or type(virtual_lines) == 'table'

    diagnostic.config({
      virtual_lines = not enabled,
    })
  end, {
    desc = 'Toggle diagnostic virtual lines',

    force = true,
  })
end

local function progress_key(data)
  if type(data) ~= 'table' then
    return '0'
  end

  local client_id = data.client_id

  if type(client_id) ~= 'number' and type(client_id) ~= 'string' then
    return '0'
  end

  return tostring(client_id)
end

local function update_terminal_progress(event)
  if not feature_enabled('lsp_terminal_progress', false) then
    return
  end

  local data = event.data

  if type(data) ~= 'table' then
    return
  end

  local params = data.params

  if type(params) ~= 'table' then
    return
  end

  local value = params.value

  if type(value) ~= 'table' then
    return
  end

  local key = progress_key(data)

  if value.kind == 'begin' then
    state.progress_at[key] = 0

    api.nvim_ui_send('\027]9;4;1;0\027\\')

    return
  end

  if value.kind == 'end' then
    state.progress_at[key] = nil

    api.nvim_ui_send('\027]9;4;0\027\\')

    return
  end

  if value.kind ~= 'report' then
    return
  end

  local now = uv.hrtime()

  local interval_ms = bounded_integer(g.lsp_progress_interval_ms, 100, 50, 1000)

  local last = state.progress_at[key] or 0

  if now - last < interval_ms * 1000000 then
    return
  end

  state.progress_at[key] = now

  local percentage = bounded_integer(value.percentage, 0, 0, 100)

  api.nvim_ui_send(string.format('\027]9;4;1;%d\027\\', percentage))
end

local function attached_client_from_event(event)
  local data = event.data

  if type(data) ~= 'table' then
    return nil
  end

  local event_client_id = data.client_id

  local clients = lsp.get_clients({
    bufnr = event.buf,
  })

  for _, client in ipairs(clients) do
    if client.id == event_client_id then
      return client
    end
  end

  return nil
end

local function detach_missing_clients(bufnr)
  local tracked = state.attached[bufnr]

  if tracked == nil then
    return
  end

  local active = {}

  local clients = lsp.get_clients({
    bufnr = bufnr,
  })

  for _, client in ipairs(clients) do
    active[client.id] = true
  end

  for client_id in pairs(tracked) do
    if not active[client_id] then
      unmark_attached(bufnr, client_id)
    end
  end
end

local function semantic_client_from_event(event)
  local data = event.data

  if type(data) ~= 'table' then
    return nil
  end

  local event_client_id = data.client_id

  local clients = lsp.get_clients({
    bufnr = event.buf,
  })

  for _, client in ipairs(clients) do
    if client.id == event_client_id then
      return client
    end
  end

  return nil
end

local function highlight_mutable_token(event)
  if not feature_enabled('lsp_mutable_variable_highlight', false) then
    return
  end

  if not valid_buffer(event.buf) then
    return
  end

  local data = event.data

  if type(data) ~= 'table' then
    return
  end

  local token = data.token

  if type(token) ~= 'table' then
    return
  end

  if token.type ~= 'variable' then
    return
  end

  if type(token.modifiers) == 'table' and token.modifiers.readonly then
    return
  end

  local client = semantic_client_from_event(event)

  if client == nil then
    return
  end

  if client.server_capabilities.semanticTokensProvider == nil then
    return
  end

  lsp.semantic_tokens.highlight_token(token, event.buf, client.id, 'MyMutableVariableHighlight')
end

local function setup_autocmds()
  api.nvim_create_autocmd('BufWipeout', {
    callback = function(event)
      state.attached[event.buf] = nil

      state.format_buffers[event.buf] = nil
    end,

    desc = 'Release native LSP buffer state',

    group = GROUP.core,
  })

  api.nvim_create_autocmd('LspAttach', {
    callback = function(event)
      local client = attached_client_from_event(event)

      if client == nil then
        return
      end

      M.on_attach(client, event.buf)
    end,

    desc = 'Configure native LSP features once per client and buffer',

    group = GROUP.core,
  })

  api.nvim_create_autocmd('LspDetach', {
    callback = function(event)
      local bufnr = event.buf

      vim.schedule(function()
        if api.nvim_buf_is_valid(bufnr) then
          detach_missing_clients(bufnr)
        end
      end)
    end,

    desc = 'Release native LSP client-buffer state',

    group = GROUP.core,
  })

  api.nvim_create_autocmd('LspProgress', {
    callback = update_terminal_progress,

    desc = 'Forward throttled LSP progress to supported terminals',

    group = GROUP.core,
  })

  api.nvim_create_autocmd('LspTokenUpdate', {
    callback = highlight_mutable_token,

    desc = 'Optionally highlight mutable variables from semantic tokens',

    group = GROUP.core,
  })
end

local function load_enabled_lsp_configs()
  if state.lsp_init_loaded then
    return true
  end

  package.loaded[MODULE_NAME] = M

  local ok, err = pcall(vim.cmd.runtime, 'lsp/init.lua')

  if not ok then
    vim.notify(string.format('Failed to load lsp/init.lua: %s', tostring(err)), levels.ERROR)

    return false
  end

  state.lsp_init_loaded = true

  return true
end

function M.setup()
  if state.setup then
    return
  end

  state.setup = true

  setup_completion_options()
  setup_diagnostics()
  setup_commands()
  setup_autocmds()

  lsp.config('*', {
    capabilities = M.capabilities,

    exit_timeout = bounded_integer(g.lsp_exit_timeout_ms, 500, 100, 10000),

    flags = {
      allow_incremental_sync = true,

      debounce_text_changes = bounded_integer(g.lsp_debounce_text_changes_ms, 250, 50, 1000),
    },

    workspace_required = false,
  })

  load_enabled_lsp_configs()
end

M.setup()

return M