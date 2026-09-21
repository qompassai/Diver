-- /qompassai/Diver/lua/config/nav/nt.lua
-- Native, read-only file tree; global mappings belong to mappings.navmap.
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local fs = vim.fs
local uv = vim.uv
local M = {}
local DEPTH_MAX = 32
local ENTRY_COUNT_MAX = 8192
local PATH_SIZE_BYTES_MAX = 4096
local READ_BATCH_MAX = 128
local ROW_COUNT_MAX = 4096

---@class NativeExplorerOptions
---@field position? 'left'|'right'
---@field show_hidden? boolean
---@field width? integer

---@class NativeExplorerConfig
---@field position 'left'|'right'
---@field show_hidden boolean
---@field width integer

---@class NativeExplorerEntry
---@field depth integer
---@field kind string
---@field name string
---@field path string

---@class NativeExplorerBudget
---@field visited integer

---@class NativeExplorerFrame
---@field entries NativeExplorerEntry[]
---@field index integer

---@class NativeExplorerSession
---@field buffer integer
---@field window integer
---@field target integer
---@field root string
---@field rows NativeExplorerEntry[]
---@field expanded table<string, boolean>
---@field revision integer
---@field hidden boolean

---@type NativeExplorerConfig
local config = {
  position = 'left',
  show_hidden = false,
  width = 40,
}
---@type NativeExplorerSession?
local active

---@param message string
local function report(message)
  vim.notify(message, vim.log.levels.WARN, { title = 'Native Explorer' })
end

---@param path string
---@return boolean
local function valid_path(path)
  return type(path) == 'string' and path ~= '' and #path <= PATH_SIZE_BYTES_MAX and not path:find('\0', 1, true)
end

---@param text string
---@return string
local function label(text)
  -- Escape display controls without ever changing the underlying path.
  local escaped = text:gsub('[%z\1-\31\127]', function(byte)
    return ('\\x%02X'):format(byte:byte())
  end)
  return escaped
end

---@param path string
---@return string?, string?
local function directory(path)
  if not valid_path(path) then
    return nil, 'Expected a nonempty path of at most 4096 bytes, without NUL.'
  end
  local real, real_error = uv.fs_realpath(path)
  if real == nil then
    return nil, 'Resolve directory: ' .. tostring(real_error)
  end
  local stat, stat_error = uv.fs_stat(real)
  if stat == nil or stat.type ~= 'directory' then
    return nil, 'Not an accessible directory: ' .. label(real) .. ' ' .. tostring(stat_error or '')
  end
  if not valid_path(real) then
    return nil, 'Resolved directory exceeds the path limit.'
  end
  return real
end

---@param session NativeExplorerSession
---@return boolean
local function live(session)
  return active == session
    and api.nvim_buf_is_valid(session.buffer)
    and api.nvim_win_is_valid(session.window)
    and api.nvim_win_get_buf(session.window) == session.buffer
end

---@param path string
---@param depth integer
---@param hidden boolean
---@param budget NativeExplorerBudget
---@return NativeExplorerEntry[]?, string?
local function read_directory(path, depth, hidden, budget)
  assert(depth >= 0 and depth <= DEPTH_MAX)
  local handle, open_error = uv.fs_opendir(path, nil, READ_BATCH_MAX)
  if handle == nil then
    return nil, 'Read ' .. label(path) .. ': ' .. tostring(open_error)
  end
  local entries = {}
  local failure
  for _ = 1, ENTRY_COUNT_MAX + 1 do
    local batch, read_error = uv.fs_readdir(handle)
    if batch == nil then
      failure = read_error
      break
    end
    if #batch == 0 then
      break
    end
    for index = 1, #batch do
      local item = batch[index]
      budget.visited = budget.visited + 1
      local child = fs.joinpath(path, item.name)
      if budget.visited > ENTRY_COUNT_MAX or not valid_path(child) then
        failure = 'Tree exceeds the 8192-entry or 4096-byte path limit.'
        break
      end
      if hidden or item.name:sub(1, 1) ~= '.' then
        entries[#entries + 1] = {
          depth = depth,
          kind = item.type,
          name = item.name,
          path = child,
        }
      end
    end
    if failure ~= nil then
      break
    end
  end
  local closed, close_error = uv.fs_closedir(handle)
  if not closed then
    failure = tostring(failure or '') .. ' Close directory: ' .. tostring(close_error)
  end
  if failure ~= nil then
    return nil, 'Read ' .. label(path) .. ': ' .. failure
  end
  table.sort(entries, function(left, right)
    if (left.kind == 'directory') ~= (right.kind == 'directory') then
      return left.kind == 'directory'
    end
    return left.name < right.name
  end)
  return entries
