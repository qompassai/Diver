-- /qompassai/Diver/lua/mappings/lspmap.lua
-- Qompass AI Diver Language Server Protocol mappings
-- Neovim 0.13+

local M = {}

local api = vim.api
local diagnostic = vim.diagnostic
local lsp = vim.lsp

M.rust_editions = {
  ['2021'] = '2021',
  ['2024'] = '2024',
}

M.rust_toolchains = {
  stable = 'stable',
  beta = 'beta',
  nightly = 'nightly',
}

M.rust_default_edition = '2024'
M.rust_default_toolchain = 'nightly'
M.current_edition = M.rust_default_edition
M.current_toolchain = M.rust_default_toolchain

---@alias LspAttachArgs { buf: integer, data: { client_id: integer } }

---@param level integer
---@param message string
local function notify(level, message)
  vim.notify(message, level, {
    title = 'Diver LSP',
  })
end

---@param bufnr integer
---@param method string
---@return boolean
local function supports_method(bufnr, method)
  for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method(method) then
      return true
    end
  end

  return false
end

---@param name string
---@param callback fun(argument: string)
---@param options any
local function user_command(name, callback, options)
  pcall(api.nvim_del_user_command, name)

  api.nvim_create_user_command(name, function(command)
    ---@cast command { args: string }
    callback(command.args)
  end, options)
end

---@param edition string
function M.rust_edition(edition)
  if M.rust_editions[edition] == nil then
    notify(vim.log.levels.ERROR, 'Invalid Rust edition: ' .. tostring(edition))
    return
  end

  M.current_edition = edition
  notify(vim.log.levels.INFO, 'Rust edition set to ' .. edition)
  vim.cmd('LspRestart')
end

---@param toolchain string
function M.rust_set_toolchain(toolchain)
  if M.rust_toolchains[toolchain] == nil then
    notify(vim.log.levels.ERROR, 'Invalid Rust toolchain: ' .. tostring(toolchain))
    return
  end

  M.current_toolchain = toolchain
  notify(vim.log.levels.INFO, 'Rust toolchain set to ' .. toolchain)
  vim.cmd('LspRestart')
end

local function attached_client_names()
  local names = {}

  for _, client in ipairs(lsp.get_clients({ bufnr = 0 })) do
    names[#names + 1] = client.name
  end

  return vim.fn.uniq(vim.fn.sort(names))
end

local function setup_commands()
  user_command('LspStart', function(argument)
    local name = argument ~= '' and argument or vim.bo.filetype

    if name == '' then
      notify(vim.log.levels.ERROR, 'LspStart: missing server name')
      return
    end

    local ok, err = pcall(lsp.enable, name)

    if not ok then
      notify(vim.log.levels.ERROR, ('LspStart: failed to enable %s: %s'):format(name, err))
      return
    end

    vim.cmd('edit')
    notify(vim.log.levels.INFO, 'Enabled LSP: ' .. name)
  end, {
    nargs = '?',
    complete = function()
      return vim.tbl_keys(lsp.config)
    end,
    desc = 'Enable an LSP configuration for the current buffer',
  })

  user_command('LspStop', function(argument)
    local name = argument ~= '' and argument or nil
    local clients = lsp.get_clients({
      bufnr = api.nvim_get_current_buf(),
      name = name,
    })

    if #clients == 0 then
      notify(
        vim.log.levels.WARN,
        name and ('No running LSP named: ' .. name) or 'No LSP clients are attached to this buffer'
      )
      return
    end

    for _, client in ipairs(clients) do
      client:stop()
    end

    if name ~= nil then
      pcall(lsp.enable, name, false)
    end

    notify(vim.log.levels.INFO, name and ('Stopped LSP: ' .. name) or 'Stopped LSP clients for this buffer')
  end, {
    nargs = '?',
    complete = attached_client_names,
    desc = 'Stop current-buffer LSP client(s)',
  })

  user_command('LspRestart', function(argument)
    local requested_name = argument ~= '' and argument or nil
    local bufnr = api.nvim_get_current_buf()
    local clients = lsp.get_clients({
      bufnr = bufnr,
      name = requested_name,
    })
    local names = {}

    for _, client in ipairs(clients) do
      client:stop()
      names[client.name] = true
    end

    if requested_name ~= nil then
      names[requested_name] = true
    end

    if vim.tbl_isempty(names) then
      notify(vim.log.levels.WARN, 'No LSP clients to restart for this buffer')
      return
    end

    vim.defer_fn(function()
      for name in pairs(names) do
        local ok, err = pcall(lsp.enable, name)

        if not ok then
          notify(vim.log.levels.ERROR, ('LspRestart: failed to enable %s: %s'):format(name, err))
        end
      end

      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_call(bufnr, function()
          vim.cmd('edit')
        end)
      end
    end, 100)
  end, {
    nargs = '?',
    complete = attached_client_names,
    desc = 'Restart current-buffer LSP client(s)',
  })

  user_command('LspInfo', function()
    local bufnr = api.nvim_get_current_buf()
    local clients = lsp.get_clients({ bufnr = bufnr })

    if #clients == 0 then
      notify(vim.log.levels.INFO, 'No LSP clients are attached to this buffer')
      return
    end

    local lines = { ('LSP clients for buffer %d:'):format(bufnr) }

    for _, client in ipairs(clients) do
      lines[#lines + 1] = ('- %s (id=%d)'):format(client.name, client.id)
    end

    notify(vim.log.levels.INFO, table.concat(lines, '\n'))
  end, {
    desc = 'Show LSP clients attached to the current buffer',
  })

  user_command('RustEdition', function(argument)
    M.rust_edition(argument)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.rust_editions)
    end,
    desc = 'Select Rust edition and restart LSP clients',
  })

  user_command('RustToolchain', function(argument)
    M.rust_set_toolchain(argument)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.rust_toolchains)
    end,
    desc = 'Select Rust toolchain and restart LSP clients',
  })
