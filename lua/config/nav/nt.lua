-- /qompassai/Diver/lua/config/nav/nt.lua
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local WINDOWS = vim.fn.has('win32') == 1
local TERMUX = not WINDOWS
  and (vim.env.TERMUX_VERSION ~= nil or (vim.env.PREFIX or ''):find('/com.termux/', 1, true) ~= nil)
local module_source = debug.getinfo(1, 'S').source
local MODULE_PATH = module_source:sub(1, 1) == '@' and fn.fnamemodify(module_source:sub(2), ':p') or ''

---@param path string
---@return boolean
local function absolute(path)
  if WINDOWS then
    return path:match('^%a:[/\\]') ~= nil or path:match('^[/\\][/\\]') ~= nil
  end
  return path:sub(1, 1) == '/'
end

---@param path string
---@return string
local function path_key(path)
  local result = vim.fs.normalize(path)
  if WINDOWS then
    result = result:lower()
  end
  return (result:gsub('/+$', ''))
end

---@return string
local function default_root()
  return WINDOWS and vim.fn.getcwd() or '/'
end

local PS_ACTIONS = {
  chmod = [[
& (Join-Path $env:SystemRoot 'System32/icacls.exe') $d.path '/grant' $d.value
if ($LASTEXITCODE -ne 0) { throw "icacls failed: $LASTEXITCODE" }
]],
  chown = [[
& (Join-Path $env:SystemRoot 'System32/icacls.exe') $d.path '/setowner' $d.value '/L'
if ($LASTEXITCODE -ne 0) { throw "icacls failed: $LASTEXITCODE" }
]],
  cp = [[
$sourcePath = [IO.Path]::GetFullPath($d.path).TrimEnd('\','/')
$targetPath = [IO.Path]::GetFullPath($d.destination)
$comparison = [StringComparison]::OrdinalIgnoreCase
if ($targetPath.Equals($sourcePath, $comparison) -or
    $targetPath.StartsWith($sourcePath + [IO.Path]::DirectorySeparatorChar, $comparison)) {
    throw 'Copy destination must be outside the source'
}
$script:count = 0
function Copy-Exclusive([string]$from, [string]$to, [int]$depth) {
    $script:count++
    if ($depth -gt 64 -or $script:count -gt 10000) { throw 'Copy budget exceeded' }
    if (Test-Path -LiteralPath $to) { throw 'Destination exists' }
    $item = Get-Item -LiteralPath $from -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        if (-not $item.LinkTarget) { throw 'Unsupported reparse point' }
        if ($item.PSIsContainer) {
            [void][IO.Directory]::CreateSymbolicLink($to, $item.LinkTarget)
        } else { [void][IO.File]::CreateSymbolicLink($to, $item.LinkTarget) }
    } elseif ($item.PSIsContainer) {
        # Create a new directory through Win32 CREATE_NEW semantics below.
        if (-not [ExplorerNativeDirectory]::CreateDirectoryW($to, [IntPtr]::Zero)) {
            throw [ComponentModel.Win32Exception]::new()
        }
        foreach ($child in $item.EnumerateFileSystemInfos()) {
            Copy-Exclusive $child.FullName ([IO.Path]::Combine($to, $child.Name)) ($depth + 1)
        }
    } else { [IO.File]::Copy($from, $to, $false) }
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ExplorerNativeDirectory {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectoryW(string path, IntPtr security);
}
'@
Copy-Exclusive $d.path $d.destination 0
]],
  exec = [[
$arguments = @($d.arguments)
& $d.path @arguments
if ($LASTEXITCODE -ne 0) { throw "Command failed: $LASTEXITCODE" }
]],
  ln = [[
$item = Get-Item -LiteralPath $d.path -Force
if ($item.PSIsContainer) {
    [void][IO.Directory]::CreateSymbolicLink($d.destination, $d.path)
} else { [void][IO.File]::CreateSymbolicLink($d.destination, $d.path) }
]],
  mv = [[
$item = Get-Item -LiteralPath $d.path -Force
if ($item.PSIsContainer) { [IO.Directory]::Move($d.path, $d.destination) }
else { [IO.File]::Move($d.path, $d.destination, $false) }
]],
  rm = [[
$root = [IO.Path]::GetPathRoot($d.path)
if ($d.path.TrimEnd('\','/') -eq $root.TrimEnd('\','/')) { throw 'Refusing volume root' }
$item = Get-Item -LiteralPath $d.path -Force
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    if ($item.PSIsContainer) { [IO.Directory]::Delete($d.path, $false) }
    else { [IO.File]::Delete($d.path) }
} elseif ($item.PSIsContainer) {
    if (-not $d.recursive) { [IO.Directory]::Delete($d.path, $false) }
    else { Remove-Item -LiteralPath $d.path -Recurse -Force -Confirm:$false }
} else { [IO.File]::Delete($d.path) }
]],
}

---@param source string ASCII script; Unicode paths are inside base64-encoded JSON.
---@return string
local function encoded_script(source)
  return vim.base64.encode((source:gsub('.', function(char)
    return char .. '\0'
  end)))
end

---@param argv string[]
---@param elevated boolean?
---@return string[]?, string?
local function windows_command(argv, elevated)
  local executable = vim.fn.exepath('pwsh')
  if executable == '' then
    return nil, 'Install PowerShell 7.3+ (pwsh.exe) for file operations.'
  end
  local kind = PS_ACTIONS[argv[1]] and argv[1] or 'exec'
  local data = { path = argv[#argv], destination = '', value = '', recursive = false, arguments = {} } ---@type table<string, any>
  if kind == 'exec' then
    data.path = vim.fn.exepath(argv[1])
    if data.path == '' then
      return nil, 'Executable not found: ' .. argv[1]
    end
    data.arguments = vim.list_slice(argv, 2)
  elseif kind == 'cp' or kind == 'mv' or kind == 'ln' then
    data.path, data.destination = argv[#argv - 1], argv[#argv]
  elseif kind == 'chmod' or kind == 'chown' then
    data.value = argv[#argv - 1]
  elseif kind == 'rm' then
    data.recursive = vim.tbl_contains(argv, '-r')
  end
  local payload = vim.base64.encode(vim.json.encode(data))
  local source = "$ErrorActionPreference='Stop'; try {\n"
    .. "if ($PSVersionTable.PSVersion -lt [version]'7.3') { throw 'PowerShell 7.3+ required' }\n"
    .. "$d = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"
    .. payload
    .. "')) | ConvertFrom-Json\n"
    .. PS_ACTIONS[kind]
    .. '\nexit 0\n} catch { [Console]::Error.WriteLine($_); exit 1 }'
  local encoded = encoded_script(source)
  if #encoded > 24000 then
    return nil, 'Operation exceeds the Windows command-line budget.'
  end
  if elevated then
    local launch = "$ErrorActionPreference='Stop'; try { $p = Start-Process "
      .. "-FilePath (Join-Path $PSHOME 'pwsh.exe') -Verb RunAs -PassThru -Wait "
      .. "-ArgumentList '-NoLogo -NoProfile -EncodedCommand "
      .. encoded
      .. "'; exit $p.ExitCode } catch { [Console]::Error.WriteLine($_); exit 1 }"
    return { executable, '-NoLogo', '-NoProfile', '-Command', launch }
  end
  return { executable, '-NoLogo', '-NoProfile', '-EncodedCommand', encoded }
end

---@param module_name string
---@param items {label: string, value: any}[]
---@param sink fun(value: any)
---@param options {prompt: string}
local function pick_items(module_name, items, sink, options)
  local ok, picker = pcall(require, module_name)
  if ok and type(picker) == 'table' and type(picker.fzf_pick) == 'function' and fn.executable('sh') == 1 then
    picker.fzf_pick(items, sink, options)
    return
  end
  vim.ui.select(items, {
    prompt = options.prompt,
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item then
      sink(item.value)
    end
  end)
end

local operations = {}
do
  local M = operations
  M.fzf_module = 'config.nav.fzf'
  ---@class ExplorerCommandOptions
  ---@field capture? boolean
  ---@field cwd? string
  ---@field elevated? boolean
  ---@field env? table<string, string>
  ---@field keep? boolean

  ---@class ExplorerCommand
  ---@field buffer integer
  ---@field directory? string
  ---@field job integer
  ---@field origin integer
  ---@field window integer

  ---@type ExplorerCommand?
  local active
  local OUTPUT_MAX = 4 * 1024 * 1024
  local ITEMS_MAX = 10000
  local epoch = 0

  ---@param message string
  ---@param level? integer
  local function notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, { title = 'Explorer operations' })
  end

  ---@param path string
  ---@return string
  local function label(path)
    local text = path:gsub('[%c]', function(char)
      return ('\\x%02X'):format(char:byte())
    end)
    return text:sub(1, 1500)
  end

  ---@param directory string?
  local function cleanup(directory)
    if directory then
      uv.fs_unlink(directory .. '/output')
      uv.fs_rmdir(directory)
    end
  end

  ---@param command ExplorerCommand
  ---@param code integer
  ---@param options ExplorerCommandOptions
  ---@param callback fun(code: integer, output: string)
  local function finished(command, code, options, callback)
    if active ~= command then
      cleanup(command.directory)
      return
    end
    active = nil
    local output = ''
    if command.directory and code == 0 then
      local path = command.directory .. '/output'
      local stat = uv.fs_stat(path)
      if type(stat) ~= 'table' or stat.size > OUTPUT_MAX then
        code = 1
      else
        local descriptor = uv.fs_open(path, 'r', 0)
        if type(descriptor) == 'number' then
          local data = uv.fs_read(descriptor, OUTPUT_MAX, 0)
          uv.fs_close(descriptor)
          if type(data) == 'string' then
            output = data
          else
            code = 1
          end
        else
          code = 1
        end
      end
    end
    cleanup(command.directory)
    if
      code == 0
      and not options.keep
      and api.nvim_win_is_valid(command.window)
      and api.nvim_win_get_buf(command.window) == command.buffer
      and #api.nvim_tabpage_list_wins(api.nvim_win_get_tabpage(command.window)) > 1
    then
      api.nvim_win_close(command.window, false)
      if api.nvim_buf_is_valid(command.buffer) then
        api.nvim_buf_delete(command.buffer, { force = true })
      end
    end
    if api.nvim_win_is_valid(command.origin) then
      api.nvim_set_current_win(command.origin)
    end
    if code ~= 0 then
      notify('Operation failed or was cancelled (exit ' .. code .. '); inspect its terminal.', vim.log.levels.WARN)
    end
    callback(code, output)
  end

  ---@param argv string[]
  ---@param options? ExplorerCommandOptions
  ---@param callback? fun(code: integer, output: string)
  function M.run(argv, options, callback)
    options = vim.tbl_extend('force', {}, options or {})
    if active then
      notify('An explorer operation is active; finish it or call ExplorerCancel.')
      return
    end
    assert(#argv > 0 and #argv <= 64, 'invalid command argument count')
    for _, value in ipairs(argv) do
      assert(type(value) == 'string' and #value <= 8192 and not value:find('%z'))
    end
    if WINDOWS then
      local translated, err = windows_command(argv, options.elevated)
      if not translated then
        notify(err or 'Windows operation unavailable.')
        return
      end
      argv = translated
      options.elevated = false
    end
    local executable = fn.exepath(argv[1])
    if executable == '' then
      notify('Executable not found: ' .. argv[1], vim.log.levels.ERROR)
      return
    end
    local args = vim.deepcopy(argv)
    args[1] = executable
    if options.elevated then
      local sudo = fn.exepath('sudo')
      if sudo == '' then
        notify('sudo is unavailable.', vim.log.levels.ERROR)
        return
      end
      table.insert(args, 1, TERMUX and '-p' or '--')
      table.insert(args, 1, sudo)
    end
    local private
    if options.capture then
      local shell = fn.exepath('sh')
      if shell == '' then
        notify('Output capture requires POSIX sh.')
        return
      end
      private = uv.fs_mkdtemp(fn.tempname() .. '-explorer-XXXXXX')
      if type(private) ~= 'string' then
        notify('Cannot create private output directory.')
        return
      end
      uv.fs_chmod(private, 448)
      -- Fixed script; arguments are positional data, never evaluated as shell source.
      args = vim.list_extend({
        shell,
        '-c',
        'umask 077; ulimit -f 4096 || exit; out=$1; shift; exec "$@" > "$out"',
        'explorer-capture',
        private .. '/output',
      }, args)
    end
    local origin = api.nvim_get_current_win()
    vim.cmd.new({ mods = { split = 'botright' } })
    api.nvim_win_set_config(0, { height = 12 })
    local command = {
      buffer = api.nvim_get_current_buf(),
      directory = private,
      job = 0,
      origin = origin,
      window = api.nvim_get_current_win(),
    } ---@type ExplorerCommand
    active = command
    vim.bo[command.buffer].bufhidden = 'hide'
    command.job = fn.jobstart(args, {
      cwd = options.cwd or fn.getcwd(),
      env = options.env,
      term = true,
      on_exit = function(_, code)
        vim.schedule(function()
          finished(command, code, options, callback or function() end)
        end)
      end,
    })
    if command.job <= 0 then
      active = nil
      cleanup(private)
      notify('Unable to start operation terminal.', vim.log.levels.ERROR)
      return
    end
    api.nvim_create_autocmd('BufWipeout', {
      buffer = command.buffer,
      once = true,
      callback = function()
        if active == command then
          fn.jobstop(command.job)
        end
      end,
    })
    vim.cmd.startinsert()
  end

  function M.cancel()
    epoch = epoch + 1
    if active then
      fn.jobstop(active.job)
    end
  end

  ---@param path string
  local function edit_root(path)
    local editor = fn.exepath('nvim')
    if editor == '' then
      editor = vim.v.progpath
    end
    if WINDOWS or TERMUX then
      M.run({
        editor,
        '-u',
        'NONE',
        '-i',
        'NONE',
        '-n',
        '--cmd',
        'set nomodeline noexrc noswapfile noundofile nobackup nowritebackup',
        '--',
        path,
      }, { elevated = true, cwd = default_root() }, function(code)
        if code == 0 then
          vim.cmd.checktime()
        end
      end)
      return
    end
    local editor_command = fn.shellescape(editor)
      .. ' -u NONE -i NONE -n --cmd '
      .. fn.shellescape('set nomodeline noexrc noswapfile noundofile nobackup nowritebackup')
    M.run({ 'sudo', '--edit', '--', path }, {
      cwd = '/',
      env = { SUDO_EDITOR = editor_command, EDITOR = editor_command },
    }, function(code)
      if code == 0 then
        vim.cmd.checktime()
        notify('sudoedit finished; file timestamps checked.')
      end
    end)
  end

  ---@param path? string
  function M.edit(path)
    if type(path) == 'string' and path ~= '' then
      edit_root(fn.fnamemodify(path, ':p'))
      return
    end
    local token = epoch
    vim.ui.input({ prompt = 'Administrator edit file: ', completion = 'file' }, function(value)
      if token == epoch and type(value) == 'string' and value ~= '' then
        edit_root(fn.fnamemodify(value, ':p'))
      end
    end)
  end

  ---@param path? string
  function M.shell(path)
    local root = type(path) == 'string' and path ~= '' and fn.fnamemodify(path, ':p') or default_root()
    if WINDOWS then
      local payload = vim.base64.encode(root)
      local source = 'Set-Location -LiteralPath ([Text.Encoding]::UTF8.GetString('
        .. "[Convert]::FromBase64String('"
        .. payload
        .. "')))"
      M.run(
        { 'pwsh', '-NoLogo', '-NoProfile', '-NoExit', '-EncodedCommand', encoded_script(source) },
        { elevated = true, cwd = fn.getcwd() }
      )
      return
    end
    local shell = fn.exepath('bash')
    if shell == '' then
      notify('Install bash for the administrator shell.')
      return
    end
    M.run({
      shell,
      '--noprofile',
      '--norc',
      '-c',
      'cd -- "$1" && exec "$2" --noprofile --norc',
      'explorer-admin',
      root,
      shell,
    }, { elevated = true, cwd = '/', keep = true, env = { BASH_ENV = '', ENV = '' } })
  end

  ---@param prompt string
  ---@param initial string
  ---@param callback fun(value: string)
  local function input(prompt, initial, callback)
    local token = epoch
    vim.ui.input({ prompt = prompt, default = initial, completion = 'file' }, function(value)
      if token == epoch and type(value) == 'string' and value ~= '' and not value:find('%z') then
        callback(value)
      end
    end)
  end

  ---@param argv string[]
  ---@param root string
  local function execute(argv, root)
    M.run(argv, { elevated = true, cwd = '/' }, function(code)
      if code == 0 then
        M.browse(root)
      end
    end)
  end

  ---@param path string
  ---@param root string
  function M.actions(path, root)
    epoch = epoch + 1
    local token = epoch
    local actions = {
      'Browse directory',
      'Change mode',
      'Change owner/group',
      'Copy',
      'Create directory',
      'Create file',
      'Delete',
      'Delete recursively',
      'Edit/read as administrator',
      'Move/rename',
      'Root shell',
      'Symbolic link',
    }
    vim.ui.select(actions, { prompt = 'SUDO actions: ' .. label(path) }, function(choice)
      if not choice or epoch ~= token then
        return
      end
      if choice == 'Browse directory' then
        M.browse(path)
      elseif choice == 'Edit/read as administrator' then
        M.edit(path)
      elseif choice == 'Root shell' then
        M.shell(root)
      elseif choice == 'Change mode' then
        input('Mode (octal or symbolic): ', 'u+rw', function(mode)
          execute({ 'chmod', '--', mode, path }, root)
        end)
      elseif choice == 'Change owner/group' then
        input('Owner[:group]: ', '', function(owner)
          execute({ 'chown', '--no-dereference', '--', owner, path }, root)
        end)
      elseif choice == 'Delete' or choice == 'Delete recursively' then
        input('Type DELETE to remove ' .. label(path) .. ': ', '', function(answer)
          if answer == 'DELETE' then
            local argv = choice == 'Delete' and { 'rm', '-d', '--', path }
              or { 'rm', '-r', '--one-file-system', '--preserve-root=all', '--', path }
            execute(argv, root)
          end
        end)
      else
        input(choice .. ' destination: ', root .. '/', function(destination)
          if not absolute(destination) then
            notify('Enter an absolute destination path.')
            return
          end
          if choice == 'Create directory' then
            execute({ 'mkdir', '-p', '--', destination }, root)
          elseif choice == 'Create file' then
            execute({
              'sh',
              '-c',
              'umask 077; set -C; : > "$1"',
              'explorer-create',
              destination,
            }, root)
          elseif choice == 'Copy' then
            execute({ 'cp', '-a', '--no-clobber', '-T', '--', path, destination }, root)
          elseif choice == 'Move/rename' then
            execute({ 'mv', '--no-clobber', '-T', '--', path, destination }, root)
          elseif choice == 'Symbolic link' then
            execute({ 'ln', '-s', '-T', '--', path, destination }, root)
          end
        end)
      end
    end)
  end

  ---@param root string
  ---@param output string
  local function present(root, output)
    local items = {
      { label = '[Actions for this directory]', value = {
        kind = 'actions',
        path = root,
      } },
      { label = '../', value = { kind = 'd', path = vim.fs.dirname(root) or '/' } },
    }
    for kind, path in output:gmatch('([^%z]+)%z([^%z]+)%z') do
      if #items >= ITEMS_MAX then
        notify('Admin picker limited to 10000 entries.')
        break
      end
      items[#items + 1] =
        { label = kind .. '  ' .. label(path), value = {
          kind = kind,
          path = path,
        } }
    end
    table.sort(items, function(a, b)
      return a.label < b.label
    end)
    local token = epoch
    pick_items(M.fzf_module, items, function(value)
      if token ~= epoch or type(value) ~= 'table' or type(value.path) ~= 'string' then
        return
      end
      if value.kind == 'd' then
        M.browse(value.path)
      else
        M.actions(value.path, root)
      end
    end, { prompt = 'SUDO browse> ' })
  end

  ---@param root string
  local function windows_browser(root)
    if MODULE_PATH == '' or fn.filereadable(MODULE_PATH) ~= 1 then
      notify('Administrator navigation needs nt.lua loaded from a real file.')
      return
    end
    local bootstrap = "package.preload['config.nav.nt']=function() return dofile("
      .. string.format('%q', MODULE_PATH)
      .. ') end; '
    local module_name = M.fzf_module:gsub('%.', '/')
    local fzf_path = api.nvim_get_runtime_file('lua/' .. module_name .. '.lua', false)[1]
    if fzf_path then
      bootstrap = bootstrap
        .. 'package.preload['
        .. string.format('%q', M.fzf_module)
        .. ']=function() return dofile('
        .. string.format('%q', fzf_path)
        .. ') end; '
    end
    bootstrap = bootstrap .. "require('config.nav.nt').setup({fzf_module=" .. string.format('%q', M.fzf_module) .. '})'
    M.run({
      vim.v.progpath,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '-n',
      '--cmd',
      'set nomodeline noexrc noswapfile noundofile nobackup nowritebackup',
      '--cmd',
      'lua ' .. bootstrap,
      '-c',
      "lua require('config.nav.nt').open(" .. string.format('%q', root) .. ')',
    }, { elevated = true, cwd = fn.getcwd() })
  end

  ---@param path? string
  function M.browse(path)
    epoch = epoch + 1
    local token = epoch
    if type(path) ~= 'string' or path == '' then
      path = default_root()
    end
    local root = fn.fnamemodify(path, ':p')
    if WINDOWS then
      windows_browser(root)
      return
    end
    M.run({ 'find', '-H', root, '-mindepth', '1', '-maxdepth', '1', '-printf', '%y\\0%p\\0' }, {
      elevated = true,
      capture = true,
      cwd = '/',
    }, function(code, output)
      if code == 0 and token == epoch then
        present(root, output)
      end
    end)
  end
end

local M = {}

local ENTRIES_MAX = 10000
local OUTPUT_BYTES_MAX = 2 * 1024 * 1024
local TIMEOUT_MS = 5000

---@class ExplorerOptions
---@field fzf_module string
---@field position 'left'|'right'
---@field show_hidden boolean
---@field width integer

---@class ExplorerPane
---@field source integer
---@field window integer

---@class ExplorerEntry
---@field directory boolean
---@field name string
---@field path string

---@class ExplorerSnapshot
---@field bufnr integer
---@field cwd string
---@field cwd_dev integer
---@field cwd_ino integer
---@field generation integer
---@field window integer

---@class ExplorerIdentity
---@field dev integer
---@field ino integer
---@field type string

---@class ExplorerPickItem
---@field label string
---@field value string

---@class ExplorerFzf
---@field fzf_pick fun(items: ExplorerPickItem[], sink: fun(value: any), opts: {prompt: string})
---@field document_symbols? fun()
---@field git_status? fun()

---@class ExplorerScan
---@field chunks string[]
---@field process? vim.SystemObj
---@field size integer
---@field snapshot ExplorerSnapshot
---@field timer? uv.uv_timer_t
---@field truncated boolean

---@type ExplorerOptions
M.config = { fzf_module = 'config.nav.fzf', position = 'left', show_hidden = false, width = 40 }
---@type table<integer, ExplorerPane>
local panes = {}
---@type table<integer, integer>
local generations = {}
---@type table<string, string>
local commands = {}
---@type ExplorerScan?
local scan
local generation = 0
local group = 0

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'Native explorer' })
end

---@param bufnr integer
---@return string?
local function directory(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local name = api.nvim_buf_get_name(bufnr)
  if name == '' or fn.isdirectory(name) ~= 1 then
    return nil
  end
  local path = uv.fs_realpath(name)
  return type(path) == 'string' and path or nil
end

---@param path string
---@return ExplorerIdentity?
local function identity(path)
  local stat = uv.fs_lstat(path)
  if type(stat) ~= 'table' then
    return nil
  end
  return { dev = stat.dev, ino = stat.ino, type = stat.type }
end

---@param path string
---@param expected ExplorerIdentity
---@return boolean
local function same_entry(path, expected)
  local current = identity(path)
  return current ~= nil
    and current.dev == expected.dev
    and current.ino == expected.ino
    and current.type == expected.type
end

---@return ExplorerSnapshot?
local function snapshot()
  local bufnr = api.nvim_get_current_buf()
  local cwd = directory(bufnr)
  if not cwd or vim.bo[bufnr].filetype ~= 'directory' then
    notify('Open a native directory buffer first.', vim.log.levels.WARN)
    return nil
  end
  local stat = identity(cwd)
  if not stat then
    return nil
  end
  generation = generation + 1
  generations[bufnr] = generation
  return {
    bufnr = bufnr,
    cwd = cwd,
    cwd_dev = stat.dev,
    cwd_ino = stat.ino,
    generation = generation,
    window = api.nvim_get_current_win(),
  }
end

---@param saved ExplorerSnapshot
---@return boolean
local function current(saved)
  if
    generations[saved.bufnr] ~= saved.generation
    or not api.nvim_win_is_valid(saved.window)
    or api.nvim_win_get_buf(saved.window) ~= saved.bufnr
    or directory(saved.bufnr) ~= saved.cwd
  then
    return false
  end
  local stat = identity(saved.cwd)
  return stat ~= nil and stat.dev == saved.cwd_dev and stat.ino == saved.cwd_ino
end

---@param line string
---@param cwd string
---@return ExplorerEntry?
local function entry_from_line(line, cwd)
  if line == '' then
    return nil
  end
  local is_directory = line:sub(-1) == '/'
  local name = is_directory and line:sub(1, -2) or line
  name = name:gsub('%z', '\n') -- Native dir encodes a filename newline as NUL.
  if name == '' or name == '.' or name == '..' or name:find('/', 1, true) then
    return nil
  end
  return { directory = is_directory, name = name, path = fs.joinpath(cwd, name) }
end

---@return ExplorerEntry?
local function selected()
  local cwd = directory(api.nvim_get_current_buf())
  return cwd and entry_from_line(api.nvim_get_current_line(), cwd) or nil
end

---@param name string?
---@return boolean
local function valid_name(name)
  if WINDOWS and type(name) == 'string' then
    local stem = (name:match('^[^.]+') or name):upper()
    if
      name:find('[<>:"|?*]')
      or name:find('[. ]$')
      or stem:match('^COM[1-9]$')
      or stem:match('^LPT[1-9]$')
      or stem == 'CON'
      or stem == 'PRN'
      or stem == 'AUX'
      or stem == 'NUL'
    then
      return false
    end
  end
  return type(name) == 'string'
    and name ~= ''
    and name ~= '.'
    and name ~= '..'
    and #name <= 255
    and not name:find('[/\\%c]')
end

---@param path string
---@return boolean
local function has_buffer(path)
  path = path_key(path)
  local boundary = path .. '/'
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(bufnr) then
      local name = api.nvim_buf_get_name(bufnr)
      local resolved = uv.fs_realpath(name)
      name = path_key(name)
      if type(resolved) == 'string' then
        resolved = path_key(resolved)
      end
      if
        name == path
        or name:sub(1, #boundary) == boundary
        or (type(resolved) == 'string' and (resolved == path or resolved:sub(1, #boundary) == boundary))
      then
        return true
      end
    end
  end
  return false
end

---@param command string
---@param path string
---@return boolean
local function edit(command, path)
  local ok, err = pcall(api.nvim_cmd, {
    cmd = command,
    args = { path },
    magic = { bar = false, file = false },
  }, {})
  if not ok then
    notify(tostring(err), vim.log.levels.ERROR)
  end
  return ok
end

---@return ExplorerPane?
local function pane()
  local tab = api.nvim_get_current_tabpage()
  local item = panes[tab]
  if item and (not api.nvim_win_is_valid(item.window) or not directory(api.nvim_win_get_buf(item.window))) then
    panes[tab] = nil
    return nil
  end
  return item
end

---@return integer
local function target_window()
  local item = pane()
  if not item or item.window ~= api.nvim_get_current_win() then
    return api.nvim_get_current_win()
  end
  if
    api.nvim_win_is_valid(item.source)
    and item.source ~= item.window
    and api.nvim_win_get_tabpage(item.source) == api.nvim_get_current_tabpage()
  then
    return item.source
  end
  vim.cmd.vsplit({ mods = { split = 'botright' } })
  item.source = api.nvim_get_current_win()
  return item.source
end

---@param path string
---@param how? 'edit'|'split'|'vsplit'|'tabedit'
local function open_path(path, how)
  local stat = uv.fs_stat(path)
  if type(stat) ~= 'table' or (stat.type ~= 'file' and stat.type ~= 'directory') then
    notify('Entry is missing, unreadable, or is not a regular file/directory.')
    return
  end
  if stat.type == 'directory' then
    edit(how or 'edit', path)
    return
  end
  api.nvim_set_current_win(target_window())
  if edit(how or 'edit', path) then
    vim.bo[api.nvim_get_current_buf()].autoread = true
  end
end

---@param how? 'edit'|'split'|'vsplit'|'tabedit'
function M.open_selected(how)
  local item = selected()
  if item then
    open_path(item.path, how)
  end
end

function M.refresh()
  if directory(api.nvim_get_current_buf()) then
    local keys = api.nvim_replace_termcodes('<Plug>(nvim-dir-reload)', true, false, true)
    api.nvim_feedkeys(keys, 'm', false)
  end
end

---@param saved ExplorerSnapshot
local function refresh_snapshot(saved)
  if current(saved) then
    api.nvim_win_call(saved.window, function()
      -- :edit invokes native dir's BufReadCmd synchronously; no private API.
      vim.cmd.edit()
    end)
  end
end

---@param make_directory boolean
local function create(make_directory)
  local saved = snapshot()
  if not saved then
    return
  end
  local prompt = make_directory and 'New directory name: ' or 'New file name: '
  vim.ui.input({ prompt = prompt }, function(name)
    if name == nil or not current(saved) then
      return
    end
    if not valid_name(name) then
      notify('Use a single basename without separators or control characters.')
      return
    end
    local path = fs.joinpath(saved.cwd, name)
    local ok, err
    if make_directory then
      ok, err = uv.fs_mkdir(path, 448) -- 0700; never recursive.
    else
      local descriptor
      descriptor, err = uv.fs_open(path, 'wx', 384) -- 0600; never truncate/follow.
      if type(descriptor) == 'number' then
        ok, err = uv.fs_close(descriptor)
      end
    end
    if not ok then
      notify('Create failed: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    refresh_snapshot(saved)
  end)
end

function M.create_dir()
  create(true)
end

function M.create_file()
  create(false)
end

function M.delete()
  local item, saved = selected(), snapshot()
  if not item or not saved then
    return
  end
  local original = identity(item.path)
  if not original then
    return
  end
  vim.ui.select({ 'Cancel', 'Delete' }, {
    prompt = 'Delete ' .. vim.inspect(item.name) .. '? Directories must be empty.',
  }, function(choice)
    if choice ~= 'Delete' or not current(saved) or not same_entry(item.path, original) then
      return
    end
    if has_buffer(item.path) then
      notify('Close loaded buffers for this entry before deleting it.', vim.log.levels.WARN)
      return
    end
    if WINDOWS then
      operations.run({ 'rm', '-d', '--', item.path }, { cwd = saved.cwd }, function(code)
        if code == 0 then
          refresh_snapshot(saved)
        end
      end)
      return
    end
    local ok, err
    if original.type == 'directory' then
      ok, err = uv.fs_rmdir(item.path)
    else
      ok, err = uv.fs_unlink(item.path) -- Unlinks symlinks; never follows their target.
    end
    if not ok then
      notify('Delete failed: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    refresh_snapshot(saved)
  end)
end

---@param item ExplorerEntry
---@param original ExplorerIdentity
---@param saved ExplorerSnapshot
---@param name string
local function move(item, original, saved, name)
  local destination = fs.joinpath(saved.cwd, name)
  if not current(saved) or not same_entry(item.path, original) then
    return
  end
  if has_buffer(item.path) or has_buffer(destination) then
    notify('A source/destination buffer is loaded.', vim.log.levels.WARN)
    return
  end
  if identity(destination) then
    notify('Destination already exists; rename refused.', vim.log.levels.WARN)
    return
  end
  operations.run({
    'mv',
    '--no-clobber',
    '--no-copy',
    '--no-target-directory',
    '--',
    item.path,
    destination,
  }, { cwd = saved.cwd }, function(code)
    if code ~= 0 or identity(item.path) or not same_entry(destination, original) then
      notify('Rename failed or was refused; inspect the directory.', vim.log.levels.WARN)
    else
      notify('Renamed to ' .. vim.inspect(name))
    end
    refresh_snapshot(saved)
  end)
end

function M.rename()
  local item, saved = selected(), snapshot()
  if not item or not saved then
    return
  end
  local original = identity(item.path)
  if not original then
    return
  end
  vim.ui.input({ prompt = 'Rename to: ', default = item.name }, function(name)
    if name == nil or name == item.name then
      return
    end
    if not valid_name(name) then
      notify('Use a single basename without separators or control characters.')
      return
    end
    move(item, original, saved, name)
  end)
end

---@return ExplorerFzf?
local function fzf()
  local ok, module = pcall(require, M.config.fzf_module)
  return {
    fzf_pick = function(items, sink, options)
      pick_items(M.config.fzf_module, items, sink, options)
    end,
    document_symbols = ok and type(module) == 'table' and module.document_symbols or nil,
    git_status = ok and type(module) == 'table' and module.git_status or nil,
  }
end

---@param path string
---@return string
local function label(path)
  return (path:gsub('[%c]', function(char)
    return ('\\x%02X'):format(char:byte())
  end))
end

---@param saved ExplorerSnapshot
---@param items ExplorerPickItem[]
local function pick(saved, items)
  local picker = fzf()
  if not picker or not current(saved) then
    return
  end
  api.nvim_set_current_win(saved.window)
  picker.fzf_pick(items, function(value)
    if type(value) ~= 'string' or not current(saved) then
      return
    end
    api.nvim_set_current_win(saved.window)
    open_path(value)
  end, { prompt = 'Explorer files> ' })
end

function M.find_entries()
  local saved = snapshot()
  if not saved then
    return
  end
  local items = {} ---@type ExplorerPickItem[]
  for _, line in ipairs(api.nvim_buf_get_lines(saved.bufnr, 0, ENTRIES_MAX, false)) do
    local item = entry_from_line(line, saved.cwd)
    if item then
      items[#items + 1] = { label = label(line), value = item.path }
    end
  end
  pick(saved, items)
end

---@param running ExplorerScan
local function close_timer(running)
  local timer = running.timer
  running.timer = nil
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

function M.cancel()
  local running = scan
  scan = nil
  if running then
    close_timer(running)
    if running.process then
      pcall(running.process.kill, running.process, 9)
    end
  end
end

---@param running ExplorerScan
---@param data string
local function collect(running, data)
  if scan ~= running then
    return
  end
  local remaining = OUTPUT_BYTES_MAX - running.size
  if remaining > 0 and #data > 0 and #running.chunks < 4096 then
    local chunk = data:sub(1, remaining)
    running.chunks[#running.chunks + 1] = chunk
    running.size = running.size + #chunk
  end
  if #data > remaining or #running.chunks >= 4096 then
    running.truncated = true
    if running.process then
      pcall(running.process.kill, running.process, 9)
    end
  end
end

---@param running ExplorerScan
---@param result vim.SystemCompleted
local function finish_scan(running, result)
  if scan ~= running then
    return
  end
  scan = nil
  close_timer(running)
  if not current(running.snapshot) then
    return
  end
  if running.truncated or (result.code ~= 0 and result.code ~= 1) then
    notify('File search exceeded its budget or failed; browse a smaller directory.', vim.log.levels.WARN)
    return
  end
  local output = table.concat(running.chunks)
  local items = {} ---@type ExplorerPickItem[]
  for path in output:gmatch('([^%z]+)%z') do
    if #items >= ENTRIES_MAX then
      notify('Showing the first 10000 files; narrow the directory for complete results.')
      break
    end
    items[#items + 1] = { label = label(path), value = path }
  end
  table.sort(items, function(left, right)
    return left.label < right.label
  end)
  pick(running.snapshot, items)
end

function M.find_files()
  local saved = snapshot()
  if not saved then
    return
  end
  local executable = fn.exepath('rg')
  if executable == '' then
    notify('Recursive search requires ripgrep (rg); f searches the visible listing.')
    return
  end
  M.cancel()
  local argv = { executable, '--files', '--null', '--glob', '!.git' }
  if M.config.show_hidden then
    argv[#argv + 1] = '--hidden'
  end
  vim.list_extend(argv, { '--', saved.cwd })
  ---@type ExplorerScan
  local running = { chunks = {}, size = 0, snapshot = saved, truncated = false }
  scan = running
  local ok, process = pcall(vim.system, argv, {
    cwd = saved.cwd,
    env = { RIPGREP_CONFIG_PATH = '' },
    stderr = false,
    stdout = function(err, data)
      if err then
        running.truncated = true
      end
      if data then
        collect(running, data)
      end
    end,
    timeout = TIMEOUT_MS,
  }, function(result)
    vim.schedule(function()
      finish_scan(running, result)
    end)
  end)
  if not ok then
    scan = nil
    notify('File search failed: ' .. tostring(process), vim.log.levels.ERROR)
    return
  end
  running.process = process
  running.timer = vim.defer_fn(function()
    running.timer = nil
    if scan == running then
      pcall(process.kill, process, 9)
    end
  end, TIMEOUT_MS + 1000)
end

---@param action 'document_symbols'|'git_status'
local function source_picker(action)
  M.cancel()
  if WINDOWS and fn.executable('sh') ~= 1 then
    notify('This FZF Git/symbol picker requires Git for Windows sh.exe on PATH.')
    return
  end
  local picker = fzf()
  if not picker then
    return
  end
  local target = target_window()
  if directory(api.nvim_win_get_buf(target)) then
    notify('Open a source file first; this action uses its LSP/project context.')
    return
  end
  local callback = picker[action]
  if type(callback) ~= 'function' then
    notify('FZF module does not provide ' .. action, vim.log.levels.WARN)
    return
  end
  api.nvim_set_current_win(target)
  callback()
end

function M.git_status()
  source_picker('git_status')
end

function M.symbols()
  source_picker('document_symbols')
end

function M.toggle_hidden()
  M.config.show_hidden = not M.config.show_hidden
  M.refresh()
end

function M.yank_path()
  local item = selected()
  if item then
    fn.setreg('"', item.path)
    notify('Copied path to the unnamed register.')
  end
end

function M.close()
  M.cancel()
  local tab = api.nvim_get_current_tabpage()
  local item = pane()
  panes[tab] = nil
  if item then
    local bufnr = api.nvim_win_get_buf(item.window)
    generations[bufnr] = nil
    if #api.nvim_tabpage_list_wins(tab) > 1 then
      api.nvim_win_close(item.window, false)
    elseif api.nvim_buf_is_valid(fn.bufnr('#')) then
      vim.cmd.buffer(fn.bufnr('#'))
    end
    return
  end
  if directory(api.nvim_get_current_buf()) then
    generations[api.nvim_get_current_buf()] = nil
    local alternate = fn.bufnr('#')
    if alternate > 0 and api.nvim_buf_is_valid(alternate) then
      vim.cmd.buffer(alternate)
    end
  end
end

function M.help()
  notify(table.concat({
    '<CR>: open | -: parent | R: reload | q: close',
    'a: create file | A: create directory | d: delete | r: rename',
    'f: fuzzy visible entries | F: recursive files | H: toggle hidden',
    'G: source-project Git status | S: source-document LSP symbols',
    's/v/t: split/vertical/tab | y: copy path | <C-c>: cancel operation',
    'c/m/x: copy/move/symlink | D: recursive delete | P/O: mode/owner',
    'E: administrator edit | U: administrator browser | :ExplorerShell: admin shell',
  }, '\n'))
end

-- File operations are explicit. Authentication happens in a terminal or the Windows UAC dialog.
---@param action 'copy'|'move'|'link'
local function transfer(action)
  local item, saved = selected(), snapshot()
  if not item or not saved then
    return
  end
  local original = identity(item.path)
  if not original then
    return
  end
  vim.ui.input(
    { prompt = action .. ' destination: ', default = saved.cwd .. '/', completion = 'file' },
    function(destination)
      if
        type(destination) ~= 'string'
        or destination == ''
        or not current(saved)
        or not same_entry(item.path, original)
      then
        return
      end
      if not absolute(destination) then
        destination = fs.joinpath(saved.cwd, destination)
      end
      if identity(destination) or has_buffer(destination) then
        notify('Destination exists or has a loaded buffer.')
        return
      end
      if action == 'move' and has_buffer(item.path) then
        notify('Close source buffers before moving; unsaved content is preserved.')
        return
      end
      local argv = action == 'copy' and { 'cp', '-a', '--no-clobber', '-T', '--' }
        or action == 'move' and { 'mv', '--no-clobber', '-T', '--' }
        or { 'ln', '-s', '-T', '--' }
      vim.list_extend(argv, { item.path, destination })
      operations.run(argv, { cwd = saved.cwd }, function(code)
        if code == 0 then
          refresh_snapshot(saved)
        end
      end)
    end
  )
end

function M.copy()
  transfer('copy')
end
function M.move()
  transfer('move')
end
function M.symlink()
  transfer('link')
end

function M.delete_tree()
  local item, saved = selected(), snapshot()
  if not item or not saved then
    return
  end
  local original = identity(item.path)
  if not original then
    return
  end
  vim.ui.input({ prompt = 'Type DELETE to recursively remove ' .. label(item.path) .. ': ' }, function(answer)
    if answer ~= 'DELETE' or not current(saved) or not same_entry(item.path, original) then
      return
    end
    if has_buffer(item.path) then
      notify('Close buffers below this path first.')
      return
    end
    operations.run(
      { 'rm', '-r', '--one-file-system', '--preserve-root=all', '--', item.path },
      { cwd = saved.cwd },
      function(code)
        if code == 0 then
          refresh_snapshot(saved)
        end
      end
    )
  end)
end

function M.permissions()
  local item, saved = selected(), snapshot()
  if not item or not saved then
    return
  end
  local original = identity(item.path)
  if not original then
    return
  end
  vim.ui.input({
    prompt = WINDOWS and 'ACL grant (user:permission): ' or 'Mode: ',
    default = WINDOWS and ((vim.env.USERNAME or '') .. ':M') or 'u+rw',
  }, function(mode)
    if type(mode) ~= 'string' or mode == '' or not current(saved) or not same_entry(item.path, original) then
      return
    end
    operations.run({ 'chmod', '--', mode, item.path }, { cwd = saved.cwd }, function(code)
      if code == 0 then
        refresh_snapshot(saved)
      end
    end)
  end)
end

function M.ownership()
  local item, saved = selected(), snapshot()
  if not item or not saved then
    return
  end
  local original = identity(item.path)
  if not original then
    return
  end
  vim.ui.input({ prompt = WINDOWS and 'Owner (DOMAIN\\user): ' or 'Owner[:group]: ' }, function(owner)
    if type(owner) ~= 'string' or owner == '' or not current(saved) or not same_entry(item.path, original) then
      return
    end
    operations.run(
      { 'chown', '--no-dereference', '--', owner, item.path },
      { cwd = saved.cwd, elevated = true },
      function(code)
        if code == 0 then
          refresh_snapshot(saved)
        end
      end
    )
  end)
end

---@param path? string
function M.admin(path)
  M.cancel()
  operations.browse(path and path ~= '' and path or directory(api.nvim_get_current_buf()) or default_root())
end

---@param path? string
function M.sudoedit(path)
  M.cancel()
  local item = selected()
  operations.edit(path and path ~= '' and path or (item and item.path))
end

---@param path? string
function M.shell(path)
  M.cancel()
  operations.shell(path and path ~= '' and path or directory(api.nvim_get_current_buf()) or default_root())
end

function M.cancel_operations()
  M.cancel()
  operations.cancel()
  for bufnr in pairs(generations) do
    generations[bufnr] = nil
  end
end

---@param bufnr integer
local function attach(bufnr)
  if not api.nvim_buf_is_valid(bufnr) or not directory(bufnr) then
    return
  end
  -- Only local directory-buffer keys are owned here; no leader mappings.
  local mappings = {
    {
      '<CR>',
      function()
        M.open_selected()
      end,
      'Open entry',
    },
    { '<C-c>', M.cancel_operations, 'Cancel current explorer operation' },
    { '?', M.help, 'Explorer help' },
    { 'A', M.create_dir, 'Create directory' },
    { 'D', M.delete_tree, 'Delete recursively' },
    { 'E', M.sudoedit, 'Edit/read as administrator' },
    { 'F', M.find_files, 'FZF recursive files' },
    { 'G', M.git_status, 'FZF source-project Git status' },
    { 'H', M.toggle_hidden, 'Toggle hidden entries' },
    { 'O', M.ownership, 'Set owner/group as administrator' },
    { 'P', M.permissions, 'Change permissions / Windows ACL grant' },
    { 'S', M.symbols, 'FZF source-document symbols' },
    { 'U', M.admin, 'Administrator directory browser' },
    { 'a', M.create_file, 'Create file exclusively' },
    { 'c', M.copy, 'Copy file/directory' },
    { 'd', M.delete, 'Delete file or empty directory' },
    { 'f', M.find_entries, 'FZF visible entries' },
    { 'm', M.move, 'Move file/directory' },
    {
      'o',
      function()
        M.open_selected('split')
      end,
      'Open in horizontal split',
    },
    { 'q', M.close, 'Close explorer' },
    { 'r', M.rename, 'Rename without overwriting' },
    {
      's',
      function()
        M.open_selected('split')
      end,
      'Open in horizontal split',
    },
    {
      't',
      function()
        M.open_selected('tabedit')
      end,
      'Open in tab',
    },
    {
      'v',
      function()
        M.open_selected('vsplit')
      end,
      'Open in vertical split',
    },
    { 'x', M.symlink, 'Create symbolic link' },
    { 'y', M.yank_path, 'Copy entry path' },
  }
  for _, mapping in ipairs(mappings) do
    vim.keymap.set('n', mapping[1], mapping[2], {
      buf = bufnr,
      desc = 'Explorer: ' .. mapping[3],
      silent = true,
    })
  end
  vim.keymap.set('n', '-', '<Plug>(nvim-dir-up)', {
    buf = bufnr,
    desc = 'Explorer: Parent directory',
    silent = true,
  })
  vim.bo[bufnr].bufhidden = 'hide'
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  for _, window in ipairs(fn.win_findbuf(bufnr)) do
    vim.wo[window].cursorline = true
    vim.wo[window].number = false
    vim.wo[window].relativenumber = false
    vim.wo[window].wrap = false
  end
end

---@param bufnr integer
local function render(bufnr)
  if not directory(bufnr) then
    return
  end
  local lines = {} ---@type string[]
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line ~= '' and (M.config.show_hidden or line:sub(1, 1) ~= '.') then
      if #lines == ENTRIES_MAX then
        notify('Directory view limited to 10000 entries.', vim.log.levels.WARN)
        break
      end
      lines[#lines + 1] = line
    end
  end
  table.sort(lines, function(left, right)
    local left_dir, right_dir = left:sub(-1) == '/', right:sub(-1) == '/'
    return left_dir ~= right_dir and left_dir or (left_dir == right_dir and left < right)
  end)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  -- Native dir installs its default maps after DirReadPost. Apply ours afterwards.
  vim.schedule(function()
    attach(bufnr)
  end)
end

---@return boolean
local function backend()
  if fn.has('nvim-0.13') ~= 1 or #api.nvim_get_runtime_file('plugin/dir.lua', false) == 0 then
    notify('This config needs Neovim 0.13 with the builtin dir plugin.', vim.log.levels.ERROR)
    return false
  end
  if vim.g.loaded_nvim_dir_plugin == nil then
    vim.cmd.runtime('plugin/dir.lua')
  end
  if fn.maparg('<Plug>(nvim-dir-reload)', 'n') == '' then
    notify('The builtin dir plugin is disabled; remove loaded_nvim_dir_plugin from your config.')
    return false
  end
  return true
end

---@param path? string
function M.open(path)
  if not backend() then
    return
  end
  local item = pane()
  if item and (not path or path == '') then
    api.nvim_set_current_win(item.window)
    return
  end
  local root = path
  if not root or root == '' then
    local name = api.nvim_buf_get_name(0)
    root = directory(api.nvim_get_current_buf()) or (name ~= '' and fs.dirname(name) or nil) or fn.getcwd()
  end
  local real_root = uv.fs_realpath(fn.fnamemodify(root, ':p'))
  if type(real_root) ~= 'string' or fn.isdirectory(real_root) ~= 1 then
    notify('Explorer root must be an existing local directory.', vim.log.levels.WARN)
    return
  end
  if item then
    api.nvim_set_current_win(item.window)
    edit('edit', real_root)
    return
  end
  local source = api.nvim_get_current_win()
  local split = M.config.position == 'left' and 'topleft' or 'botright'
  vim.cmd.vsplit({ mods = { split = split } })
  local window = api.nvim_get_current_win()
  if not edit('edit', real_root) then
    api.nvim_win_close(window, false)
    return
  end
  panes[api.nvim_get_current_tabpage()] = { source = source, window = window }
  api.nvim_win_set_config(window, { width = M.config.width })
  vim.wo[window].winfixwidth = true
end

---@param path? string
function M.toggle(path)
  if pane() then
    M.close()
  else
    M.open(path)
  end
end

---@param name string
---@param callback fun(command: vim.api.keyset.create_user_command.command_args)
---@param description string
---@param completion? 'dir'|'file'
local function command(name, callback, description, completion)
  local existing = api.nvim_get_commands({ builtin = false })[name]
  if existing then
    if commands[name] == existing.definition then
      return
    end
    notify('Preserving existing command :' .. name, vim.log.levels.WARN)
    return
  end
  api.nvim_create_user_command(name, callback, {
    complete = completion,
    desc = description,
    force = false,
    nargs = completion and '?' or 0,
  })
  commands[name] = api.nvim_get_commands({ builtin = false })[name].definition
end

function M.create_commands()
  command('Explorer', function(args)
    M.toggle(args.args)
  end, 'Toggle native explorer', 'dir')
  command('ExplorerAdmin', function(args)
    M.admin(args.args)
  end, 'Administrator file browser', 'dir')
  command('ExplorerCancel', function()
    M.cancel_operations()
  end, 'Cancel explorer operation')
  command('ExplorerClose', function()
    M.close()
  end, 'Close native explorer')
  command('ExplorerFind', function()
    M.find_files()
  end, 'Find files below explorer directory')
  command('ExplorerOpen', function(args)
    M.open(args.args)
  end, 'Open native explorer', 'dir')
  command('ExplorerRefresh', function()
    M.refresh()
  end, 'Reload native explorer')
  command('ExplorerShell', function(args)
    M.shell(args.args)
  end, 'Explicit administrator shell', 'dir')
  command('ExplorerSudoEdit', function(args)
    M.sudoedit(args.args)
  end, 'Edit/read as administrator', 'file')
end

---@param opts? {fzf_module?: string, position?: 'left'|'right', show_hidden?: boolean, width?: integer}
function M.setup(opts)
  local config = vim.tbl_extend('force', {}, M.config, opts or {})
  assert(config.position == 'left' or config.position == 'right', 'position: left or right')
  assert(type(config.width) == 'number' and config.width % 1 == 0, 'width must be an integer')
  assert(config.width >= 20 and config.width <= 120, 'width must be 20..120')
  assert(type(config.show_hidden) == 'boolean', 'show_hidden must be boolean')
  assert(type(config.fzf_module) == 'string' and config.fzf_module ~= '', 'invalid FZF module')
  if not backend() then
    return
  end
  M.cancel()
  M.config = {
    fzf_module = config.fzf_module,
    position = config.position,
    show_hidden = config.show_hidden,
    width = config.width,
  }
  operations.fzf_module = M.config.fzf_module
  group = api.nvim_create_augroup('NativeExplorerConfig', { clear = true })
  api.nvim_create_autocmd('User', {
    callback = function(args)
      render(args.buf)
    end,
    group = group,
    pattern = 'DirReadPost',
  })
  api.nvim_create_autocmd('FileType', {
    callback = function(args)
      attach(args.buf)
    end,
    group = group,
    pattern = 'directory',
  })
  api.nvim_create_autocmd('BufWipeout', {
    callback = function(args)
      generations[args.buf] = nil
    end,
    group = group,
  })
  api.nvim_create_autocmd('VimLeavePre', { callback = M.cancel_operations, group = group })
  M.create_commands()
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if vim.bo[bufnr].filetype == 'directory' then
      attach(bufnr)
    end
  end
end

return M