end

---@param root string
---@param expanded table<string, boolean>
---@param hidden boolean
---@return NativeExplorerEntry[]?, string?
local function snapshot(root, expanded, hidden)
  local budget = { visited = 0 }
  local entries, read_error = read_directory(root, 0, hidden, budget)
  if entries == nil then
    return nil, read_error
  end
  local rows = {}
  ---@type NativeExplorerFrame[]
  local stack = { { entries = entries, index = 1 } }
  -- Each visited row pushes at most one frame. Depth and total work are bounded.
  for _ = 1, ENTRY_COUNT_MAX * 2 + 2 do
    local frame = stack[#stack]
    if frame == nil then
      return rows
    end
    local entry = frame.entries[frame.index]
    if entry == nil then
      stack[#stack] = nil
    else
      if #rows >= ROW_COUNT_MAX then
        return nil, 'Tree exceeds 4096 displayed rows; browse a smaller root.'
      end
      rows[#rows + 1] = entry
      frame.index = frame.index + 1
      if entry.kind == 'directory' and expanded[entry.path] then
        if entry.depth >= DEPTH_MAX then
          return nil, 'Tree exceeds 32 nesting levels; enter the directory as root.'
        end
        local children, child_error = read_directory(entry.path, entry.depth + 1, hidden, budget)
        if children == nil then
          return nil, child_error
        end
        stack[#stack + 1] = { entries = children, index = 1 }
      end
    end
  end
  return nil, 'Tree traversal budget exhausted.'
end

---@param session NativeExplorerSession
---@return NativeExplorerEntry?
local function selected(session)
  if not live(session) then
    return nil
  end
  -- The first two lines are a root header and help, never filesystem entries.
  local index = api.nvim_win_get_cursor(session.window)[1] - 2
  return session.rows[index]
end

---@param session NativeExplorerSession
---@param rows NativeExplorerEntry[]
---@param preferred? string
local function render(session, rows, preferred)
  assert(live(session))
  assert(#rows <= ROW_COUNT_MAX)
  local current = selected(session)
  local keep = preferred or (current and current.path)
  local cursor = math.min(api.nvim_win_get_cursor(session.window)[1], #rows + 2)
  local lines = { label(session.root), 'Enter: open  -: parent  f: filter  ?: help' }
  local retained = {}
  for index = 1, #rows do
    local entry = rows[index]
    local marker = '    '
    if entry.kind == 'directory' then
      marker = session.expanded[entry.path] and '[-] ' or '[+] '
      if session.expanded[entry.path] then
        retained[entry.path] = true
      end
    elseif entry.kind == 'link' then
      marker = '[@] '
    elseif entry.kind ~= 'file' then
      marker = '[?] '
    end
    lines[index + 2] = string.rep('  ', entry.depth) .. marker .. label(entry.name)
    if entry.path == keep then
      cursor = index + 2
    end
  end
  api.nvim_set_option_value('modifiable', true, { buf = session.buffer })
  api.nvim_buf_set_lines(session.buffer, 0, -1, false, lines)
  api.nvim_set_option_value('modifiable', false, { buf = session.buffer })
  session.rows = rows
  session.expanded = retained -- Collapsed descendants cannot accumulate hidden state.
  session.revision = session.revision + 1
  api.nvim_win_set_cursor(session.window, { math.max(1, cursor), 0 })
end

---@return boolean?, string?
function M.refresh()
  local session = active
  if session == nil or not live(session) then
    return nil, 'Explorer is not open.'
  end
  local rows, err = snapshot(session.root, session.expanded, session.hidden)
  if rows == nil then
    report(tostring(err) .. ' Previous snapshot retained; press R to retry.')
    return nil, err
  end
  render(session, rows)
  return true
end

---@return boolean?, string?
function M.close()
  local session = active
  if session == nil then
    return true
  end
  if live(session) then
    local tab = api.nvim_win_get_tabpage(session.window)
    if #api.nvim_tabpage_list_wins(tab) == 1 then
      api.nvim_win_set_buf(session.window, api.nvim_create_buf(true, false))
    else
      local ok, err = pcall(api.nvim_win_close, session.window, true)
      if not ok then
        report('Close explorer: ' .. tostring(err))
        return nil, tostring(err)
      end
    end
  end
  if active == session then
    active = nil
  end
  if api.nvim_buf_is_valid(session.buffer) then
    local ok, err = pcall(api.nvim_buf_delete, session.buffer, {
      force = true,
    })
    if not ok then
      report('Delete explorer buffer: ' .. tostring(err))
      return nil, tostring(err)
    end
  end
  return true
end

---@param session NativeExplorerSession
---@return boolean
local function focus_target(session)
  if
    not api.nvim_win_is_valid(session.target)
    or api.nvim_win_get_buf(session.target) == session.buffer
    or vim.bo[api.nvim_win_get_buf(session.target)].buftype ~= ''
  then
    report('Original editing window is unavailable; close and reopen the explorer.')
    return false
  end
  api.nvim_set_current_win(session.target)
  return true
end

---@param session NativeExplorerSession
---@param path string
---@param how? 'edit'|'split'|'vsplit'|'tabedit'
local function open_path(session, path, how)
  if not live(session) or not valid_path(path) then
    return
  end
  local stat, err = uv.fs_stat(path)
  if stat == nil then
    report('Open file: ' .. tostring(err))
    return
  end
  if stat.type == 'directory' then
    M.open(path) -- Explicitly entering a symlink directory changes the canonical root.
    return
  end
  if stat.type ~= 'file' then
    report('Refusing to open a socket, device, FIFO, or other non-regular file.')
    return
  end
  if not focus_target(session) then
    return
  end
  local ok, command_error = pcall(api.nvim_cmd, {
    cmd = how or 'edit',
    args = { path },
    magic = { file = false, bar = false },
  }, {})
  if not ok then
    report('Open file: ' .. tostring(command_error))
    return
  end
  session.target = api.nvim_get_current_win()
end

---@param how? 'edit'|'split'|'vsplit'|'tabedit'
function M.activate(how)
  assert(how == nil or how == 'edit' or how == 'split' or how == 'vsplit' or how == 'tabedit', 'Unsupported open mode')
  local session = active
  if session == nil then
    return
  end
  local entry = selected(session)
  if entry == nil then
    return
  end
  if entry.kind ~= 'directory' then
    open_path(session, entry.path, how)
    return
  end
  local previous = session.expanded[entry.path]
  session.expanded[entry.path] = not previous
  if not M.refresh() then
    session.expanded[entry.path] = previous
  end
end

function M.parent()
  local session = active
  if session ~= nil and live(session) then
    local parent = fs.dirname(session.root)
    if parent ~= nil and parent ~= session.root then
      local previous = session.root
      if M.open(parent) then
        render(session, session.rows, previous)
      end
    end
  end
end

function M.enter()
  local session = active
  if session == nil then
    return
  end
  local entry = selected(session)
  if entry ~= nil then
    open_path(session, entry.path)
  end
end

function M.toggle_hidden()
  local session = active
  if session ~= nil and live(session) then
    session.hidden = not session.hidden
    if not M.refresh() then
      session.hidden = not session.hidden
    end
  end
end

function M.pick()
  local session = active
  if session == nil or not live(session) then
    return
  end
  local ok, picker = pcall(require, 'config.nav.fzf')
  if not ok then
    report('Load config.nav.fzf: ' .. tostring(picker))
    return
  end
  local items = {}
  for index = 1, #session.rows do
    local entry = session.rows[index]
    local suffix = entry.kind == 'directory' and '/' or ''
    items[index] = { label = label(entry.path) .. suffix, value = entry.path }
  end
  local revision = session.revision
  api.nvim_set_current_win(session.window)
  local called, err = pcall(picker.fzf_pick, items, function(path)
    if not live(session) or session.revision ~= revision then
      report('Explorer changed while picking; selection discarded.')
      return
    end
    open_path(session, path)
  end, { prompt = 'Explorer> ' })
  if not called then
    report('Explorer picker: ' .. tostring(err))
  end
end

---@param action 'document_symbols'|'files'|'git_status'|'live_grep'|'workspace_symbols'
function M.picker(action)
  assert(
    action == 'document_symbols'
      or action == 'files'
      or action == 'git_status'
      or action == 'live_grep'
      or action == 'workspace_symbols',
    'Unsupported picker'
  )
  local session = active
  if session == nil or not live(session) then
    return
  end
  local ok, picker = pcall(require, 'config.nav.fzf')
  if not ok then
    report('Load config.nav.fzf: ' .. tostring(picker))
    return
  end
  if not focus_target(session) then
    return
  end
  -- Existing project-root and LSP semantics belong to fzf.lua, not the tree root.
  local called, err = pcall(picker[action])
  if not called then
    report('FZF ' .. action .. ': ' .. tostring(err))
  end
end

local function help()
  vim.notify(
    table.concat({
      '<CR>/<Space>/l: expand directory or open file',
      '-/h: parent root   L: enter selected directory as root',
      's/v/t: open in split/vertical split/tab   q: close',
      'H: hidden files   R: refresh   f: fuzzy-filter displayed tree entries',
      'F: project files   g: project grep   G: project Git status',
      'S: source document symbols   W: source workspace symbols',
      'Browsing only: no create, delete, rename, cwd changes, or netrw takeover.',
    }, '\n'),
    vim.log.levels.INFO,
    { title = 'Native Explorer' }
  )
end

---@param buffer integer
local function setup_keymaps(buffer)
  local function bind(key, callback, description)
    vim.keymap.set('n', key, callback, {
      buffer = buffer,
      desc = description,
      nowait = true,
      silent = true,
    })
  end
  bind('<CR>', M.activate, 'Open or expand')
  bind('<Space>', M.activate, 'Open or expand')
  bind('-', M.parent, 'Parent directory')
  bind('?', help, 'Explorer help')
  bind('F', function()
    M.picker('files')
  end, 'Project files')
  bind('G', function()
    M.picker('git_status')
  end, 'Project Git status')
  bind('H', M.toggle_hidden, 'Toggle hidden files')
  bind('L', M.enter, 'Enter directory or file')
  bind('R', M.refresh, 'Refresh tree')
  bind('S', function()
    M.picker('document_symbols')
  end, 'Document symbols')
  bind('W', function()
    M.picker('workspace_symbols')
  end, 'Workspace symbols')
  bind('f', M.pick, 'Filter displayed entries')
  bind('g', function()
    M.picker('live_grep')
  end, 'Project grep')
  bind('h', M.parent, 'Parent directory')
  bind('l', M.activate, 'Open or expand')
  bind('q', M.close, 'Close explorer')
  bind('s', function()
    M.activate('split')
  end, 'Open split')
  bind('t', function()
    M.activate('tabedit')
  end, 'Open tab')
  bind('v', function()
    M.activate('vsplit')
  end, 'Open vertical split')
end

---@param root string
---@return NativeExplorerSession
local function create_session(root)
  local target = api.nvim_get_current_win()
  local buffer = api.nvim_create_buf(false, true)
  local session = {
    buffer = buffer,
    window = -1,
    target = target,
    root = root,
    rows = {},
    expanded = {},
    revision = 0,
    hidden = config.show_hidden,
  }
  active = session
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = buffer })
  api.nvim_set_option_value('buftype', 'nofile', { buf = buffer })
  api.nvim_set_option_value('swapfile', false, { buf = buffer })
  api.nvim_set_option_value('undolevels', -1, { buf = buffer })
  api.nvim_set_option_value('filetype', 'native-explorer', { buf = buffer })
  api.nvim_buf_set_name(buffer, 'native-explorer://' .. buffer)
  session.window = api.nvim_open_win(buffer, true, {
    split = config.position,
    win = -1,
    width = config.width,
  })
  local window = session.window
  api.nvim_set_option_value('cursorline', true, { win = window })
  api.nvim_set_option_value('foldenable', false, { win = window })
  api.nvim_set_option_value('list', false, { win = window })
  api.nvim_set_option_value('number', false, { win = window })
  api.nvim_set_option_value('relativenumber', false, { win = window })
  api.nvim_set_option_value('signcolumn', 'no', { win = window })
  api.nvim_set_option_value('spell', false, { win = window })
  api.nvim_set_option_value('winfixwidth', true, { win = window })
  api.nvim_set_option_value('wrap', false, { win = window })
  setup_keymaps(buffer)
  api.nvim_create_autocmd('BufWipeout', {
    buffer = buffer,
    once = true,
    callback = function()
      if active == session then
        active = nil
      end
    end,
  })
  return session
end

---@param path? string Existing directory, literal path; nil uses cwd for a new session.
---@return boolean?, string?
function M.open(path)
  local session = active
  if session ~= nil and live(session) and path == nil then
    api.nvim_set_current_win(session.window)
    return true
  end
  local root, err = directory(path or vim.fn.getcwd())
  if root == nil then
    report(tostring(err))
    return nil, err
  end
  local hidden = config.show_hidden
  if session ~= nil and live(session) then
    hidden = session.hidden
  end
  local rows, read_error = snapshot(root, {}, hidden)
  if rows == nil then
    report(tostring(read_error))
    return nil, read_error
  end
  if session == nil or not live(session) then
    if not M.close() then
      return nil, 'Unable to clean up previous explorer.'
    end
    local ok, result = pcall(create_session, root)
    if not ok then
      M.close()
      report('Open explorer: ' .. tostring(result))
      return nil, tostring(result)
    end
    session = result
  end
  session.root = root
  session.expanded = {}
  api.nvim_set_current_win(session.window)
  render(session, rows)
  if #rows > 0 then
    api.nvim_win_set_cursor(session.window, {
      3,
      0,
    })
  end
  return true
end

function M.toggle()
  if active ~= nil and live(active) then
    return M.close()
  end
  return M.open()
end

function M.reveal()
  local session = active
  local buffer = api.nvim_get_current_buf()
  if session ~= nil and live(session) and buffer == session.buffer then
    if not focus_target(session) then
      return
    end
    buffer = api.nvim_get_current_buf()
  end
  local path = api.nvim_buf_get_name(buffer)
  if not valid_path(path) or vim.bo[buffer].buftype ~= '' then
    report('Current buffer has no filesystem path.')
    return
  end
  local parent = fs.dirname(path)
  if parent ~= nil and M.open(parent) then
    local opened = active
    if opened ~= nil and live(opened) then
      if fs.basename(path):sub(1, 1) == '.' and not opened.hidden then
        M.toggle_hidden()
      end
      render(opened, opened.rows, fs.joinpath(opened.root, fs.basename(path)))
    end
  end
end

function M.create_commands()
  api.nvim_create_user_command('Explorer', function()
    M.toggle()
  end, { force = true })
  api.nvim_create_user_command('ExplorerClose', function()
    M.close()
  end, { force = true })
  api.nvim_create_user_command('ExplorerOpen', function(args)
    M.open(args.args ~= '' and args.args or nil)
  end, { complete = 'dir', force = true, nargs = '?' })
  api.nvim_create_user_command('ExplorerPick', M.pick, {
    force = true,
  })
  api.nvim_create_user_command('ExplorerRefresh', function()
    M.refresh()
  end, { force = true })
  api.nvim_create_user_command('ExplorerReveal', M.reveal, { force = true })
end

---@param options? NativeExplorerOptions
---@return boolean?, string?
function M.setup(options)
  if options == nil then
    options = {}
  end
  if type(options) ~= 'table' then
    return nil, 'Explorer options must be a table.'
  end
  for key in pairs(options) do
    if key ~= 'position' and key ~= 'show_hidden' and key ~= 'width' then
      return nil, 'Unknown explorer option: ' .. tostring(key)
    end
  end
  local candidate = {
    position = 'left',
    show_hidden = false,
    width = 40,
  }
  if options.show_hidden ~= nil then
    candidate.show_hidden = options.show_hidden
  end
  if options.position ~= nil then
    candidate.position = options.position
  end
  if options.width ~= nil then
    candidate.width = options.width
  end
  if
    candidate.position ~= 'left' and candidate.position ~= 'right'
    or type(candidate.show_hidden) ~= 'boolean'
    or type(candidate.width) ~= 'number'
    or candidate.width % 1 ~= 0
    or candidate.width < 20
    or candidate.width > 120
  then
    return nil, 'Expected position left/right, boolean show_hidden, and integer width 20..120.'
  end
  if not M.close() then
    return nil, 'Unable to close explorer during setup.'
  end
  config = candidate
  M.create_commands()
  return true
end

return M