end

---@param bufnr integer
local function setup_buffer_maps(bufnr)
  local function map(mode, lhs, rhs, description)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = bufnr,
      silent = true,
      desc = description,
    })
  end

  map('n', 'ca', lsp.buf.code_action, 'Code actions')

  map('n', 'gd', function()
    if not supports_method(bufnr, 'textDocument/definition') then
      notify(vim.log.levels.WARN, 'No LSP supports textDocument/definition for this buffer')
      return
    end

    lsp.buf.definition({
      pos = vim.pos.cursor(bufnr, api.nvim_win_get_cursor(0)),
      loclist = true,
    })
  end, 'Go to definition')

  map('n', 'gI', lsp.buf.implementation, 'Go to implementation')
  map('n', 'K', lsp.buf.hover, 'Show hover information')
  map('n', 'gs', lsp.buf.document_symbol, 'Show document symbols')
  map('n', 'gw', lsp.buf.workspace_symbol, 'Show workspace symbols')
  map('n', '<leader>rn', lsp.buf.rename, 'Rename symbol')

  map('n', 'f', function()
    if not supports_method(bufnr, 'textDocument/formatting') then
      notify(vim.log.levels.WARN, 'No active LSP client supports formatting')
      return
    end

    lsp.buf.format({
      async = true,
      bufnr = bufnr,
    })
  end, 'Format buffer')

  map('n', '[d', function()
    diagnostic.jump({ count = -1 })
  end, 'Previous diagnostic')

  map('n', ']d', function()
    diagnostic.jump({ count = 1 })
  end, 'Next diagnostic')

  map('n', '<leader>fD', function()
    diagnostic.open_float(nil, { scope = 'line' })
  end, 'Show line diagnostics')

  map('n', '<leader>li', '<cmd>LspInfo<cr>', 'Show LSP info')

  map('i', '<C-Space>', function()
    if lsp.completion and lsp.completion.get then
      lsp.completion.get()
      return ''
    end

    return api.nvim_replace_termcodes('<C-x><C-o>', true, false, true)
  end, 'Trigger LSP completion')

  map('i', '<Tab>', function()
    if lsp.inline_completion and lsp.inline_completion.get then
      if lsp.inline_completion.get() then
        return ''
      end
    end

    return '<Tab>'
  end, 'Accept inline completion')

  if vim.bo[bufnr].filetype == 'rust' then
    map('n', '<leader>re', function()
      vim.ui.select(vim.tbl_keys(M.rust_editions), {
        prompt = 'Select Rust edition',
      }, M.rust_edition)
    end, 'Rust: select edition')

    map('n', '<leader>rt', function()
      vim.ui.select(vim.tbl_keys(M.rust_toolchains), {
        prompt = 'Select Rust toolchain',
      }, M.rust_set_toolchain)
    end, 'Rust: select toolchain')
  end
end

---@param args LspAttachArgs
function M.on_attach(args)
  if not api.nvim_buf_is_valid(args.buf) then
    return
  end

  setup_buffer_maps(args.buf)

  local client = lsp.get_client_by_id(args.data.client_id)

  if client ~= nil and client:supports_method('textDocument/signatureHelp') then
    vim.keymap.set('i', '<C-k>', lsp.buf.signature_help, {
      buffer = args.buf,
      silent = true,
      desc = 'Show signature help',
    })
  end

  if client ~= nil and client:supports_method('textDocument/codeLens') then
    lsp.codelens.enable(true, { bufnr = args.buf })

    vim.keymap.set('n', '<leader>cl', lsp.codelens.run, {
      buffer = args.buf,
      silent = true,
      desc = 'Run code lens',
    })
  end
end

function M.setup_lspmap()
  setup_commands()
end

M.setup = M.setup_lspmap

return M
