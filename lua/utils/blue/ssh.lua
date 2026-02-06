#!/usr/bin/env lua
-- /qompassai/Diver/lua/utils/blue/ssh.lua
-- Qompass AI Diver Blueteam SSH Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local ERROR = vim.log.levels.ERROR
local function create_class(name)
  local cls = {}
  cls.__index = cls
  cls.name = name
  function cls:new(...)
    local instance = setmetatable({}, self)
    if instance.init then
      instance:init(...)
    end
    return instance
  end

  function cls:subclass(subname)
    local subcls = create_class(subname)
    subcls.super = self
    setmetatable(subcls, { __index = self })
    return subcls
  end

  return cls
end
local function get_logger()
  return {
    error = function(msg)
      vim.notify('[SSH] ' .. msg, ERROR)
    end,
    fmt_error = function(fmt, ...)
      vim.notify('[SSH] ' .. fmt:format(...), ERROR)
    end,
  }
end
local function matches_host_name_pattern(hostname, pattern)
  local lua_pattern = pattern:gsub('%.', '%%.'):gsub('%*', '.*'):gsub('%?', '.')
  return hostname:match('^' .. lua_pattern .. '$') ~= nil
end
local function hostname_contains_wildcard(hostname)
  return hostname:match('[*?]') ~= nil
end
local function process_line(line)
  if not line or line:match('^%s*#') or line:match('^%s*$') then
    return nil, nil
  end
  local key, value = line:match('^%s*(%S+)%s+(.*)$')
  if key and value then
    value = value:gsub('%s+$', '')
    return key, value
  end
  return nil, nil
end
local SSHConfigParser = create_class('SSHConfigParser')
function SSHConfigParser:init()
  self.global_options = {}
  self.config = {}
  self.current_hosts = nil
  self.known_hosts = {}
  self.in_match_block = false
  self.logger = get_logger()
end

function SSHConfigParser:process_directive(key, value, source_file)
  if key == 'Host' then
    self.current_hosts = vim.split(value, '%s+')
    self.in_match_block = false
    for _, current_host in ipairs(self.current_hosts) do
      local apply_chain = { self.global_options }
      local post_process_hosts = {}
      for _, known_host in ipairs(self.known_hosts) do
        if matches_host_name_pattern(current_host, known_host) then
          table.insert(apply_chain, (self.config[known_host] or {}).parsed_config or {})
          table.insert(post_process_hosts, known_host)
        end
        if matches_host_name_pattern(known_host, current_host) and self.config[known_host] ~= nil then
          table.insert(self.config[known_host].post_process_from_hosts, current_host)
        end
      end
      table.insert(self.known_hosts, current_host)
      self.config[current_host] = {
        source_file = source_file,
        post_process_from_hosts = post_process_hosts,
        parsed_config = vim.tbl_extend(
          'keep',
          (self.config[current_host] or {}).parsed_config or {},
          unpack(apply_chain)
        ),
      }
    end
  elseif key == 'Match' then
    self.in_match_block = true
  elseif key == 'Include' then
    self.in_match_block = false
    self:parse_config_file(value, source_file)
  elseif self.current_hosts == nil then
    self.global_options[key] = value
  else
    if not self.in_match_block then
      for _, current_host in ipairs(self.current_hosts) do
        self.config[current_host].parsed_config[key] = self.config[current_host].parsed_config[key] or value
      end
    end
  end
  self:_post_process_all_configs()
end

function SSHConfigParser:_process_line(line, source)
  local directive, directive_value = process_line(line)
  if directive_value ~= nil and directive ~= nil then
    self:process_directive(directive, directive_value, source)
  end
end

function SSHConfigParser:parse_config_string(raw_string)
  local lines = vim.split(raw_string, '\n', { plain = true })
  for _, line in ipairs(lines) do
    self:_process_line(line, 'LITERAL_STRING')
  end
  self:_post_process_all_configs()
  return self
end

function SSHConfigParser:_post_process_all_configs()
  local config
  for _, host_name in ipairs(self.known_hosts) do
    config = self.config[host_name]
    for _, matched_host in ipairs(config.post_process_from_hosts) do
      self.config[host_name].parsed_config =
          vim.tbl_extend('keep', self.config[host_name].parsed_config, self.config[matched_host].parsed_config)
    end
  end
