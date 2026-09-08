#!/usr/bin/env lua
-- /qompassai/Diver/lua/utils/blue/sops.lua
-- Qompass AI Secret Operations (SOPs) Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local buf = vim.api.nvim_get_current_buf
local execmd = vim.api.nvim_exec_autocmds
local fn = vim.fn
local fs = vim.fs
local notify = vim.notify
local get_opts = vim.api.nvim_get_option_value
local set_opts = vim.api.nvim_set_option_value
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local DEFAULT_SUPPORTED_FILE_FORMATS = {
  '*.yaml',
  '*.yml',
  '*.json',
  '*.dockerconfigjson',
}

local SOPS_MARKER_BYTES = {
  ['yaml'] = 'mac: ENC[',
  ['yaml.helm-values'] = 'mac: ENC[',
  ['json'] = '"mac": "ENC[',
}

M.config = {
  supported_file_formats = vim.deepcopy(DEFAULT_SUPPORTED_FILE_FORMATS),
  sops_binary = 'sops',
  notify_on_unmodified_write = true,
}

M._augroup = nil

local function dedupe_list(items)
  local seen = {}
  local result = {}

  for _, item in ipairs(items or {}) do
    if type(item) == 'string' and item ~= '' and not seen[item] then
      seen[item] = true
      table.insert(result, item)
    end
  end

  return result
end

local function get_supported_patterns()
  return dedupe_list(M.config.supported_file_formats)
end

local function sops_decrypt_buffer(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local cwd = fs.dirname(path)
  local filetype = get_opts('filetype', { buf = bufnr })

  vim.system({
    M.config.sops_binary,
    '--decrypt',
    '--input-type',
    filetype,
    '--output-type',
    filetype,
    path,
  }, { cwd = cwd, text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        notify('Failed to decrypt file', WARN)
        return
      end

      local decrypted_lines = fn.split(out.stdout, '\n', false)

      set_opts('buftype', 'acwrite', { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, decrypted_lines)

      local old_undo_levels = get_opts('undolevels', { buf = bufnr })
      set_opts('undolevels', -1, { buf = bufnr })
      vim.cmd('exe "normal a \\<BS>\\<Esc>"')
      set_opts('undolevels', old_undo_levels, { buf = bufnr })

      set_opts('modified', false, { buf = bufnr })

      execmd('BufReadPost', {
        buffer = bufnr,
        modeline = false,
      })
    end)
  end)
end

local function sops_encrypt_buffer(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local cwd = fs.dirname(path)
  local plugin_root = fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'):sub(1, -4)
  local editor_script = fs.joinpath(plugin_root, 'scripts', 'sops-editor.sh')

  if fn.filereadable(editor_script) == 0 then
    notify('SOPS editor script not found: ' .. editor_script, WARN)
    return
  end

  local temp_file = fn.tempname()

  local function cleanup()
    fn.delete(temp_file)
  end

  local plaintext_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local success = fn.writefile(plaintext_lines, temp_file) == 0

  if not success then
    cleanup()
    notify('Failed to write temp file', WARN)
    return
  end

  vim.system({
    M.config.sops_binary,
    'edit',
    path,
  }, {
    cwd = cwd,
    env = {
      SOPS_EDITOR = editor_script,
      SOPS_NVIM_TEMP_FILE = temp_file,
    },
    text = true,
  }, function(out)
    vim.schedule(function()
      cleanup()

      if out.code ~= 0 then
        notify('SOPS failed to edit file: ' .. (out.stderr or ''), WARN)
        return
      end

      set_opts('modified', false, { buf = bufnr })

      execmd('BufReadPost', {
        buffer = bufnr,
        modeline = false,
      })
    end)
  end)
end

function M.is_sops_encrypted(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local filetype = get_opts('filetype', { buf = bufnr })
  local marker = SOPS_MARKER_BYTES[filetype]

  if not marker then
    return false
  end

  for _, line in ipairs(lines) do
    if string.find(line, marker, nil, true) then
      return true
    end
  end

  return false
end

function M.setup(opts)
  opts = opts or {}

  M.config = vim.tbl_deep_extend('force', M.config, opts)

  if opts.supported_file_formats then
    M.config.supported_file_formats =
      dedupe_list(vim.list_extend(vim.deepcopy(DEFAULT_SUPPORTED_FILE_FORMATS), opts.supported_file_formats))
  else
    M.config.supported_file_formats = dedupe_list(M.config.supported_file_formats)
  end

  if M._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M._augroup)
  end

  M._augroup = augroup('QompassBlueSops', { clear = true })

  autocmd({ 'BufReadPost', 'FileReadPost' }, {
    group = M._augroup,
    pattern = get_supported_patterns(),
    callback = function()
      local bufnr = buf()

      if not M.is_sops_encrypted(bufnr) then
        return
      end

      local buffer_group = augroup('QompassBlueSopsBuffer' .. bufnr, { clear = true })

      autocmd('BufDelete', {
        buffer = bufnr,
        group = buffer_group,
        callback = function()
          vim.api.nvim_clear_autocmds({
            buffer = bufnr,
            group = buffer_group,
          })
        end,
      })

      autocmd('BufWriteCmd', {
        buffer = bufnr,
        group = buffer_group,
        callback = function()
          if not get_opts('modified', { buf = bufnr }) then
            if M.config.notify_on_unmodified_write then
              notify('Skipping sops encryption. File has not been modified', INFO)
            end
            return
          end

          sops_encrypt_buffer(bufnr)
        end,
      })

      sops_decrypt_buffer(bufnr)
    end,
  })

  return M
end

return M