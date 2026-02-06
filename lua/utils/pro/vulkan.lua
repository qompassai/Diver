-- vulkan.lua
-- Qompass AI Diver Vulkan Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local api = vim.api
local ERROR = vim.log.levels.ERROR
local insert = table.insert
local WARN = vim.log.levels.WARN
local function create_scratch(title, lines, ft)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  if ft then
    vim.bo[buf].filetype = ft
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.cmd('botright split')
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.cmd('file ' .. title)
end
local function run_cmd(cmd)
  local handle = io.popen(cmd .. ' 2>/dev/null')
  if not handle then
    return nil, 'failed to spawn: ' .. cmd
  end
  local out = handle:read('*a') or ''
  handle:close()
  local lines = {}
  for line in out:gmatch('[^\n]+') do
    table.insert(lines, line)
  end
  return lines, nil
end
local function parse_layers(lines)
  local layers = {}
  for _, line in ipairs(lines or {}) do
    for token in line:gmatch('VK_LAYER[%w_%.]+') do
      layers[token] = true
    end
  end
  local list = {}
  for name in pairs(layers) do
    table.insert(list, name)
  end
  table.sort(list)
  return list
end
function M.show_layers()
  local lines, err = run_cmd([[vulkaninfo 2>/dev/null | grep -i 'VK_LAYER_']])
  if err then
    vim.notify('[vulkan-layers] ' .. err .. ' (is vulkaninfo installed?)', ERROR)
    return
  end
  if #lines == 0 then
    vim.notify('[vulkan-layers] no VK_LAYER_* lines from vulkaninfo', WARN)
  end
  local layer_list = parse_layers(lines)
  local buf_lines = {}
  table.insert(buf_lines, '# Vulkan validation / instance layers')
  table.insert(buf_lines, '')
  if #layer_list == 0 then
    table.insert(buf_lines, 'No VK_LAYER_* entries detected.')
  else
    for _, name in ipairs(layer_list) do
      table.insert(buf_lines, '- ' .. name)
    end
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'markdown'
  api.nvim_buf_set_lines(buf, 0, -1, false, buf_lines)
  vim.cmd('botright split')
  api.nvim_win_set_buf(0, buf)
end

function M.status()
  local lines, err = run_cmd([[vulkaninfo 2>/dev/null | grep -i 'VK_LAYER_']])
  if err then
    vim.notify('[vulkan-layers] ' .. err, ERROR)
    return
  end
  local available = table.concat(lines or {}, '\n'):match('VK_LAYER_KHRONOS_validation') ~= nil
  if available then
    vim.notify('[vulkan-layers] VK_LAYER_KHRONOS_validation AVAILABLE', vim.log.levels.INFO)
  else
    vim.notify('[vulkan-layers] VK_LAYER_KHRONOS_validation NOT FOUND (check SDK / driver install)', WARN)
  end
end

function M.run_with_validation(cmd)
  if not cmd or cmd == '' then
    vim.notify('[vulkan-layers] provide a command, e.g. :VulkanRun ./app', vim.log.levels.WARN)
    return
  end
  local full = string.format('VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_PATH=$VK_LAYER_PATH %s', cmd)
  vim.cmd('botright split')
  vim.cmd('terminal ' .. full)
end

---@return table
local function parse_layers_from_vulkaninfo(lines) ---@param lines table|nil
  if not lines then
    return {}
  end
  local layers = {}
  for _, line in ipairs(lines) do
    for token in line:gmatch('VK_LAYER[%w_%.]+') do
      layers[token] = true
    end
  end
  local list = {}
  for name in pairs(layers) do
    table.insert(list, name)
  end
  table.sort(list)
  return list
end
function M.vulkan_layers_list()
  local lines, err = run_cmd('vulkaninfo 2>/dev/null | grep -i \'VK_LAYER_\'')
  if err then
    vim.notify('[vk-gpu] ' .. err .. ' (is vulkaninfo installed?)', ERROR)
    return
  end
  local layer_list = parse_layers_from_vulkaninfo(lines)
  local buf_lines = {}
  insert(buf_lines, '# Vulkan validation / instance layers')
  table.insert(buf_lines, '')
  if #layer_list == 0 then
    insert(buf_lines, 'No VK_LAYER_* entries detected.')
  else
    for _, name in ipairs(layer_list) do
      insert(buf_lines, '- ' .. name)
    end
  end
  create_scratch('VulkanLayers', buf_lines, 'markdown')
end

