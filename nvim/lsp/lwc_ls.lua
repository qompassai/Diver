-- /qompassai/Diver/lsp/lwc_ls.lua
-- Qompass AI Lightning Web Components (LWC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
---@source https://github.com/forcedotcom/lightning-language-server/
local uv = vim.uv
local function path_join(...)
  return table.concat({ ... }, '/')
end
---@param path string|nil
---@return boolean
local function exists(path)
  return type(path) == 'string' and uv.fs_stat(path) ~= nil
end
---@param path string
---@return string|nil
local function read_file(path)
  local fd = uv.fs_open(path, 'r', 438)
  if not fd then
    return nil
  end

  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil
  end

  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data
end

---@param path string
---@param content string
local function write_file(path, content)
  local dir = vim.fs.dirname(path)
  if dir and dir ~= '' then
    vim.fn.mkdir(dir, 'p')
  end

  local fd = assert(uv.fs_open(path, 'w', 420))
  assert(uv.fs_write(fd, content, 0))
  uv.fs_close(fd)
end

---@param obj any
---@return string
local function json_encode(obj)
  return vim.json.encode(obj)
end

---@param fname string
---@return string|nil
local function find_root(fname)
  return vim.fs.root(fname, {
    'sfdx-project.json',
    'sfdx-project.jsonc',
    'lwc.config.json',
    'package.json',
    '.git',
  })
end

---@param bufnr integer
---@param on_dir fun(root:string|nil)
local function lwc_root_dir(bufnr, on_dir)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  on_dir(find_root(fname))
end

---@param root string|nil
---@return string|nil
local function find_sfdx_project(root)
  if not root then
    return nil
  end

  local p = path_join(root, 'sfdx-project.json')
  if exists(p) then
    return p
  end

  return nil
end

---@param root string|nil
---@return table|nil
local function read_sfdx_project(root)
  local file = find_sfdx_project(root)
  if not file then
    return nil
  end
  local raw = read_file(file)
  if not raw or raw == '' then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, raw)
  if ok and type(decoded) == 'table' then
    return decoded
  end
  return nil
