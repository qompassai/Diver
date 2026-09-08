-- ~/.config/nvim/lua/dap/store/common.lua
local uv = vim.uv

local M = {}

---@param value unknown
---@return string
function M.literal(value)
  if value == nil then
    return 'NULL'
  end

  if type(value) == 'boolean' then
    return value and 'TRUE' or 'FALSE'
  end

  if type(value) == 'number' then
    assert(value == value and value ~= math.huge and value ~= -math.huge, 'non-finite SQL number')
    return tostring(value)
  end

  local text = tostring(value):gsub("'", "''")
  return "'" .. text .. "'"
end

---@param value unknown
---@return string
function M.json(value)
  local encoded = vim.json.encode(value or {})
  return M.literal(encoded)
end

---@param seed? string
---@return string
function M.id(seed)
  local material = table.concat({
    seed or '',
    tostring(uv.hrtime()),
    tostring(math.random()),
    tostring(vim.fn.getpid()),
  }, '\0')

  return vim.fn.sha256(material):sub(1, 32)
end

---@param root string
---@return string
function M.project_id(root)
  return vim.fn.sha256(vim.fs.normalize(root)):sub(1, 32)
end

---@return string
function M.hostname()
  return uv.os_gethostname() or 'unknown'
end

---@param cwd? string
---@return string?
function M.git_commit(cwd)
  if vim.fn.executable('git') ~= 1 then
    return nil
  end

  local result = vim.system({
    'git',
    '-C',
    cwd or vim.fn.getcwd(),
    'rev-parse',
    'HEAD',
  }, {
    text = true,
  }):wait(1000)

  if result.code ~= 0 then
    return nil
  end

  return vim.trim(result.stdout or '')
end

---@param cwd? string
---@return string?
function M.git_branch(cwd)
  if vim.fn.executable('git') ~= 1 then
    return nil
  end

  local result = vim.system({
    'git',
    '-C',
    cwd or vim.fn.getcwd(),
    'branch',
    '--show-current',
  }, {
    text = true,
  }):wait(1000)

  if result.code ~= 0 then
    return nil
  end

  local branch = vim.trim(result.stdout or '')
  return branch ~= '' and branch or nil
end

return M