end

function SSHConfigParser:_expand_path(path, parent_file)
  local parent_dir = parent_file and vim.fs.dirname(parent_file)
  if parent_dir then
    parent_dir = vim.fs.normalize(parent_dir)
  end
  local cmd = { 'sh', '-c', ('echo %s'):format(path) }
  local cmd_output = ''
  if vim.fn.has('nvim-0.10') == 1 then
    local res = vim.system(cmd, { text = true, cwd = parent_dir }):wait()
    cmd_output = res.code == 0 and res.stdout or ''
  else
    local lines = {}
    local job_id = vim.fn.jobstart(cmd, {
      cwd = parent_dir,
      on_stdout = function(_, data)
        local str = table.concat(data, ''):gsub('\r\n', '\n'):gsub('\n', '')
        table.insert(lines, str)
      end,
      stdout_buffered = true,
    })
    vim.fn.jobwait({ job_id })
    cmd_output = table.concat(lines, ' ')
  end
  return vim.split(cmd_output, '%s+', { trimempty = true })
end

function SSHConfigParser:parse_config_file(file_path, parent_file)
  local expanded_paths = self:_expand_path(file_path, parent_file)
  for _, path in ipairs(expanded_paths) do
    self:_parse_config_file(path)
  end
  return self
end

function SSHConfigParser:_parse_config_file(file_path)
  file_path = vim.fn.expand(file_path)
  if type(file_path) == 'table' then
    file_path = file_path[1]
  end
  for line in io.lines(file_path) do
    self:_process_line(line, file_path)
  end
  self:_post_process_all_configs()
  return self
end

function SSHConfigParser:get_config()
  local config = {}
  for host_name, ssh_config in pairs(self.config) do
    if not hostname_contains_wildcard(host_name) then
      config[host_name] = ssh_config
    end
  end
  return config
end

local SSHExecutor = create_class('SSHExecutor')
function SSHExecutor:init(host, conn_opts, config)
  self.host = host
  self.conn_opts = conn_opts or ''
  self.ssh_conn_opts = self.conn_opts
  self.scp_conn_opts = self.conn_opts == '' and '-r' or self.conn_opts:gsub('%-p', '-P') .. ' -r'
  config = config or {}
  self.ssh_binary = config.ssh_binary or 'ssh'
  self.scp_binary = config.scp_binary or 'scp'
  self._job_id = nil
  self._job_stdout = {}
  self._job_exit_code = nil
end

function SSHExecutor:_build_run_command(command, additional_opts)
  local conn_opts = additional_opts and (self.ssh_conn_opts .. ' ' .. additional_opts) or self.ssh_conn_opts
  local host_conn_opts = conn_opts == '' and self.host or conn_opts .. ' ' .. self.host
  return ('%s %s %s'):format(self.ssh_binary, host_conn_opts, vim.fn.shellescape(command))
end

function SSHExecutor:run_command(command, opts)
  opts = opts or {}
  local full_cmd = self:_build_run_command(command, opts.additional_conn_opts)
  self._job_stdout = {}
  self._job_id = vim.fn.jobstart(full_cmd, {
    on_stdout = function(_, data)
      vim.list_extend(self._job_stdout, data)
      if opts.on_stdout then
        opts.on_stdout(data)
      end
    end,
    on_exit = function(_, code)
      self._job_exit_code = code
      if opts.on_exit then
        opts.on_exit(code)
      end
    end,
  })
  return self._job_id
end

function SSHExecutor:upload(local_path, remote_path, opts)
  opts = opts or {}
  local remote_full = ('%s:%s'):format(self.host, remote_path)
  local scp_command = ('%s %s %s %s'):format(self.scp_binary, self.scp_conn_opts, local_path, remote_full)
  return vim.fn.system(scp_command)
end

function SSHExecutor:download(remote_path, local_path, opts)
  opts = opts or {}
  local remote_full = ('%s:%s'):format(self.host, remote_path)
  local scp_command = ('%s %s %s %s'):format(self.scp_binary, self.scp_conn_opts, remote_full, local_path)
  return vim.fn.system(scp_command)
end

M.SSHConfigParser = SSHConfigParser
M.SSHExecutor = SSHExecutor
return M