end
---@param root string
---@return string[]
local function get_package_dirs(root)
  local project = read_sfdx_project(root)
  if type(project) ~= 'table' or type(project.packageDirectories) ~= 'table' then
    return { 'force-app' }
  end

  local dirs = {}

  for _, item in ipairs(project.packageDirectories) do
    if type(item) == 'table' and type(item.path) == 'string' and item.path ~= '' then
      dirs[#dirs + 1] = item.path
    end
  end

  if #dirs == 0 then
    dirs[1] = 'force-app'
  end

  return dirs
end

---@param root string
local function ensure_forceignore_has_jsconfig(root)
  local forceignore = path_join(root, '.forceignore')
  local line = 'jsconfig.json'
  local content = read_file(forceignore)

  if not content then
    write_file(forceignore, line .. '\n')
    return
  end

  if not content:match('(^|\n)jsconfig%.json(\n|$)') then
    write_file(forceignore, content:gsub('%s*$', '') .. '\n' .. line .. '\n')
  end
end

---@param root string
---@param module_dir string
---@param typings_dir string
---@param prefer_ts boolean
local function make_jsconfig(root, module_dir, typings_dir, prefer_ts)
  local tsconfig = path_join(module_dir, 'tsconfig.json')
  local jsconfig = path_join(module_dir, 'jsconfig.json')

  if prefer_ts and exists(tsconfig) then
    return
  end

  if exists(tsconfig) then
    return
  end

  local include = { '**/*' }

  if exists(path_join(root, typings_dir)) then
    include[#include + 1] = path_join(root, typings_dir, '**/*.d.ts')
  end

  local config = {
    compilerOptions = {
      allowJs = true,
      checkJs = true,
      experimentalDecorators = true,
    },
    include = include,
  }

  local rendered = json_encode(config) .. '\n'

  if not exists(jsconfig) then
    write_file(jsconfig, rendered)
    return
  end

  local old = read_file(jsconfig)
  if old ~= rendered then
    write_file(jsconfig, rendered)
  end
end

---@param root string|nil
local function ensure_lwc_workspace_files(root)
  if not root then
    return
  end

  local project = read_sfdx_project(root) or {}
  local default_lwc_language = project.defaultLwcLanguage
  local prefer_ts = default_lwc_language == 'typescript'
  local typings_dir = '.sfdx/typings/lwc'
  ensure_forceignore_has_jsconfig(root)
  for _, pkg in ipairs(get_package_dirs(root)) do
    local pkg_root = path_join(root, pkg)

    local lwc_dir = path_join(pkg_root, 'main', 'default', 'lwc')
    if exists(lwc_dir) then
      make_jsconfig(root, lwc_dir, typings_dir, prefer_ts)
    end
    local modules_dir = path_join(pkg_root, 'modules')
    if exists(modules_dir) then
      make_jsconfig(root, modules_dir, typings_dir, prefer_ts)
    end
  end
end

---@param client vim.lsp.Client
---@param changes table[]
local function notify_changed_files(client, changes)
  if client:is_stopped() then
    return
  end

  if not client:supports_method('workspace/didChangeWatchedFiles') then
    return
  end

  client:notify('workspace/didChangeWatchedFiles', {
    changes = changes,
  })
end

---@param kind '"created"'|'"changed"'|'"deleted"'
---@return integer
local function file_change_type(kind)
  if kind == 'created' then
    return 1
  elseif kind == 'changed' then
    return 2
  elseif kind == 'deleted' then
    return 3
  end

  return 2
end

---@param client vim.lsp.Client
---@param root string|nil
---@param group_name string
local function register_lwc_watchers(client, root, group_name)
  if not root then
    return
  end

  local patterns = {
    '**/*.resource',
    '**/labels/CustomLabels.labels-meta.xml',
    '**/staticresources/*.resource-meta.xml',
    '**/contentassets/*.asset-meta.xml',
    '**/lwc/*.js',
    '**/modules/*.js',
    '**/modules/*.ts',
    '**/sfdx-project.json',
  }

  local regexes = {}
  for _, glob in ipairs(patterns) do
    regexes[#regexes + 1] = vim.fn.glob2regpat(glob)
  end

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileWritePost' }, {
    group = vim.api.nvim_create_augroup(group_name, { clear = true }),
    pattern = '*',
    callback = function(args)
      local file = vim.api.nvim_buf_get_name(args.buf)
      if file == '' or not vim.startswith(file, root) then
        return
      end

      local rel = vim.fs.relpath(file, root) or file
      local matched = false

      for _, re in ipairs(regexes) do
        if rel:match(re) then
          matched = true
          break
        end
      end

      if not matched then
        return
      end

      if rel == 'sfdx-project.json' then
        ensure_lwc_workspace_files(root)
      end

      notify_changed_files(client, {
        {
          uri = vim.uri_from_fname(file),
          type = file_change_type('changed'),
        },
      })
    end,
  })
end

---@param client vim.lsp.Client
---@param bufnr integer
local function lwc_on_attach(client, bufnr)
  local root = client.config.root_dir
  if type(root) ~= 'string' or root == '' then
    root = find_root(vim.api.nvim_buf_get_name(bufnr))
  end

  ensure_lwc_workspace_files(root)
  register_lwc_watchers(client, root, 'lwc-ls-watch-' .. client.id)

  vim.api.nvim_create_user_command('LwcHealthCheck', function()
    local messages = {}

    local sfdx = find_sfdx_project(root)
    if sfdx then
      messages[#messages + 1] = 'OK sfdx-project.json: ' .. sfdx
    else
      messages[#messages + 1] = 'MISSING sfdx-project.json'
    end

    local typings = root and path_join(root, '.sfdx/typings/lwc') or nil
    if exists(typings) then
      messages[#messages + 1] = 'OK typings: ' .. typings
    else
      messages[#messages + 1] = 'MISSING typings dir: ' .. tostring(typings)
    end

    vim.notify(table.concat(messages, '\n'), vim.log.levels.INFO, {
      title = 'lwc_ls',
    })
  end, { force = true })
end

return ---@type vim.lsp.Config
{
  cmd = {
    'lwc-language-server',
    '--stdio',
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'html',
    'xml',
  },
  root_dir = lwc_root_dir,
  root_markers = {
    'sfdx-project.json',
    'sfdx-project.jsonc',
    'lwc.config.json',
    'package.json',
    '.git',
  },
  init_options = {
    workspaceType = 'SFDX',
    embeddedLanguages = {
      javascript = true,
    },
    sfdxTypingsDir = '.sfdx/typings/lwc',
  },
  settings = {
    lwc = {
      preview = {
        typeScriptSupport = true,
      },
      typings = {
        sfdx = '.sfdx/typings/lwc',
        vscode = '.vscode/typings/lwc',
      },
      namespaces = {
        lwc = 'lwc',
        aura = 'aura',
      },
    },
  },
  on_attach = lwc_on_attach,
}