function M.vulkan_validation_status()
  local lines, err = run_cmd('vulkaninfo 2>/dev/null | grep -i \'VK_LAYER_\'')
  if err or not lines then   -- Add nil check for lines
    vim.notify('[vk-gpu] ' .. (err or 'no output'), vim.log.levels.ERROR)
    return
  end
  local blob = table.concat(lines, '')
  local has_khronos = blob:match('VK_LAYER_KHRONOS_validation') ~= nil
  if has_khronos then
    vim.notify('[vk-gpu] VK_LAYER_KHRONOS_validation AVAILABLE', vim.log.levels.INFO)
  else
    vim.notify('[vk-gpu] VK_LAYER_KHRONOS_validation NOT FOUND (check SDK / drivers)', WARN)
  end
end

function M.vulkan_run_with_validation(cmd)
  if not cmd or cmd == '' then
    vim.notify('[vk-gpu] provide a command, e.g. :VulkanRunWithValidation ./app', vim.log.levels.WARN)
    return
  end
  local full = string.format('VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation VK_LAYER_PATH=$VK_LAYER_PATH %s', cmd)

  vim.cmd('botright split')
  vim.cmd('terminal ' .. full)
end

local function nvidia_smi_query(fields)
  local field_str = table.concat(fields, ',')
  local cmd = string.format('nvidia-smi --query-gpu=%s --format=csv,noheader,nounits', field_str)
  local lines, err = run_cmd(cmd)
  return lines, err
end
function M.nvidia_summary()
  local fields = {
    'index',
    'name',
    'driver_version',
    'temperature.gpu',
    'power.draw',
    'power.limit',
    'utilization.gpu',
    'memory.used',
    'memory.total',
    'compute_mode',
  }
  local lines, err = nvidia_smi_query(fields)
  if err or not lines then
    vim.notify('[vk-gpu] ' .. (err or 'no output') .. ' (is nvidia-smi available?)', ERROR)
    return
  end
  if #lines == 0 then
    vim.notify('[vk-gpu] no GPUs reported by nvidia-smi', WARN)
    return
  end
  local header = {
    '# NVIDIA GPU summary (nvidia-smi)',
    '',
    '| idx | name | driver | temp C | power W | limit W | util %% | mem used | mem total | compute_mode |',
    '|-----|------|--------|--------|---------|---------|--------|----------|-----------|--------------|',
  }
  local rows = {}
  for _, line in ipairs(lines) do
    local cols = {}
    for col in line:gmatch('([^,]+)') do
      insert(cols, vim.trim(col))
    end
    insert(
      rows,
      string.format(
        '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |',
        cols[1] or '?',         -- index
        cols[2] or '?',         -- name
        cols[3] or '?',         -- driver_version
        cols[4] or '?',         -- temp
        cols[5] or '?',         -- power.draw
        cols[6] or '?',         -- power.limit
        cols[7] or '?',         -- util.gpu
        cols[8] or '?',         -- mem.used
        cols[9] or '?',         -- mem.total
        cols[10] or '?'         -- compute_mode
      )
    )
  end
  local buf_lines = {}
  vim.list_extend(buf_lines, header)
  vim.list_extend(buf_lines, rows)
  create_scratch('NvidiaSummary', buf_lines, 'markdown')
end

function M.nvidia_watch(interval)
  interval = tonumber(interval) or 1
  local cmd = string.format('watch -n %d nvidia-smi', interval)
  vim.cmd('botright split')
  vim.cmd('terminal ' .. cmd)
end

function M.dashboard()
  local vk_lines, vk_err = run_cmd('vulkaninfo --summary 2>/dev/null | head -n 20')
  local smi_lines, smi_err = nvidia_smi_query({ 'index', 'name', 'driver_version' })
  local out = {}
  insert(out, '# Vulkan + NVIDIA status')
  insert(out, '')
  table.insert(out, '## Vulkan (vulkaninfo --summary)')
  if vk_err or not vk_lines then
    insert(out, '')
    insert(out, '> vulkaninfo error: ' .. (vk_err or 'no output'))
  elseif #vk_lines == 0 then
    insert(out, '')
    insert(out, '> no output from vulkaninfo (Vulkan SDK / loader missing?)')
  else
    table.insert(out, '')
    for _, l in ipairs(vk_lines) do
      table.insert(out, '    ' .. l)
    end
  end
  insert(out, '')
  insert(out, '## NVIDIA GPUs (nvidia-smi)')
  if smi_err or not smi_lines then
    insert(out, '')
    insert(out, '> nvidia-smi error: ' .. (smi_err or 'no output'))
  elseif #smi_lines == 0 then
    table.insert(out, '')
    table.insert(out, '> no GPUs reported by nvidia-smi')
  else
    table.insert(out, '')
    for _, l in ipairs(smi_lines) do
      table.insert(out, '    ' .. l)
    end
  end
  create_scratch('VkGpuDashboard', out, 'markdown')
end

return M