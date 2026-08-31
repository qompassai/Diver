-- /qompassai/Diver/lua/config/core/lsp.lua
-- Qompass AI Diver Native LSP Core Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- -----------------------------------------------------
local M = {}
local api = vim.api
local diagnostic = vim.diagnostic
local g = vim.g
local lsp = vim.lsp
local opt = vim.opt
local uv = vim.uv
local lspmap = require('mappings.lspmap')
assert(type(lspmap.on_attach) == 'function', 'mappings.lspmap.on_attach must be a function')
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
  [diagnostic.severity.WARN] = ' ',
  [diagnostic.severity.INFO] = ' ',
  [diagnostic.severity.HINT] = ' ',
}

---@class LspState
---@field attached table<integer, table<integer, true>>
---@field format_buffers table<integer, true>
---@field progress_at table<integer, integer>
---@field setup boolean

---@type LspState
local state = {
  attached = {},
  format_buffers = {},
  progress_at = {},
  setup = false,
}

---@param name string
---@param default boolean
---@return boolean
local function feature_enabled(name, default)
  local value = g[name]
  if value == nil then
    return default
  end
  return value == true or value == 1
end

---@param value unknown
---@param default integer
---@param minimum integer
---@param maximum integer
---@return integer
local function bounded_integer(value, default, minimum, maximum)
  local number = tonumber(value)
  if not number then
    return default
  end
  number = math.floor(number)
  return math.max(minimum, math.min(maximum, number))
end

---@param bufnr integer
---@return boolean
local function valid_buffer(bufnr)
  return api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr)
end

---@param bufnr integer
---@return { bufnr: integer }
local function buffer_scope(bufnr)
  return {
    bufnr = bufnr,
  }
end

---@param client vim.lsp.Client
---@param method string
---@param bufnr integer
---@return boolean
local function supports(client, method, bufnr)
  return not client:is_stopped() and client:supports_method(method, bufnr)
end

---@param bufnr integer
---@param client_id integer
---@return boolean
local function mark_attached(bufnr, client_id)
  state.attached[bufnr] = state.attached[bufnr] or {}
  if state.attached[bufnr][client_id] then
    return false
  end
  state.attached[bufnr][client_id] = true
  return true
end

---@param bufnr integer
---@param client_id integer
local function unmark_attached(bufnr, client_id)
  local clients = state.attached[bufnr]
  if not clients then
    return
  end
  clients[client_id] = nil
  if next(clients) == nil then
    state.attached[bufnr] = nil
  end
end

local function setup_completion_options()
  vim.o.autocomplete = true
  vim.o.autocompletedelay = 0
  vim.o.autocompletetimeout = 80
  vim.o.completetimeout = 150
  vim.o.completeitemalign = 'abbr,kind,menu'
  vim.o.completeopt = 'menu,menuone,noselect,fuzzy'
  vim.o.pumheight = 15

  opt.complete = {
    '.^20',
    'w^10',
    'b^10',
  }
end

local function setup_diagnostics()
  diagnostic.config({
    update_in_insert = false,
    severity_sort = true,
    float = {
      border = 'rounded',
      focusable = false,
      scope = 'line',
      source = 'if_many',
      severity = {
        min = diagnostic.severity.WARN,
      },
    },
    signs = {
      severity = {
        min = diagnostic.severity.WARN,
      },
      text = {
        [diagnostic.severity.ERROR] = '󰅚 ',
        [diagnostic.severity.WARN] = '󰀪 ',
        [diagnostic.severity.INFO] = '󰋽 ',
        [diagnostic.severity.HINT] = '󰌶 ',
      },
      numhl = {
        [diagnostic.severity.ERROR] = 'DiagnosticError',
        [diagnostic.severity.WARN] = 'DiagnosticWarn',
        [diagnostic.severity.INFO] = 'DiagnosticInfo',
        [diagnostic.severity.HINT] = 'DiagnosticHint',
      },
    },
    underline = {
      severity = {
        min = diagnostic.severity.WARN,
      },
    },
    virtual_lines = true,
    virtual_text = {
      source = 'if_many',
      spacing = 2,
      severity = {
        min = diagnostic.severity.WARN,
      },
      prefix = function(item, index, total)
        ---@cast item vim.Diagnostic
        local icon = DIAGNOSTIC_ICONS[item.severity] or DIAGNOSTIC_ICONS[diagnostic.severity.HINT]
        return string.format('%s%d/%d ', icon, index, total)
      end,
    },
  })
  diagnostic.enable(true)
end

M.capabilities = vim.tbl_deep_extend('force', lsp.protocol.make_client_capabilities(), {
  textDocument = {
    completion = {
      contextSupport = true,
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
            'documentation',
            'detail',
          },
        },
        snippetSupport = true,
      },
    },
    semanticTokens = {
      multilineTokenSupport = true,
    },
  },
})

