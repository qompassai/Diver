-- /qompassai/Diver/lua/utils/ddx.lua
-- Qompass AI Diver Util Differential Diagnosis (DDX) config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local fn = vim.fn
local notify = vim.notify
local uv = vim.uv
local levels = vim.log.levels
local M = {}
local ddx_group = api.nvim_create_augroup('QompassDDX', {
  clear = true,
})
local function strip_ansi(bufnr)
  local cur = api.nvim_get_current_buf()
  if bufnr and api.nvim_buf_is_valid(bufnr) and bufnr ~= cur then
    api.nvim_set_current_buf(bufnr)
  end
  vim.cmd([[%s/\%x1b\[[0-9;]*m//g]])
  if bufnr and api.nvim_buf_is_valid(cur) and api.nvim_get_current_buf() ~= cur then
    api.nvim_set_current_buf(cur)
  end
end

local function scandir(root)
  local handle = uv.fs_scandir(root)
  if not handle then
    return {}
  end

  local results = {}
  while true do
    local name, t = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    results[#results + 1] = {
      name = name,
      type = t,
    }
  end
  return results
end

local function to_module(root, path)
  local rel = path:gsub('^' .. vim.pesc(root) .. '/?', '')
  rel = rel:gsub('%.lua$', '')
  rel = rel:gsub('/', '.')
  rel = rel:gsub('%.init$', '')
  return rel
end

local function collect_lua_files(root)
  local files = {}

  local function walk(dir)
    for _, entry in ipairs(scandir(dir)) do
      local full = dir .. '/' .. entry.name
      if entry.type == 'file' and entry.name:match('%.lua$') then
        files[#files + 1] = full
      elseif entry.type == 'directory' then
        walk(full)
      end
    end
  end

  walk(root)
  table.sort(files)
  return files
end

local function make_qf_item(file, text, lnum, col, item_type)
  return {
    filename = file,
    lnum = lnum or 1,
    col = col or 1,
    text = text,
    type = item_type,
  }
end

local function write_log(fh, msg)
  if fh then
    fh:write(msg .. '\n')
  end
end

local function syntaxcheck_file(file)
  local chunk, err = loadfile(file)
  if not chunk then
    return false, tostring(err)
  end
  return true, nil
end

local function parse_lua_error(err)
  if type(err) ~= 'string' then
    return nil, nil
  end

  local lnum, msg = err:match(':(%d+):%s*(.+)$')
  if lnum then
    return tonumber(lnum), msg
  end

  return nil, err
end

local function safe_require(mod)
  return pcall(require, mod)
end

local function check_lazy_state(qf_items, fh)
  local lazy_loaded = package.loaded['lazy'] ~= nil

  write_log(fh, ('[probe] lazy loaded: %s'):format(tostring(lazy_loaded)))
  write_log(fh, ('[probe] g:lazy_did_setup: %s'):format(tostring(vim.g.lazy_did_setup)))

  if vim.g.lazy_did_setup and not lazy_loaded then
    qf_items[#qf_items + 1] = make_qf_item(
      fn.stdpath('config') .. '/init.lua',
      "[lazy] g:lazy_did_setup is set but package.loaded['lazy'] is nil"
    )
  end
end

local function check_pack_state(qf_items, fh)
  local has_pack = type(vim.pack) == 'table'
  local has_add = type(vim.pack and vim.pack.add) == 'function'
  local has_update = type(vim.pack and vim.pack.update) == 'function'

  write_log(fh, ('[probe] vim.pack available: %s'):format(tostring(has_pack)))
  write_log(fh, ('[probe] vim.pack.add available: %s'):format(tostring(has_add)))
  write_log(fh, ('[probe] vim.pack.update available: %s'):format(tostring(has_update)))

  if not has_pack then
    qf_items[#qf_items + 1] =
      make_qf_item(fn.stdpath('config') .. '/init.lua', '[vim.pack] vim.pack table is unavailable')
    return
  end

  if not has_add then
    qf_items[#qf_items + 1] =
      make_qf_item(fn.stdpath('config') .. '/init.lua', '[vim.pack] vim.pack.add is unavailable')
  end

  if not has_update then
    qf_items[#qf_items + 1] =
      make_qf_item(fn.stdpath('config') .. '/init.lua', '[vim.pack] vim.pack.update is unavailable')
  end
end

local function check_lualine_state(qf_items, fh)
  local config_file = fn.stdpath('config') .. '/lua/config/ui/line.lua'
  local loaded = package.loaded['lualine'] ~= nil
  local ok_line, line_mod = safe_require('config.ui.line')
  local ok_lualine, lualine_mod = safe_require('lualine')
  local statusline = vim.o.statusline

  write_log(fh, ("[probe:lualine] package.loaded['lualine'] = %s"):format(tostring(loaded)))
  write_log(fh, ("[probe:lualine] require('config.ui.line') = %s"):format(tostring(ok_line)))
  write_log(fh, ("[probe:lualine] require('lualine') = %s"):format(tostring(ok_lualine)))
  write_log(fh, ('[probe:lualine] vim.o.statusline = %s'):format(statusline == '' and '<empty>' or statusline))

  if not ok_line then
    qf_items[#qf_items + 1] =
      make_qf_item(config_file, '[lualine] failed to require config.ui.line: ' .. tostring(line_mod))
    return
  end

  if type(line_mod) ~= 'table' or type(line_mod.setup) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(config_file, '[lualine] config.ui.line.setup missing or invalid')
  end

  if not ok_lualine then
    qf_items[#qf_items + 1] =
      make_qf_item(config_file, '[lualine] plugin module could not be required: ' .. tostring(lualine_mod))
  end

  if not loaded then
    qf_items[#qf_items + 1] = make_qf_item(config_file, '[lualine] plugin module is not loaded at runtime')
  end

  if statusline == '' then
    qf_items[#qf_items + 1] = make_qf_item(config_file, '[lualine] vim.o.statusline is empty')
  end
end

local function check_luarocks_state(qf_items, fh)
  local file = fn.stdpath('config') .. '/lua/config/lang/lua.lua'
  local ok_cfg, cfg = safe_require('config.lang.lua')

  write_log(fh, ("[probe:luarocks] require('config.lang.lua') = %s"):format(tostring(ok_cfg)))

  if not ok_cfg then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] failed to require config.lang.lua: ' .. tostring(cfg))
    return
  end

  if type(cfg.lua_luarocks) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] config.lang.lua.lua_luarocks is missing')
    return
  end

  local ok_opts, opts = pcall(cfg.lua_luarocks, {})
  write_log(fh, ('[probe:luarocks] lua_luarocks({}) = %s'):format(tostring(ok_opts)))

  if not ok_opts then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] lua_luarocks() failed: ' .. tostring(opts))
    return
  end

  if type(opts) ~= 'table' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] lua_luarocks() did not return a table')
    return
  end

  if type(opts.rocks) ~= 'table' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] lua_luarocks() returned no rocks table')
  end

  local ok_lr, lr = safe_require('luarocks-nvim')
  write_log(fh, ("[probe:luarocks] require('luarocks-nvim') = %s"):format(tostring(ok_lr)))

  if not ok_lr then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] luarocks-nvim module missing: ' .. tostring(lr))
    return
  end

  if type(lr.setup) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] luarocks-nvim.setup missing or invalid')
  end
end

local function check_lsp_state(qf_items, fh)
  local file = fn.stdpath('config') .. '/lua/config/core/lsp.lua'
  local ok, result = safe_require('config.core.lsp')

  write_log(fh, ("[probe:lsp] require('config.core.lsp') = %s"):format(tostring(ok)))
  write_log(fh, ('[probe:lsp] active clients = %d'):format(#vim.lsp.get_clients()))

  if not ok then
    qf_items[#qf_items + 1] = make_qf_item(file, '[lsp] failed to require config.core.lsp: ' .. tostring(result))
  end
end

local function check_mapping_modules(qf_items, fh)
  local checks = {
    {
      mod = 'mappings.ddxmap',
      file = fn.stdpath('config') .. '/lua/mappings/ddxmap.lua',
    },
  }

  for _, item in ipairs(checks) do
    local ok, result = safe_require(item.mod)
    write_log(fh, ("[probe:mappings] require('%s') = %s"):format(item.mod, tostring(ok)))

    if not ok then
      qf_items[#qf_items + 1] =
        make_qf_item(item.file, ('[mappings] failed to require %s: %s'):format(item.mod, tostring(result)))
    end
  end
end

local function check_plugin_specs(qf_items, fh)
  local file = fn.stdpath('config') .. '/lua/plugins/init.lua'
  local ok, plugins_mod = safe_require('plugins')

  write_log(fh, ("[probe:plugins] require('plugins') = %s"):format(tostring(ok)))

  if not ok then
    qf_items[#qf_items + 1] =
      make_qf_item(file, '[plugins] failed to require plugins module: ' .. tostring(plugins_mod))
    return
  end

  if type(plugins_mod.validate_specs) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[plugins] validate_specs() missing')
    return
  end

  local ok_validate, valid, errors = pcall(plugins_mod.validate_specs)
  if not ok_validate then
    qf_items[#qf_items + 1] = make_qf_item(file, '[plugins] validate_specs() crashed: ' .. tostring(valid))
    return
  end

  write_log(fh, ('[probe:plugins] validate_specs() = %s'):format(tostring(valid)))

  if not valid and type(errors) == 'table' then
    for _, err in ipairs(errors) do
      qf_items[#qf_items + 1] = make_qf_item(file, '[plugins] ' .. err)
    end
  end
end

local function syntaxcheck_all(lua_root, files, qf_items, fh)
  local ok_count = 0
  local err_count = 0

  for _, file in ipairs(files) do
    local mod = to_module(lua_root, file)
    local ok, err = syntaxcheck_file(file)

    if ok then
      ok_count = ok_count + 1
      write_log(fh, ('[syntax] OK: %s | %s'):format(mod, file))
    else
      err_count = err_count + 1
      local short_file = file:gsub('^' .. vim.pesc(lua_root) .. '/?', '')
      local lnum, msg = parse_lua_error(err)

      qf_items[#qf_items + 1] = make_qf_item(file, ('[syntax:%s] %s'):format(mod, msg or err), lnum or 1, 1)

      write_log(fh, ('[syntax] FAILED: %s | %s'):format(mod, short_file))
      write_log(fh, err)
      write_log(fh, string.rep('-', 80))
    end
  end

  return ok_count, err_count
end

local function check_modules_in_root(root, prefix, qf_items, fh, expect_table)
  if fn.isdirectory(root) == 0 then
    write_log(fh, ('[probe:%s] root missing: %s'):format(prefix, root))
    return
  end

  local files = collect_lua_files(root)
  for _, file in ipairs(files) do
    local mod = to_module(root, file)
    local full_mod = prefix .. '.' .. mod
    local ok, result = safe_require(full_mod)
    write_log(fh, ("[probe:%s] require('%s') = %s"):format(prefix, full_mod, tostring(ok)))
    if not ok then
      qf_items[#qf_items + 1] =
        make_qf_item(file, ('[%s] failed to require %s: %s'):format(prefix, full_mod, tostring(result)))
    elseif expect_table and type(result) ~= 'table' then
      qf_items[#qf_items + 1] = make_qf_item(file, ('[%s] %s did not return a table'):format(prefix, full_mod))
    end
  end
end

local function parse_luacheck_line(line)
  local file, lnum, col, code, msg = line:match('^([^:]+):(%d+):(%d+): %(([%w%d]+)%) (.+)$')
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      text = ('[luacheck:%s] %s'):format(code, msg),
    }
  end

  file, lnum, col, msg = line:match('^([^:]+):(%d+):(%d+): (.+)$')
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      text = '[luacheck] ' .. msg,
    }
  end
end
local function run_luacheck(paths, qf_items, fh)
  if fn.executable('luacheck') ~= 1 then
    write_log(fh, '[probe:luacheck] luacheck not found in PATH')
    return
  end
  local cmd = vim.list_extend({
    'luacheck',
    '--formatter',
    'plain',
    '--codes',
  }, paths)

  local result = vim.system(cmd, { text = true }):wait()

  write_log(fh, ('[probe:luacheck] exit_code=%s'):format(tostring(result.code)))

  local output = {}
  if result.stdout and result.stdout ~= '' then
    vim.list_extend(output, vim.split(result.stdout, '\n', { trimempty = true }))
  end
  if result.stderr and result.stderr ~= '' then
    vim.list_extend(output, vim.split(result.stderr, '\n', { trimempty = true }))
  end
  for _, line in ipairs(output) do
    write_log(fh, '[probe:luacheck] ' .. line)
    local item = parse_luacheck_line(line)
    if item then
      qf_items[#qf_items + 1] = item
    end
  end
end

local tiger_defaults = {
  active_handles = 80,
  autocmds = 500,
  buffer_mib = 32,
  config_file_kib = 256,
  hot_autocmds_per_event = 24,
  loaded_buffers = 80,
  loaded_modules = 450,
  lua_memory_mib = 128,
  rss_mib = 768,
  startup_source_self_ms = 8,
  startup_source_total_ms = 20,
  startup_total_ms = 250,
}

local tiger_severity_rank = {
  WARN = 1,
  INFO = 2,
}

local tiger_hot_events = {
  BufEnter = true,
  BufWinEnter = true,
  CursorMoved = true,
  CursorMovedI = true,
  DiagnosticChanged = true,
  InsertCharPre = true,
  LspAttach = true,
  TextChanged = true,
  TextChangedI = true,
  TextChangedP = true,
  WinResized = true,
  WinScrolled = true,
}

local tiger_static_rules = {
  {
    category = 'blocking-process',
    pattern = 'vim%.system%b()%s*:wait%s*%(',
    message = 'Synchronous vim.system(...):wait() blocks Neovim until the process exits',
    action = 'Prefer the vim.system() callback form in startup code and frequently triggered callbacks',
  },
  {
    category = 'blocking-process',
    pattern = 'fn%.system[%a_]*%s*%(',
    message = 'vim.fn.system()/systemlist() blocks Neovim until the process exits',
    action = 'Prefer vim.system(..., callback) unless synchronous execution is intentional',
  },
  {
    category = 'blocking-wait',
    pattern = 'vim%.wait%s*%(',
    message = 'vim.wait() blocks the caller while polling its condition',
    action = 'Prefer an event, callback, autocmd, or scheduled continuation on interactive paths',
  },
  {
    category = 'blocking-process',
    pattern = 'io%.popen%s*%(',
    message = "io.popen() performs blocking process I/O on Neovim's main thread",
    action = 'Prefer vim.system() with a callback for interactive work',
  },
  {
    category = 'blocking-process',
    pattern = 'os%.execute%s*%(',
    message = 'os.execute() blocks Neovim until the command exits',
    action = 'Prefer vim.system() with an argument vector and callback',
  },
  {
    category = 'full-buffer-read',
    pattern = 'nvim_buf_get_lines%([^,]+,%s*0,%s*-1',
    message = 'Full-buffer reads allocate a Lua copy of every line',
    action = 'Read only the required range, especially inside autocmd or redraw callbacks',
  },
}

local function tiger_thresholds()
  local overrides = type(vim.g.tigercheck_thresholds) == 'table' and vim.g.tigercheck_thresholds or {}
  return vim.tbl_deep_extend('force', {}, tiger_defaults, overrides)
end

local function add_tiger_finding(findings, severity, category, file, lnum, col, message, action)
  findings[#findings + 1] = {
    action = action,
    category = category,
    col = col or 1,
    file = file,
    lnum = lnum or 1,
    message = message,
    severity = severity,
  }
end

local function tiger_source_location(callback)
  if type(callback) ~= 'function' then
    return nil, nil
  end

  local ok, info = pcall(debug.getinfo, callback, 'S')
  if not ok or type(info) ~= 'table' or type(info.source) ~= 'string' then
    return nil, nil
  end

  local source = info.source
  if source:sub(1, 1) ~= '@' then
    return nil, nil
  end

  return source:sub(2), math.max(tonumber(info.linedefined) or 1, 1)
end

local function tiger_autocmd_location(autocmd)
  local file, lnum = tiger_source_location(autocmd.callback)
  if file then
    return file, lnum
  end

  return fn.stdpath('config') .. '/init.lua', 1
end

local function tiger_runtime_metrics(metrics, findings, thresholds)
  local config_file = fn.stdpath('config') .. '/init.lua'
  local loaded_buffers = 0
  local largest_buffer_bytes = 0
  local largest_buffer_file = config_file

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
      loaded_buffers = loaded_buffers + 1
      local line_count = api.nvim_buf_line_count(bufnr)
      local ok_offset, bytes = pcall(api.nvim_buf_get_offset, bufnr, line_count)
      if ok_offset and type(bytes) == 'number' and bytes > largest_buffer_bytes then
        largest_buffer_bytes = bytes
        local name = api.nvim_buf_get_name(bufnr)
        largest_buffer_file = name ~= '' and name or config_file
      end
    end
  end

  local module_count = 0
  for _ in pairs(package.loaded) do
    module_count = module_count + 1
  end

  local lua_memory_mib = collectgarbage('count') / 1024
  local ok_rss, rss_bytes = pcall(uv.resident_set_memory)
  local rss_mib = ok_rss and type(rss_bytes) == 'number' and rss_bytes / 1024 / 1024 or nil
  local handle_count = 0
  local active_handle_count = 0
  local handle_types = {}

  if type(uv.walk) == 'function' then
    uv.walk(function(handle)
      handle_count = handle_count + 1
      local handle_type = 'unknown'
      if type(uv.handle_get_type) == 'function' then
        local ok_type, value = pcall(uv.handle_get_type, handle)
        if ok_type and type(value) == 'string' then
          handle_type = value
        end
      end
      handle_types[handle_type] = (handle_types[handle_type] or 0) + 1

      local ok_active, active = pcall(function()
        return handle:is_active()
      end)
      if ok_active and active then
        active_handle_count = active_handle_count + 1
      end
    end)
  end

  metrics.active_handles = active_handle_count
  metrics.handle_count = handle_count
  metrics.handle_types = handle_types
  metrics.largest_buffer_mib = largest_buffer_bytes / 1024 / 1024
  metrics.loaded_buffers = loaded_buffers
  metrics.loaded_modules = module_count
  metrics.lua_memory_mib = lua_memory_mib
  metrics.rss_mib = rss_mib

  if lua_memory_mib >= thresholds.lua_memory_mib then
    add_tiger_finding(
      findings,
      'WARN',
      'lua-memory',
      config_file,
      1,
      1,
      ('Lua heap is %.1f MiB; threshold is %.1f MiB'):format(lua_memory_mib, thresholds.lua_memory_mib),
      'Inspect eagerly loaded modules, retained closures, caches, and large Lua tables'
    )
  end

  if rss_mib and rss_mib >= thresholds.rss_mib then
    add_tiger_finding(
      findings,
      'WARN',
      'resident-memory',
      config_file,
      1,
      1,
      ('Neovim RSS is %.1f MiB; threshold is %.1f MiB'):format(rss_mib, thresholds.rss_mib),
      'Compare a clean start, then disable eager plugins or large providers in groups to isolate growth'
    )
  end

  if loaded_buffers >= thresholds.loaded_buffers then
    add_tiger_finding(
      findings,
      'WARN',
      'buffers',
      config_file,
      1,
      1,
      ('%d loaded buffers exceed the threshold of %d'):format(loaded_buffers, thresholds.loaded_buffers),
      'Review hidden terminal, preview, scratch, and plugin buffers that are never deleted'
    )
  end

  local largest_buffer_mib = largest_buffer_bytes / 1024 / 1024
  if largest_buffer_mib >= thresholds.buffer_mib then
    add_tiger_finding(
      findings,
      'WARN',
      'large-buffer',
      largest_buffer_file,
      1,
      1,
      ('Loaded buffer is approximately %.1f MiB; threshold is %.1f MiB'):format(
        largest_buffer_mib,
        thresholds.buffer_mib
      ),
      'Avoid full-buffer Lua copies and disable expensive per-line features for very large files'
    )
  end

  if module_count >= thresholds.loaded_modules then
    add_tiger_finding(
      findings,
      'WARN',
      'eager-loading',
      config_file,
      1,
      1,
      ('%d loaded Lua modules exceed the threshold of %d'):format(module_count, thresholds.loaded_modules),
      'Compare package.loaded after a clean start and defer language- or filetype-specific modules'
    )
  end

  if active_handle_count >= thresholds.active_handles then
    add_tiger_finding(
      findings,
      'WARN',
      'event-loop',
      config_file,
      1,
      1,
      ('%d active libuv handles exceed the threshold of %d'):format(active_handle_count, thresholds.active_handles),
      'Review repeating timers, watchers, jobs, terminals, sockets, and handles not closed during teardown'
    )
  end
end

local function tiger_autocmd_metrics(metrics, findings, thresholds)
  local ok, autocmds = pcall(api.nvim_get_autocmds, {})
  if not ok or type(autocmds) ~= 'table' then
    add_tiger_finding(
      findings,
      'INFO',
      'autocmds',
      fn.stdpath('config') .. '/init.lua',
      1,
      1,
      'Could not inspect runtime autocommands: ' .. tostring(autocmds),
      'Run :checkhealth and confirm the current Neovim API is available'
    )
    return
  end

  metrics.autocmds = #autocmds
  local duplicate_groups = {}
  local event_counts = {}
  local event_locations = {}

  for _, autocmd in ipairs(autocmds) do
    local event = tostring(autocmd.event or '<unknown>')
    local pattern = tostring(autocmd.pattern or (autocmd.buflocal and '<buffer>' or '*'))
    local group = tostring(autocmd.group_name or autocmd.group or '<none>')
    local file, lnum = tiger_autocmd_location(autocmd)
    local handler

    if type(autocmd.callback) == 'function' then
      handler = ('%s:%d'):format(file, lnum)
    elseif autocmd.callback ~= nil then
      handler = tostring(autocmd.callback)
    else
      handler = tostring(autocmd.command or '')
    end

    local signature = table.concat({ event, pattern, group, handler }, '\31')
    duplicate_groups[signature] = duplicate_groups[signature]
      or {
        count = 0,
        event = event,
        file = file,
        lnum = lnum,
        pattern = pattern,
      }
    duplicate_groups[signature].count = duplicate_groups[signature].count + 1

    if tiger_hot_events[event] and not autocmd.buflocal and (pattern == '*' or pattern == '') then
      event_counts[event] = (event_counts[event] or 0) + 1
      event_locations[event] = event_locations[event] or {
        file = file,
        lnum = lnum,
      }
    end
  end

  if #autocmds >= thresholds.autocmds then
    add_tiger_finding(
      findings,
      'WARN',
      'autocmds',
      fn.stdpath('config') .. '/init.lua',
      1,
      1,
      ('%d runtime autocommands exceed the threshold of %d'):format(#autocmds, thresholds.autocmds),
      'Review duplicate setup calls and plugins that register handlers repeatedly'
    )
  end

  for _, duplicate in pairs(duplicate_groups) do
    if duplicate.count > 1 then
      add_tiger_finding(
        findings,
        'WARN',
        'duplicate-autocmd',
        duplicate.file,
        duplicate.lnum,
        1,
        ('Autocmd appears %d times: event=%s pattern=%s'):format(duplicate.count, duplicate.event, duplicate.pattern),
        'Ensure setup is idempotent and create the augroup with clear=true before re-registering handlers'
      )
    end
  end

  for event, count in pairs(event_counts) do
    if count >= thresholds.hot_autocmds_per_event then
      local location = event_locations[event]
      add_tiger_finding(
        findings,
        'WARN',
        'hot-autocmd',
        location.file,
        location.lnum,
        1,
        ('%d global %s handlers run on a high-frequency event'):format(count, event),
        'Make handlers buffer-local where possible and debounce expensive work'
      )
    end
  end
end

local function tiger_lsp_metrics(metrics, findings)
  if not vim.lsp or type(vim.lsp.get_clients) ~= 'function' then
    return
  end

  local clients = vim.lsp.get_clients()
  metrics.lsp_clients = #clients
  local groups = {}

  for _, client in ipairs(clients) do
    local root = type(client.config) == 'table' and client.config.root_dir or nil
    local key = ('%s\31%s'):format(tostring(client.name), tostring(root or '<none>'))
    groups[key] = groups[key]
      or {
        count = 0,
        name = tostring(client.name),
        root = tostring(root or '<none>'),
      }
    groups[key].count = groups[key].count + 1
  end

  for _, group in pairs(groups) do
    if group.count > 1 then
      local file = fn.stdpath('config') .. '/lsp/' .. group.name .. '.lua'
      add_tiger_finding(
        findings,
        'WARN',
        'duplicate-lsp',
        file,
        1,
        1,
        ('%d %s clients share root %s'):format(group.count, group.name, group.root),
        'Check for duplicate vim.lsp.enable() calls or overlapping filetype activation paths'
      )
    end
  end
end

local function tiger_static_scan(files, metrics, findings, thresholds)
  local scanned_bytes = 0
  local scanned_lines = 0

  for _, file in ipairs(files) do
    local file_bytes = 0
    local file_lines = 0
    local function_definitions = {}
    local input = io.open(file, 'r')
    if input then
      for line in input:lines() do
        file_lines = file_lines + 1
        file_bytes = file_bytes + #line + 1
        local trimmed = line:match('^%s*(.-)%s*$')
        if trimmed ~= '' and not trimmed:match('^%-%-') then
          for _, rule in ipairs(tiger_static_rules) do
            local first = line:find(rule.pattern)
            if first then
              add_tiger_finding(findings, 'WARN', rule.category, file, file_lines, first, rule.message, rule.action)
            end
          end

          local function_name = line:match('^%s*function%s+([%w_%.:]+)%s*%(')
            or line:match('^%s*local%s+function%s+([%w_]+)%s*%(')
            or line:match('^%s*([%w_%.:]+)%s*=%s*function%s*%(')
          if function_name then
            local previous = function_definitions[function_name]
            if previous then
              add_tiger_finding(
                findings,
                'WARN',
                'duplicate-function',
                file,
                file_lines,
                1,
                ('Function %s redefines the implementation from line %d'):format(function_name, previous),
                'Remove the duplicate or rename it; the later definition silently replaces the earlier one'
              )
            else
              function_definitions[function_name] = file_lines
            end
          end
        end
      end
      input:close()
    end

    scanned_bytes = scanned_bytes + file_bytes
    scanned_lines = scanned_lines + file_lines
    if file_bytes / 1024 >= thresholds.config_file_kib then
      add_tiger_finding(
        findings,
        'INFO',
        'large-config-module',
        file,
        1,
        1,
        ('Lua file is %.1f KiB across %d lines'):format(file_bytes / 1024, file_lines),
        'Split by responsibility only if this module is eagerly loaded or difficult to profile'
      )
    end
  end

  metrics.scanned_files = #files
  metrics.scanned_kib = scanned_bytes / 1024
  metrics.scanned_lines = scanned_lines
end

local function tiger_startup_metrics(startup_log, metrics, findings, thresholds)
  if not startup_log or startup_log == '' then
    add_tiger_finding(
      findings,
      'INFO',
      'startup',
      fn.stdpath('config') .. '/init.lua',
      1,
      1,
      'No --startuptime log was supplied; live runtime checks still completed',
      'Use the documented two-pass CLI command to include complete startup attribution'
    )
    return
  end

  startup_log = fn.fnamemodify(fn.expand(startup_log), ':p')
  if fn.filereadable(startup_log) ~= 1 then
    add_tiger_finding(
      findings,
      'WARN',
      'startup',
      startup_log,
      1,
      1,
      'Startup timing log is not readable',
      'Generate it with nvim --headless --startuptime <file> +qa'
    )
    return
  end

  local sessions = {}
  local current = {}
  local input = io.open(startup_log, 'r')
  if not input then
    return
  end

  for line in input:lines() do
    if line:find('times in msec', 1, true) then
      current = {}
      sessions[#sessions + 1] = current
    else
      current[#current + 1] = line
    end
  end
  input:close()

  local lines = sessions[#sessions] or current
  local sources = {}
  local startup_ms

  for _, line in ipairs(lines) do
    local clock, total_ms, self_ms, file = line:match('^%s*(%d+%.%d+)%s+(%d+%.%d+)%s+(%d+%.%d+):%s+sourcing%s+(.+)$')
    if file then
      local source = sources[file] or {
        count = 0,
        self_ms = 0,
        total_ms = 0,
      }
      source.count = source.count + 1
      source.self_ms = source.self_ms + (tonumber(self_ms) or 0)
      source.total_ms = source.total_ms + (tonumber(total_ms) or 0)
      sources[file] = source
      startup_ms = math.max(startup_ms or 0, tonumber(clock) or 0)
    end

    local started = line:match('^%s*(%d+%.%d+).+NVIM STARTED')
    if started then
      startup_ms = tonumber(started)
    end
  end

  metrics.startup_log = startup_log
  metrics.startup_ms = startup_ms

  if startup_ms and startup_ms >= thresholds.startup_total_ms then
    add_tiger_finding(
      findings,
      'WARN',
      'startup-total',
      fn.stdpath('config') .. '/init.lua',
      1,
      1,
      ('Startup took %.1f ms; threshold is %.1f ms'):format(startup_ms, thresholds.startup_total_ms),
      'Start with the slow source findings below, then compare against nvim --clean'
    )
  end

  for file, source in pairs(sources) do
    if source.self_ms >= thresholds.startup_source_self_ms or source.total_ms >= thresholds.startup_source_total_ms then
      add_tiger_finding(
        findings,
        'WARN',
        'startup-source',
        file,
        1,
        1,
        ('Startup source used %.2f ms self / %.2f ms including children across %d load(s)'):format(
          source.self_ms,
          source.total_ms,
          source.count
        ),
        'Inspect eager requires and setup work in this file; move filetype-specific work behind activation events'
      )
    end
  end
end

local function tiger_sort_findings(findings)
  table.sort(findings, function(left, right)
    local left_rank = tiger_severity_rank[left.severity] or 99
    local right_rank = tiger_severity_rank[right.severity] or 99
    if left_rank ~= right_rank then
      return left_rank < right_rank
    end
    if left.category ~= right.category then
      return left.category < right.category
    end
    if left.file ~= right.file then
      return left.file < right.file
    end
    if left.lnum ~= right.lnum then
      return left.lnum < right.lnum
    end
    return left.col < right.col
  end)
end

local function tiger_report_lines(metrics, findings, thresholds)
  local version = vim.version()
  local lines = {
    'Qompass AI Diver Tiger Performance Check',
    string.rep('=', 80),
    ('Generated: %s'):format(os.date('%Y-%m-%d %H:%M:%S')),
    ('Neovim: %d.%d.%d'):format(version.major, version.minor, version.patch),
    'Scope: snapshot and heuristic audit; findings identify investigation targets, not proof of causation.',
    '',
    'Runtime metrics',
    string.rep('-', 80),
    ('Lua heap: %.1f MiB (warn >= %.1f)'):format(metrics.lua_memory_mib or 0, thresholds.lua_memory_mib),
    ('RSS: %s (warn >= %.1f MiB)'):format(
      metrics.rss_mib and ('%.1f MiB'):format(metrics.rss_mib) or '<unavailable>',
      thresholds.rss_mib
    ),
    ('Loaded Lua modules: %d (warn >= %d)'):format(metrics.loaded_modules or 0, thresholds.loaded_modules),
    ('Loaded buffers: %d (warn >= %d)'):format(metrics.loaded_buffers or 0, thresholds.loaded_buffers),
    ('Largest loaded buffer: %.1f MiB (warn >= %.1f)'):format(metrics.largest_buffer_mib or 0, thresholds.buffer_mib),
    ('Autocommands: %d (warn >= %d)'):format(metrics.autocmds or 0, thresholds.autocmds),
    ('LSP clients: %d'):format(metrics.lsp_clients or 0),
    ('libuv handles: %d total / %d active (warn active >= %d)'):format(
      metrics.handle_count or 0,
      metrics.active_handles or 0,
      thresholds.active_handles
    ),
    ('Scanned config: %d files / %d lines / %.1f KiB'):format(
      metrics.scanned_files or 0,
      metrics.scanned_lines or 0,
      metrics.scanned_kib or 0
    ),
    ('Startup: %s'):format(metrics.startup_ms and ('%.1f ms'):format(metrics.startup_ms) or '<not measured>'),
    '',
    'Active handle types',
    string.rep('-', 80),
  }

  local handle_names = {}
  for name in pairs(metrics.handle_types or {}) do
    handle_names[#handle_names + 1] = name
  end
  table.sort(handle_names)
  if #handle_names == 0 then
    lines[#lines + 1] = '<none reported>'
  else
    for _, name in ipairs(handle_names) do
      lines[#lines + 1] = ('%-16s %d'):format(name, metrics.handle_types[name])
    end
  end

  lines[#lines + 1] = ''
  lines[#lines + 1] = ('Findings (%d)'):format(#findings)
  lines[#lines + 1] = string.rep('-', 80)
  if #findings == 0 then
    lines[#lines + 1] = 'No configured threshold was exceeded and no static hotspot matched.'
  else
    for _, finding in ipairs(findings) do
      lines[#lines + 1] = ('%s:%d:%d: [%s/%s] %s'):format(
        finding.file,
        finding.lnum,
        finding.col,
        finding.severity,
        finding.category,
        finding.message
      )
      if finding.action and finding.action ~= '' then
        lines[#lines + 1] = ('  action: %s'):format(finding.action)
      end
    end
  end

  lines[#lines + 1] = ''
  lines[#lines + 1] = 'Threshold overrides'
  lines[#lines + 1] = string.rep('-', 80)
  lines[#lines + 1] = 'Set vim.g.tigercheck_thresholds before running ConfigTigerCheck, for example:'
  lines[#lines + 1] = 'vim.g.tigercheck_thresholds = { startup_total_ms = 180, rss_mib = 512 }'
  return lines
end

local function tiger_write_report(report_path, lines)
  local output, err = io.open(report_path, 'w')
  if not output then
    return false, err
  end
  output:write(table.concat(lines, '\n'))
  output:write('\n')
  output:close()
  return true, nil
end

local function tiger_finish_qf(findings)
  local items = {}
  for _, finding in ipairs(findings) do
    local item_type = finding.severity == 'WARN' and 'W' or 'I'
    local text = ('[%s/%s] %s'):format(finding.severity, finding.category, finding.message)
    if finding.action and finding.action ~= '' then
      text = text .. ' | action: ' .. finding.action
    end
    items[#items + 1] = make_qf_item(finding.file, text, finding.lnum, finding.col, item_type)
  end

  fn.setqflist({}, 'r', {
    title = 'ConfigTigerCheck',
    items = items,
  })
  if #api.nvim_list_uis() > 0 then
    vim.cmd('copen')
  end
end

local function runtimecheck(qf_items, fh)
  write_log(fh, '')
  write_log(fh, '[runtime] starting targeted probes')
  write_log(fh, string.rep('=', 80))
  check_lazy_state(qf_items, fh)
  check_pack_state(qf_items, fh)
  check_lualine_state(qf_items, fh)
  check_luarocks_state(qf_items, fh)
  check_lsp_state(qf_items, fh)
  check_mapping_modules(qf_items, fh)
  check_plugin_specs(qf_items, fh)
  check_modules_in_root(fn.stdpath('config') .. '/lsp', 'lsp', qf_items, fh, true)
  run_luacheck({
    fn.stdpath('config') .. '/lua',
    fn.stdpath('config') .. '/lsp',
  }, qf_items, fh)
end

local function finish_qf(qf_items)
  if #qf_items > 0 then
    fn.setqflist({}, 'r', {
      title = 'ConfigSelfCheck',
      items = qf_items,
    })
    vim.cmd('copen')
  else
    fn.setqflist({}, 'r', {
      title = 'ConfigSelfCheck',
      items = {},
    })
  end
end

function M.buffer_diagnostics(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  vim.diagnostic.setloclist({
    open = false,
    title = 'Buffer Diagnostics',
  })
  vim.cmd('lopen')
end
function M.workspace_diagnostics()
  vim.diagnostic.setqflist({
    open = true,
    title = 'Workspace Diagnostics',
  })
end
--- @param bufnr? integer
function M.buffer_diagnostics(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  vim.diagnostic.setloclist({
    open = false,
    title = 'Buffer Diagnostics',
  })
  vim.cmd('lopen')
end
function M.document_symbols()
  vim.lsp.buf.document_symbol()
end
function M.workspace_symbols()
  vim.ui.input({
    prompt = 'Workspace symbols query: ',
  }, function(query)
    if not query or query == '' then
      return
    end
    vim.lsp.buf.workspace_symbol(query)
  end)
end
function M.toggle_quickfix()
  for _, win in ipairs(api.nvim_list_wins()) do
    local info = fn.getwininfo(api.nvim_win_get_number(win))[1]
    if info and info.quickfix == 1 and info.loclist == 0 then
      vim.cmd('cclose')
      return
    end
  end
  vim.cmd('copen')
end
function M.toggle_loclist()
  local wins = fn.getwininfo()
  local current = api.nvim_get_current_win()
  for _, win in ipairs(wins) do
    if win.winid == current and win.loclist == 1 then
      vim.cmd('lclose')
      return
    end
  end
  vim.cmd('lopen')
end
function M.enable_workspace_diagnostics_handler()
  vim.diagnostic.handlers.qompass_qf = {
    show = function(_, _, _, _)
      vim.schedule(function()
        vim.diagnostic.setqflist({
          open = false,
          title = 'Workspace Diagnostics',
        })
      end)
    end,
    hide = function()
      vim.schedule(function()
        fn.setqflist({}, 'r', { title = 'Workspace Diagnostics', items = {} })
      end)
    end,
  }
  notify('Enabled native workspace diagnostics quickfix handler', levels.INFO)
end
function M.disable_workspace_diagnostics_handler()
  vim.diagnostic.handlers.qompass_qf = nil
  notify('Disabled native workspace diagnostics quickfix handler', levels.INFO)
end
function M.selfcheck()
  local lua_root = fn.stdpath('config') .. '/lua'
  local files = collect_lua_files(lua_root)
  local qf_items = {}
  local state_dir = fn.stdpath('state')
  fn.mkdir(state_dir, 'p')
  local log_path = state_dir .. '/selfcheck.log'
  local fh = io.open(log_path, 'w')
  write_log(fh, ('[selfcheck] %s'):format(os.date('%Y-%m-%d %H:%M:%S')))
  write_log(fh, ('[selfcheck] lua_root=%s'):format(lua_root))
  write_log(fh, ('[selfcheck] state_dir=%s'):format(state_dir))
  write_log(fh, ('[selfcheck] log_path=%s'):format(log_path))
  write_log(fh, '')
  local syntax_ok, syntax_err = syntaxcheck_all(lua_root, files, qf_items, fh)
  runtimecheck(qf_items, fh)
  finish_qf(qf_items)
  local runtime_err = math.max(#qf_items - syntax_err, 0)
  local summary = ('[selfcheck] syntax: %d OK, %d FAILED | runtime issues: %d | log: %s'):format(
    syntax_ok,
    syntax_err,
    runtime_err,
    log_path
  )
  notify(summary, #qf_items == 0 and levels.INFO or levels.ERROR)
  write_log(fh, '')
  write_log(fh, ('[selfcheck] syntax_ok=%d syntax_err=%d runtime_issues=%d'):format(syntax_ok, syntax_err, runtime_err))
  if fh then
    fh:close()
  end
end
function M.syntaxcheck()
  local lua_root = fn.stdpath('config') .. '/lua'
  local files = collect_lua_files(lua_root)
  local qf_items = {}
  local state_dir = fn.stdpath('state')
  fn.mkdir(state_dir, 'p')
  local log_path = state_dir .. '/selfcheck.log'
  local fh = io.open(log_path, 'w')
  write_log(fh, ('[syntaxcheck] %s'):format(os.date('%Y-%m-%d %H:%M:%S')))
  write_log(fh, ('[syntaxcheck] lua_root=%s'):format(lua_root))
  write_log(fh, '')
  local syntax_ok, syntax_err = syntaxcheck_all(lua_root, files, qf_items, fh)
  finish_qf(qf_items)
  local summary = ('[syntaxcheck] %d OK, %d FAILED | log: %s'):format(syntax_ok, syntax_err, log_path)
  notify(summary, syntax_err == 0 and levels.INFO or levels.ERROR)
  write_log(fh, '')
  write_log(fh, ('[syntaxcheck] syntax_ok=%d syntax_err=%d'):format(syntax_ok, syntax_err))
  if fh then
    fh:close()
  end
end
function M.tigercheck(startup_log)
  local config_root = fn.stdpath('config')
  local files = collect_lua_files(config_root .. '/lua')
  local lsp_root = config_root .. '/lsp'
  if fn.isdirectory(lsp_root) == 1 then
    vim.list_extend(files, collect_lua_files(lsp_root))
  end

  local init_file = config_root .. '/init.lua'
  if fn.filereadable(init_file) == 1 then
    files[#files + 1] = init_file
  end
  table.sort(files)

  local thresholds = tiger_thresholds()
  local findings = {}
  local metrics = {}
  tiger_runtime_metrics(metrics, findings, thresholds)
  tiger_autocmd_metrics(metrics, findings, thresholds)
  tiger_lsp_metrics(metrics, findings)
  tiger_static_scan(files, metrics, findings, thresholds)
  tiger_startup_metrics(startup_log, metrics, findings, thresholds)
  tiger_sort_findings(findings)

  local state_dir = fn.stdpath('state')
  fn.mkdir(state_dir, 'p')
  local report_path = state_dir .. '/tigercheck.log'
  local lines = tiger_report_lines(metrics, findings, thresholds)
  local ok_report, report_err = tiger_write_report(report_path, lines)
  if not ok_report then
    add_tiger_finding(
      findings,
      'WARN',
      'report',
      init_file,
      1,
      1,
      'Could not write Tiger report: ' .. tostring(report_err),
      'Check permissions for stdpath("state")'
    )
    tiger_sort_findings(findings)
    lines = tiger_report_lines(metrics, findings, thresholds)
  end

  tiger_finish_qf(findings)
  local has_warning = false
  for _, finding in ipairs(findings) do
    if finding.severity == 'WARN' then
      has_warning = true
      break
    end
  end

  if #api.nvim_list_uis() == 0 then
    api.nvim_echo({
      { table.concat(lines, '\n') .. '\n' },
    }, false, {})
  else
    notify(
      ('Tiger check: %d finding(s) | report: %s'):format(#findings, report_path),
      has_warning and levels.WARN or levels.INFO
    )
  end
end
M.run = M.selfcheck
api.nvim_create_user_command('ConfigSelfCheck', M.selfcheck, {
  desc = 'Syntax-check all Lua config files and run safe runtime probes',
})
api.nvim_create_user_command('ConfigSyntaxCheck', M.syntaxcheck, {
  desc = 'Syntax-check all Lua config files without requiring modules',
})
api.nvim_create_user_command('ConfigSelfCheckLog', function()
  vim.cmd(('edit %s'):format(fn.fnameescape(fn.stdpath('state') .. '/selfcheck.log')))
end, {
  desc = 'Open the ConfigSelfCheck log file',
})
-- Interactive: :ConfigTigerCheck[ startup-log]
-- Complete CLI startup audit:
-- tiger_startup_log="$(mktemp --suffix=.nvim-startup.log)" || exit 1
-- trap 'rm -f -- "$tiger_startup_log"' EXIT
-- nvim --headless --startuptime "$tiger_startup_log" '+qa'
-- nvim --headless "+ConfigTigerCheck $tiger_startup_log" '+qa'
api.nvim_create_user_command('ConfigTigerCheck', function(opts)
  M.tigercheck(opts.args ~= '' and opts.args or nil)
end, {
  complete = 'file',
  desc = 'Audit startup, memory, event-loop, LSP, autocmd, and static performance hotspots',
  nargs = '?',
})
api.nvim_create_user_command('ConfigTigerCheckLog', function()
  vim.cmd(('edit %s'):format(fn.fnameescape(fn.stdpath('state') .. '/tigercheck.log')))
end, {
  desc = 'Open the ConfigTigerCheck human-readable report',
})
api.nvim_create_user_command('DiagnosticsWorkspace', M.workspace_diagnostics, {
  desc = 'Populate quickfix with workspace diagnostics',
})
api.nvim_create_user_command('DiagnosticsBuffer', function()
  M.buffer_diagnostics(api.nvim_get_current_buf())
end, {
  desc = 'Populate location list with current-buffer diagnostics',
})
api.nvim_create_user_command('DiagnosticsToggleQuickfix', M.toggle_quickfix, {
  desc = 'Toggle quickfix window',
})
api.nvim_create_user_command('DiagnosticsToggleLoclist', M.toggle_loclist, {
  desc = 'Toggle location list window',
})
api.nvim_create_user_command('LspDocumentSymbols', M.document_symbols, {
  desc = 'Show document symbols with native LSP',
})

api.nvim_create_user_command('LspWorkspaceSymbols', M.workspace_symbols, {
  desc = 'Search workspace symbols with native LSP',
})

api.nvim_create_user_command('DiagnosticsEnableWorkspaceHandler', M.enable_workspace_diagnostics_handler, {
  desc = 'Enable native quickfix sync for workspace diagnostics',
})

api.nvim_create_user_command('DiagnosticsDisableWorkspaceHandler', M.disable_workspace_diagnostics_handler, {
  desc = 'Disable native quickfix sync for workspace diagnostics',
})

api.nvim_create_autocmd('BufReadPost', {
  group = ddx_group,
  pattern = '*',
  callback = function(args)
    if vim.bo[args.buf].filetype == 'nvimpager' then
      strip_ansi(args.buf)
    end
  end,
})

return M