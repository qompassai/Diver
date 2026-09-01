-- -- #################################################################
-- /qompassai/Diver/lua/config/nav/fzf.lua
-- Qompass AI Diver Native Fzf Navigation Configuration
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local lsp = vim.lsp
local uv = vim.uv

local M = {}

local SOURCE = 'native-fzf'

---@type string[]
local ROOT_MARKERS = {
  '.git',
  'Cargo.toml',
  'flake.nix',
  'go.mod',
  'package.json',
  'pyproject.toml',
}

---@class NativeFzfItem
---@field label string
---@field value any

---@class NativeFzfPickOptions
---@field prompt? string

---@class NativeFzfLocation
---@field character integer
---@field line integer
---@field uri string

---@class NativeFzfState
---@field active_job integer?
---@field session integer
local state = {
  active_job = nil,
  session = 0,
}

M.options = {
  binaries = {
    'fzf',
    'sk',
  },
  projects_directory = fn.expand('~/projects'),
  prompt = '❯ ',
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param command string
---@return string?
local function executable_path(command)
  local path = fn.exepath(command)

  if type(path) ~= 'string' or path == '' then
    return nil
  end

  return fs.normalize(path)
end

---@return string?
local function picker_binary()
  local configured = vim.env.NVIM_FZF_BIN

  if type(configured) == 'string' and configured ~= '' then
    local path = executable_path(configured)

    if path ~= nil then
      return path
    end

    notify(('NVIM_FZF_BIN is not executable: %s'):format(configured), levels.WARN)
  end

  for _, command in ipairs(M.options.binaries) do
    local path = executable_path(command)

    if path ~= nil then
      return path
    end
  end

  return nil
end

---@return string
local function project_root()
  local bufnr = api.nvim_get_current_buf()
  local name = api.nvim_buf_get_name(bufnr)
  local start = name ~= '' and name or fn.getcwd()

  local root = fs.root(start, ROOT_MARKERS)

  if type(root) == 'string' and root ~= '' then
    return fs.normalize(root)
  end

  return fs.normalize(fn.getcwd())
end

---@param path string?
local function unlink(path)
  if type(path) == 'string' and path ~= '' then
    pcall(uv.fs_unlink, path)
  end
end

---@return string?
local function temporary_file()
  local path = fn.tempname()
  local descriptor = uv.fs_open(path, 'w', 384)

  if descriptor == nil then
    notify('unable to create a private picker file', levels.ERROR)

    return nil
  end

  uv.fs_close(descriptor)

  return path
end

---@param value any
---@return NativeFzfItem
local function picker_item(value)
  if type(value) == 'table' and type(value.label) == 'string' then
    return {
      label = value.label,
      value = value.value,
    }
  end

  return {
    label = tostring(value),
    value = value,
  }
end

---@param value string
---@return string
local function single_line(value)
  return value:gsub('[\r\n\t]', ' ')
end

---@param items any[]
---@return NativeFzfItem[], string[]
local function prepare_items(items)
  ---@type NativeFzfItem[]
  local normalized = {}

  ---@type string[]
  local lines = {}

  for index, value in ipairs(items) do
    local item = picker_item(value)

    normalized[index] = item
    lines[index] = ('%08d\t%s'):format(index, single_line(item.label))
  end

  return normalized, lines
end

---@param path string
---@return string?
local function selected_line(path)
  local ok, lines = pcall(fn.readfile, path, '', 1)

  if not ok or type(lines) ~= 'table' or type(lines[1]) ~= 'string' or lines[1] == '' then
    return nil
  end

  return lines[1]
end

---@param bufnr integer
local function delete_terminal_buffer(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    pcall(api.nvim_buf_delete, bufnr, {
      force = true,
    })
  end
end

---@param items any[]
---@param sink fun(value: any, item: NativeFzfItem)
---@param options? NativeFzfPickOptions
local function fzf_pick(items, sink, options)
  if #items == 0 then
    notify('no entries', levels.INFO)

    return
  end

  local picker = picker_binary()

  if picker == nil then
    notify('install `fzf` or `skim`, or set NVIM_FZF_BIN', levels.ERROR)

    return
  end

  local shell = executable_path('sh')

  if shell == nil then
    notify('a POSIX `sh` executable is required', levels.ERROR)

    return
  end

  local input_path = temporary_file()
  local output_path = temporary_file()

  if input_path == nil or output_path == nil then
    unlink(input_path)
    unlink(output_path)

    return
  end

  local normalized, lines = prepare_items(items)

  local wrote, write_error = pcall(fn.writefile, lines, input_path, 'b')

  if not wrote then
    unlink(input_path)
    unlink(output_path)
    notify(('unable to prepare picker input: %s'):format(tostring(write_error)), levels.ERROR)

    return
  end

  options = options or {}

  local prompt = type(options.prompt) == 'string' and options.prompt or M.options.prompt

  state.session = state.session + 1

  local session = state.session

  vim.cmd('botright new')

  local terminal_buffer = api.nvim_get_current_buf()

  vim.bo[terminal_buffer].bufhidden = 'wipe'

  local script = table.concat({
    'exec "$1"',
    '--ansi',
    '--layout=reverse',
    '--border=rounded',
    '--cycle',
    '--delimiter "$2"',
    '--with-nth "2.."',
    '--prompt "$3"',
    '< "$4"',
    '> "$5"',
  }, ' ')

  local job_id

  job_id = fn.jobstart({
    shell,
    '-c',
    script,
    'qompass-native-fzf',
    picker,
    '\t',
    prompt,
    input_path,
    output_path,
  }, {
    term = true,

    on_exit = function(_, code)
      vim.schedule(function()
        local selection = selected_line(output_path)

        unlink(input_path)
        unlink(output_path)
        delete_terminal_buffer(terminal_buffer)

        if state.active_job == job_id and state.session == session then
          state.active_job = nil
        end

        if code ~= 0 or selection == nil then
          return
        end

        local raw_index = selection:match('^(%d+)\t')

        local index = tonumber(raw_index)

        if index == nil then
          notify('picker returned an invalid selection', levels.ERROR)

          return
        end

        local item = normalized[math.floor(index)]

        if item == nil then
          notify('picker selection was out of range', levels.ERROR)

          return
        end

        local ok, sink_error = pcall(sink, item.value, item)

        if not ok then
          notify(('selection handler failed: %s'):format(tostring(sink_error)), levels.ERROR)
        end
      end)
    end,
  })

  if job_id <= 0 then
    unlink(input_path)
    unlink(output_path)
    delete_terminal_buffer(terminal_buffer)
    notify('failed to start the native picker', levels.ERROR)

    return
  end

  state.active_job = job_id
  vim.cmd('startinsert')
end

M.fzf_pick = fzf_pick

function M.cancel()
  local job_id = state.active_job

  if job_id ~= nil then
    fn.jobstop(job_id)
    state.active_job = nil
  end
end

---@param command string[]
---@param cwd? string
---@return vim.SystemCompleted?
local function run(command, cwd)
  local ok, result = pcall(function()
    return vim
      .system(command, {
        cwd = cwd,
        text = true,
      })
      :wait()
  end)

  if not ok then
    notify(('command failed: %s'):format(tostring(result)), levels.ERROR)

    return nil
  end

  return result
end

---@param output string?
---@return string[]
local function output_lines(output)
  if type(output) ~= 'string' or output == '' then
    return {}
  end

  return vim.split(output, '\n', {
    plain = true,
    trimempty = true,
  })
end

---@param value number|string|nil
---@param minimum integer
---@return integer
local function integer_at_least(value, minimum)
  local parsed = tonumber(value)

  if parsed == nil then
    return minimum
  end

  local result = math.floor(parsed)

  if result < minimum then
    return minimum
  end

  return result
end

---@param path string
local function edit(path)
  vim.cmd('edit ' .. fn.fnameescape(path))
end

---@param location NativeFzfLocation
local function open_location(location)
  local bufnr = vim.uri_to_bufnr(location.uri)

  fn.bufload(bufnr)
  api.nvim_set_current_buf(bufnr)
  api.nvim_win_set_cursor(0, {
    integer_at_least(location.line, 0) + 1,
    integer_at_least(location.character, 0),
  })
end

---@param root string
---@return NativeFzfItem[]
local function project_file_items(root)
  local command

  if executable_path('fd') ~= nil then
    command = {
      'fd',
      '--type',
      'f',
      '--type',
      'l',
      '--hidden',
      '--exclude',
      '.git',
      '.',
    }
  elseif executable_path('rg') ~= nil then
    command = {
      'rg',
      '--files',
      '--hidden',
      '--glob',
      '!.git',
    }
  else
    command = {
      'find',
      '.',
      '-type',
      'f',
    }
  end

  local result = run(command, root)

  if result == nil or result.code ~= 0 then
    return {}
  end

  ---@type NativeFzfItem[]
  local items = {}

  for _, relative in ipairs(output_lines(result.stdout)) do
    relative = relative:gsub('^%./', '')

    items[#items + 1] = {
      label = relative,
      value = fs.joinpath(root, relative),
    }
  end

  return items
end

function M.files()
  local root = project_root()

  fzf_pick(project_file_items(root), function(path)
    if type(path) == 'string' then
      edit(path)
    end
  end, {
    prompt = 'Files❯ ',
  })
end

function M.buffers()
  ---@type NativeFzfItem[]
  local items = {}

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(bufnr) and fn.buflisted(bufnr) == 1 then
      local name = api.nvim_buf_get_name(bufnr)

      if name == '' then
        name = '[No Name]'
      end

      items[#items + 1] = {
        label = ('%d  %s'):format(bufnr, name),
        value = bufnr,
      }
    end
  end

  fzf_pick(items, function(bufnr)
    local buffer = integer_at_least(bufnr, 0)

    if api.nvim_buf_is_valid(buffer) then
      api.nvim_set_current_buf(buffer)
    end
  end, {
    prompt = 'Buffers❯ ',
  })
end

---@param kind integer?
---@return string
local function symbol_kind(kind)
  if type(kind) ~= 'number' then
    return 'Symbol'
  end

  local value = lsp.protocol.SymbolKind[kind]

  return type(value) == 'string' and value or 'Symbol'
end

---@param symbol table
---@param default_uri string
---@return NativeFzfLocation?
local function symbol_location(symbol, default_uri)
  local uri = default_uri
  local range

  if type(symbol.location) == 'table' then
    if type(symbol.location.uri) == 'string' then
      uri = symbol.location.uri
    end

    range = symbol.location.range
  else
    range = symbol.selectionRange or symbol.range
  end

  if type(range) ~= 'table' or type(range.start) ~= 'table' or type(range.start.line) ~= 'number' then
    return nil
  end

  return {
    uri = uri,
    line = math.floor(range.start.line),
    character = type(range.start.character) == 'number' and math.floor(range.start.character) or 0,
  }
end

---@param symbols table[]
---@param default_uri string
---@param items NativeFzfItem[]
---@param depth? integer
local function collect_symbols(symbols, default_uri, items, depth)
  depth = depth or 0

  for _, symbol in ipairs(symbols) do
    if type(symbol) == 'table' then
      local location = symbol_location(symbol, default_uri)

      if location ~= nil then
        local name = type(symbol.name) == 'string' and symbol.name or '<unnamed>'

        items[#items + 1] = {
          label = ('%s%s  [%s]  line %d'):format(
            string.rep('  ', depth),
            name,
            symbol_kind(symbol.kind),
            location.line + 1
          ),
          value = location,
        }
      end

      if type(symbol.children) == 'table' then
        collect_symbols(symbol.children, default_uri, items, depth + 1)
      end
    end
  end
end

---@param responses table
---@param default_uri string
---@return NativeFzfItem[]
local function response_symbol_items(responses, default_uri)
  ---@type NativeFzfItem[]
  local items = {}

  for _, response in pairs(responses) do
    if type(response) == 'table' and type(response.result) == 'table' then
      collect_symbols(response.result, default_uri, items)
    end
  end

  return items
end

function M.document_symbols()
  local bufnr = api.nvim_get_current_buf()
  local uri = vim.uri_from_bufnr(bufnr)

  lsp.buf_request_all(bufnr, 'textDocument/documentSymbol', {
    textDocument = {
      uri = uri,
    },
  }, function(responses)
    fzf_pick(response_symbol_items(responses, uri), function(location)
      if type(location) == 'table' then
        open_location(location)
      end
    end, {
      prompt = 'Document symbols❯ ',
    })
  end)
end

function M.workspace_symbols()
  local query = fn.input('Workspace symbol query: ')

  if query == '' then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local uri = vim.uri_from_bufnr(bufnr)

  lsp.buf_request_all(bufnr, 'workspace/symbol', {
    query = query,
  }, function(responses)
    fzf_pick(response_symbol_items(responses, uri), function(location)
      if type(location) == 'table' then
        open_location(location)
      end
    end, {
      prompt = 'Workspace symbols❯ ',
    })
  end)
end

function M.commands()
  ---@type NativeFzfItem[]
  local items = {}

  for name in
    pairs(api.nvim_get_commands({
      builtin = true,
    }))
  do
    items[#items + 1] = {
      label = name,
      value = name,
    }
  end

  table.sort(items, function(left, right)
    return left.label < right.label
  end)

  fzf_pick(items, function(command)
    if type(command) == 'string' then
      api.nvim_feedkeys(':' .. command .. ' ', 'n', false)
    end
  end, {
    prompt = 'Commands❯ ',
  })
end

function M.help_tags()
  fzf_pick(fn.getcompletion('', 'help'), function(tag)
    if type(tag) == 'string' then
      vim.cmd('help ' .. fn.fnameescape(tag))
    end
  end, {
    prompt = 'Help❯ ',
  })
end

function M.colorschemes()
  fzf_pick(fn.getcompletion('', 'color'), function(name)
    if type(name) == 'string' then
      vim.cmd('colorscheme ' .. fn.fnameescape(name))
    end
  end, {
    prompt = 'Colorschemes❯ ',
  })
end

---@param entries table[]
---@param items NativeFzfItem[]
local function collect_marks(entries, items)
  for _, entry in ipairs(entries) do
    if
      type(entry) == 'table'
      and type(entry.mark) == 'string'
      and type(entry.pos) == 'table'
      and type(entry.pos[2]) == 'number'
    then
      local bufnr = integer_at_least(entry.pos[1], 0)

      local line = integer_at_least(entry.pos[2], 1)

      local column = integer_at_least(entry.pos[3], 1)

      local name = bufnr > 0 and api.nvim_buf_get_name(bufnr) or api.nvim_buf_get_name(0)

      items[#items + 1] = {
        label = ('%s  %s:%d'):format(entry.mark, name ~= '' and name or '[No Name]', line),
        value = {
          bufnr = bufnr,
          column = column,
          line = line,
        },
      }
    end
  end
end

function M.marks()
  ---@type NativeFzfItem[]
  local items = {}

  collect_marks(fn.getmarklist(), items)
  collect_marks(fn.getmarklist(0), items)

  fzf_pick(items, function(mark)
    if type(mark) ~= 'table' then
      return
    end

    local bufnr = integer_at_least(mark.bufnr, 0)

    if bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
      api.nvim_set_current_buf(bufnr)
    end

    local line = integer_at_least(mark.line, 1)

    local column = integer_at_least(mark.column, 1) - 1

    api.nvim_win_set_cursor(0, {
      line,
      column,
    })
  end, {
    prompt = 'Marks❯ ',
  })
end

---@param query? string
function M.live_grep(query)
  query = query or fn.input('Grep pattern: ')

  if query == '' then
    return
  end

  local rg = executable_path('rg')

  if rg == nil then
    notify('`ripgrep` is required for live grep', levels.ERROR)

    return
  end

  local root = project_root()
  local result = run({
    rg,
    '--vimgrep',
    '--smart-case',
    '--hidden',
    '--glob',
    '!.git',
    query,
    '.',
  }, root)

  if result == nil or (result.code ~= 0 and result.code ~= 1) then
    return
  end

  ---@type NativeFzfItem[]
  local items = {}

  for _, line in ipairs(output_lines(result.stdout)) do
    local relative, row, column, text = line:match('^(.-):(%d+):(%d+):(.*)$')

    if relative ~= nil and row ~= nil and column ~= nil then
      items[#items + 1] = {
        label = ('%s:%s:%s:%s'):format(relative, row, column, text or ''),
        value = {
          uri = vim.uri_from_fname(fs.joinpath(root, relative)),
          line = integer_at_least(row, 1) - 1,
          character = integer_at_least(column, 1) - 1,
        },
      }
    end
  end

  fzf_pick(items, function(location)
    if type(location) == 'table' then
      open_location(location)
    end
  end, {
    prompt = 'Grep❯ ',
  })
end

function M.grep_cword()
  local word = fn.expand('<cword>')

  if word ~= '' then
    M.live_grep(word)
  end
end

---@return string?
local function git_root()
  local git = executable_path('git')

  if git == nil then
    notify('`git` is not available', levels.ERROR)

    return nil
  end

  local result = run({
    git,
    'rev-parse',
    '--show-toplevel',
  }, project_root())

  if result == nil or result.code ~= 0 then
    notify('current file is not in a Git worktree', levels.WARN)

    return nil
  end

  local root = vim.trim(result.stdout or '')

  return root ~= '' and fs.normalize(root) or nil
end

function M.git_status()
  local root = git_root()

  if root == nil then
    return
  end

  local result = run({
    'git',
    'status',
    '--short',
    '--untracked-files=all',
  }, root)

  if result == nil or result.code ~= 0 then
    return
  end

  ---@type NativeFzfItem[]
  local items = {}

  for _, line in ipairs(output_lines(result.stdout)) do
    local relative = line:sub(4)
    local renamed = relative:match('^.- %-> (.+)$')

    if renamed ~= nil then
      relative = renamed
    end

    items[#items + 1] = {
      label = line,
      value = fs.joinpath(root, relative),
    }
  end

  fzf_pick(items, function(path)
    if type(path) == 'string' then
      edit(path)
    end
  end, {
    prompt = 'Git status❯ ',
  })
end

function M.git_branches()
  local root = git_root()

  if root == nil then
    return
  end

  local result = run({
    'git',
    'branch',
    '--format=%(refname:short)',
  }, root)

  if result == nil or result.code ~= 0 then
    return
  end

  fzf_pick(output_lines(result.stdout), function(branch)
    if type(branch) ~= 'string' then
      return
    end

    local switched = run({
      'git',
      'switch',
      branch,
    }, root)

    if switched ~= nil and switched.code == 0 then
      notify(('switched to %s'):format(branch))
    else
      notify(vim.trim(switched and switched.stderr or 'git switch failed'), levels.ERROR)
    end
  end, {
    prompt = 'Git branches❯ ',
  })
end

function M.projects()
  local directory = M.options.projects_directory

  local stat = uv.fs_stat(directory)

  if stat == nil or stat.type ~= 'directory' then
    notify(('projects directory does not exist: %s'):format(directory), levels.WARN)

    return
  end

  local find = executable_path('find')

  if find == nil then
    notify('`find` is required for project discovery', levels.ERROR)

    return
  end

  local result = run({
    find,
    directory,
    '-mindepth',
    '1',
    '-maxdepth',
    '2',
    '-type',
    'd',
  })

  if result == nil or result.code ~= 0 then
    return
  end

  fzf_pick(output_lines(result.stdout), function(path)
    if type(path) ~= 'string' then
      return
    end

    api.nvim_set_current_dir(path)
    M.files()
  end, {
    prompt = 'Projects❯ ',
  })
end

function M.smart_hlsearch()
  local pattern = fn.getreg('/')
  local enabled = type(pattern) == 'string' and pattern ~= ''

  vim.opt.hlsearch = enabled
end

function M.highlight_word_under_cursor()
  local word = fn.expand('<cword>')

  if word == '' then
    return
  end

  vim.cmd('keepjumps normal! m`')
  fn.setreg('/', '\\V' .. fn.escape(word, '\\'))
  M.smart_hlsearch()
end

function M.next_match()
  vim.cmd('keepjumps normal! n')
  M.smart_hlsearch()
end

function M.prev_match()
  vim.cmd('keepjumps normal! N')
  M.smart_hlsearch()
end

---@param command string
function M.substitute(command)
  local cursor = api.nvim_win_get_cursor(0)

  local old_search = fn.getreg('/')

  vim.cmd('keepjumps ' .. command)
  api.nvim_win_set_cursor(0, cursor)
  fn.setreg('/', old_search)
  M.smart_hlsearch()
end

M.keymaps = {
  {
    '<leader>zb',
    M.buffers,
    desc = 'Fzf Buffers',
  },
  {
    '<leader>zc',
    M.commands,
    desc = 'Fzf Commands',
  },
  {
    '<leader>zd',
    M.document_symbols,
    desc = 'Fzf Document Symbols',
  },
  {
    '<leader>zf',
    M.files,
    desc = 'Fzf Files',
  },
  {
    '<leader>zgb',
    M.git_branches,
    desc = 'Fzf Git Branches',
  },
  {
    '<leader>zgs',
    M.git_status,
    desc = 'Fzf Git Status',
  },
  {
    '<leader>zh',
    M.help_tags,
    desc = 'Fzf Help Tags',
  },
  {
    '<leader>zH',
    M.colorschemes,
    desc = 'Fzf Colorscheme',
  },
  {
    '<leader>zm',
    M.marks,
    desc = 'Fzf Marks',
  },
  {
    '<leader>zs',
    M.live_grep,
    desc = 'Fzf Search',
  },
  {
    '<leader>zWs',
    M.workspace_symbols,
    desc = 'Fzf Workspace Symbols',
  },
  {
    '<leader>zw',
    M.grep_cword,
    desc = 'Fzf Current Word',
  },
}

function M.setup_mappings()
  for _, mapping in ipairs(M.keymaps) do
    vim.keymap.set('n', mapping[1], mapping[2], {
      desc = mapping.desc,
      silent = true,
    })
  end

  vim.keymap.set('n', '*', M.highlight_word_under_cursor, {
    desc = 'Search word under cursor',
    silent = true,
  })

  vim.keymap.set('n', 'n', M.next_match, {
    desc = 'Next search match',
    silent = true,
  })

  vim.keymap.set('n', 'N', M.prev_match, {
    desc = 'Previous search match',
    silent = true,
  })

  vim.keymap.set('n', '<leader>h', function()
    if vim.v.hlsearch == 1 then
      vim.opt.hlsearch = false
    else
      M.smart_hlsearch()
    end
  end, {
    desc = 'Toggle search highlighting',
    silent = true,
  })
end

local function create_commands()
  local commands = {
    NativeFzfBuffers = M.buffers,
    NativeFzfColorschemes = M.colorschemes,
    NativeFzfCommands = M.commands,
    NativeFzfDocumentSymbols = M.document_symbols,
    NativeFzfFiles = M.files,
    NativeFzfGitBranches = M.git_branches,
    NativeFzfGitStatus = M.git_status,
    NativeFzfHelp = M.help_tags,
    NativeFzfMarks = M.marks,
    NativeFzfProjects = M.projects,
    NativeFzfWorkspaceSymbols = M.workspace_symbols,
    Projects = M.projects,
  }

  for name, callback in pairs(commands) do
    api.nvim_create_user_command(name, callback, {
      force = true,
    })
  end

  api.nvim_create_user_command('NativeFzfGrep', function(options)
    M.live_grep(options.args ~= '' and options.args or nil)
  end, {
    force = true,
    nargs = '*',
  })
end

function M.setup()
  vim.opt.incsearch = true
  vim.opt.hlsearch = true

  create_commands()
  M.setup_mappings()
end

M.fzf_setup = M.setup

return M