---@param client vim.lsp.Client
---@param bufnr integer
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
  else
    lsp.completion.enable(false, client.id, bufnr)
  end
end

---@param client vim.lsp.Client
---@param bufnr integer
local function configure_inline_completion(client, bufnr)
  if not supports(client, METHOD.inline_completion, bufnr) then
    return
  end
  lsp.inline_completion.enable(feature_enabled('lsp_inline_completion', false), buffer_scope(bufnr))
end

---@param client vim.lsp.Client
---@param bufnr integer
local function configure_inlay_hints(client, bufnr)
  if not supports(client, METHOD.inlay_hint, bufnr) then
    return
  end
  lsp.inlay_hint.enable(feature_enabled('lsp_inlay_hints', false), buffer_scope(bufnr))
end

---@param client vim.lsp.Client
---@param bufnr integer
local function configure_semantic_tokens(client, bufnr)
  if not client.server_capabilities.semanticTokensProvider then
    return
  end
  lsp.semantic_tokens.enable(feature_enabled('semantic_tokens_enabled', true), buffer_scope(bufnr))
end

---@param client vim.lsp.Client
---@param bufnr integer
local function configure_document_colors(client, bufnr)
  if not lsp.document_color or not supports(client, METHOD.document_color, bufnr) then
    return
  end
  lsp.document_color.enable(feature_enabled('lsp_document_colors', false), buffer_scope(bufnr))
end

---@param bufnr integer
---@param include_will_save boolean
---@return vim.lsp.Client[]
local function formatting_clients(bufnr, include_will_save)
  local clients = lsp.get_clients({
    bufnr = bufnr,
    method = METHOD.formatting,
  })

  local result = {} ---@type vim.lsp.Client[]
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

---@param bufnr integer
---@param include_will_save boolean
---@return vim.lsp.Client?
local function select_format_client(bufnr, include_will_save)
  local clients = formatting_clients(bufnr, include_will_save)
  if #clients == 0 then
    return nil
  end

  local preferred = vim.b[bufnr].lsp_format_client
  if preferred ~= nil and preferred ~= '' then
    local preferred_id = tonumber(preferred)
    for _, client in ipairs(clients) do
      if client.id == preferred_id or client.name == preferred then
        return client
      end
    end
  end

  -- First attached formatter wins unless the buffer explicitly selects one.
  return clients[1]
end

---@param bufnr integer
---@param include_will_save boolean
---@return boolean
local function format_buffer(bufnr, include_will_save)
  if not valid_buffer(bufnr) or not vim.bo[bufnr].modifiable then
    return false
  end

  local client = select_format_client(bufnr, include_will_save)
  if not client then
    return false
  end

  local timeout_ms = bounded_integer(g.lsp_format_timeout_ms, 1000, 100, 10000)
  lsp.buf.format({
    async = false,
    bufnr = bufnr,
    id = client.id,
    timeout_ms = timeout_ms,
  })
  return true
end

---@param bufnr integer
local function ensure_format_autocmd(bufnr)
  if state.format_buffers[bufnr] then
    return
  end
  state.format_buffers[bufnr] = true

  api.nvim_create_autocmd('BufWritePre', {
    buffer = bufnr,
    desc = 'Format once with the selected native LSP client',
    group = GROUP.format,
    callback = function(event)
      if not feature_enabled('lsp_format_on_save', true) then
        return
      end
      format_buffer(event.buf, false)
    end,
  })
end

---@param client vim.lsp.Client
---@param bufnr integer
function M.on_attach(client, bufnr)
  if not valid_buffer(bufnr) or not mark_attached(bufnr, client.id) then
    return
  end

  local ok, err = xpcall(function()
    configure_completion(client, bufnr)
    configure_inline_completion(client, bufnr)
    configure_inlay_hints(client, bufnr)
    configure_semantic_tokens(client, bufnr)
    configure_document_colors(client, bufnr)

    if supports(client, METHOD.formatting, bufnr) and not supports(client, METHOD.will_save_wait_until, bufnr) then
      ensure_format_autocmd(bufnr)
    end

    lspmap.on_attach({
      buf = bufnr,
      data = {
        client_id = client.id,
      },
    })
  end, debug.traceback)

  if ok then
    return
  end

  unmark_attached(bufnr, client.id)
  vim.schedule(function()
    vim.notify(string.format('LSP attach failed for %s: %s', client.name, err), vim.log.levels.ERROR)
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
      vim.notify('No attached LSP client supports document formatting', vim.log.levels.WARN)
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
      vim.b[bufnr].lsp_format_client = nil
      vim.notify('LSP formatter selection reset to first attached client')
      return
    end

    local requested_id = tonumber(argument)
    for _, client in ipairs(clients) do
      if client.id == requested_id or client.name == argument then
        vim.b[bufnr].lsp_format_client = client.name
        vim.notify(string.format('LSP formatter set to %s[%d]', client.name, client.id))
        return
      end
    end

    vim.notify(string.format('No attached formatting client matches %q', argument), vim.log.levels.ERROR)
  end, {
    nargs = '?',
    desc = 'Show or select the buffer LSP formatter; use auto to reset',
    force = true,
    complete = function()
      local values = {
        'auto',
      }
      for _, client in ipairs(formatting_clients(api.nvim_get_current_buf(), true)) do
        values[#values + 1] = client.name
      end
      return values
    end,
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
    local buffer_filter = buffer_scope(bufnr)
    local enable_inline = not lsp.inline_completion.is_enabled(buffer_filter)

    lsp.inline_completion.enable(enable_inline, buffer_filter)

    for _, client in
      ipairs(lsp.get_clients({
        bufnr = bufnr,
      }))
    do
      if supports(client, METHOD.inline_completion, bufnr) then
        if supports(client, METHOD.completion, bufnr) then
          if enable_inline then
            lsp.completion.enable(false, client.id, bufnr)
          elseif feature_enabled('lsp_popup_completion', true) then
            lsp.completion.enable(true, client.id, bufnr, {
              autotrigger = true,
              commit_characters = true,
            })
          end
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
    local current = diagnostic.config().virtual_lines
    diagnostic.config({
      virtual_lines = not current,
    })
  end, {
    desc = 'Toggle diagnostic virtual lines',
    force = true,
  })
end

local function update_terminal_progress(event)
  if not feature_enabled('lsp_terminal_progress', false) then
    return
  end

  local data = event.data
  local params = data and data.params
  local value = params and params.value
  if type(value) ~= 'table' then
    return
  end

  local client_id = tonumber(data.client_id) or 0
  if value.kind == 'begin' then
    state.progress_at[client_id] = 0
    api.nvim_ui_send('\027]9;4;1;0\027\\')
    return
  end
  if value.kind == 'end' then
    state.progress_at[client_id] = nil
    api.nvim_ui_send('\027]9;4;0\027\\')
    return
  end
  if value.kind ~= 'report' then
    return
  end

  local now = uv.hrtime()
  local interval_ms = bounded_integer(g.lsp_progress_interval_ms, 100, 50, 1000)
  local last = state.progress_at[client_id] or 0
  if now - last < interval_ms * 1000000 then
    return
  end
  state.progress_at[client_id] = now

  local percentage = bounded_integer(value.percentage, 0, 0, 100)
  api.nvim_ui_send(string.format('\027]9;4;1;%d\027\\', percentage))
end

local function setup_autocmds()
  api.nvim_create_autocmd('LspAttach', {
    desc = 'Configure native LSP features once per client and buffer',
    group = GROUP.core,
    callback = function(event)
      local client_id = event.data and event.data.client_id
      if not client_id then
        return
      end
      local client = lsp.get_client_by_id(client_id)
      if client then
        M.on_attach(client, event.buf)
      end
    end,
  })

  api.nvim_create_autocmd('LspDetach', {
    desc = 'Release native LSP client-buffer state',
    group = GROUP.core,
    callback = function(event)
      local client_id = event.data and event.data.client_id
      if client_id then
        unmark_attached(event.buf, client_id)
      end
    end,
  })

  api.nvim_create_autocmd('BufWipeout', {
    desc = 'Release native LSP buffer state',
    group = GROUP.core,
    callback = function(event)
      state.attached[event.buf] = nil
      state.format_buffers[event.buf] = nil
    end,
  })

  api.nvim_create_autocmd('LspProgress', {
    desc = 'Forward throttled LSP progress to supported terminals',
    group = GROUP.core,
    callback = update_terminal_progress,
  })

  api.nvim_create_autocmd('LspTokenUpdate', {
    desc = 'Optionally highlight mutable variables from semantic tokens',
    group = GROUP.core,
    callback = function(event)
      if not feature_enabled('lsp_mutable_variable_highlight', false) then
        return
      end
      if not valid_buffer(event.buf) or not event.data then
        return
      end

      local token = event.data.token
      if not token or token.type ~= 'variable' then
        return
      end
      if token.modifiers and token.modifiers.readonly then
        return
      end

      lsp.semantic_tokens.highlight_token(token, event.buf, event.data.client_id, 'MyMutableVariableHighlight')
    end,
  })
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
  vim.cmd.runtime('lsp/init.lua')
end

M.setup()

return M