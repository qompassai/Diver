-- #################################################################
-- /qompassai/lua/utils/docs/license.lua
-- Qompass AI License
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
local M = {}
local group_name = 'license'
---@class license.Config
---@field org string
---@field spdx string
---@field title_prefix string
---@field auto boolean
---@type license.Config
M.config = {
  auto = false,
  org = 'Qompass AI',
  spdx = 'Apache-2.0',
  title_prefix = 'Qompass AI',
  auto = true,
}
---@param s string
---@return string
local function trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

---@param s string
---@return string[]
local function split_words(s)
  ---@type string[]
  local out = {}

  for word in s:gmatch('[A-Za-z0-9]+') do
    out[#out + 1] = word
  end

  return out
end
---@param word string
---@return string
local function title_case_word(word)
  if word:match('^%u+$') then
    return word
  end

  return word:sub(1, 1):upper() .. word:sub(2):lower()
end

---@param name string
---@return string
local function derive_title(name)
  local base = name:gsub('%..+$', ''):gsub('[_%-.]+', ' ')
  local words = split_words(trim(base))

  if #words == 0 then
    return M.config.title_prefix .. ' Config'
  end

  for idx = 1, #words do
    words[idx] = title_case_word(words[idx])
  end

  return M.config.title_prefix .. ' ' .. table.concat(words, ' ')
end

---@param bufnr integer
---@return string
local function comment_prefix(bufnr)
  ---@type string?
  local cs = vim.bo[bufnr].commentstring

  if type(cs) == 'string' and cs ~= '' and cs:find('%%s', 1, true) then
    local prefix = trim(cs:gsub('%%s', ''))
    if prefix ~= '' then
      return prefix
    end
  end

  ---@type string
  local ft = vim.bo[bufnr].filetype
  if ft == 'markdown' or ft == 'markdown.readme' then
    return '<!--'
  end

  ---@type table<string, string>
  local map = {
    ada = '--',
    apex = '//',
    asm = ';',
    awk = '#',
    bash = '#',
    brioche = '#',
    c = '//',
    cairo = '//',
    clar = ';',
    clarity = ';;',
    cmake = '#',
    cobol = '*>',
    conf = '#',
    cpp = '//',
    crystal = '#',
    css = '/*',
    csv = '#',
    cypher = '//',
    cython = '#',
    dockerfile = '#',
    dosini = ';',
    edge = '@*',
    ejs = '<%#',
    eruby = '<%#',
    fish = '#',
    fortran = '!',
    faust = '//',
    glsl = '//',
    go = '//',
    gradle = '//',
    graphql = '#',
    groff = '\\"',
    handlebars = '{{!--',
    haskell = '--',
    hcl = '#',
    helm = '{{/*',
    html = '<!--',
    ['html.antlers'] = '<!--',
    ['html-eex'] = '<!--',
    hyprlang = '#',
    ini = ';',
    jinja = '{#',
    javascript = '//',
    ['javascript.glimmer'] = '{{!',
    javascriptreact = '//',
    json = '//',
    jsonc = '//',
    leaf = '#',
    lua = '--',
    make = '#',
    --markdown = '<!--',
    -- ['markdown.readme'] = '<!--',
    mdx = '{/*',
    mojo = '#',
    nginx = '#',
    nftables = '#',
    njk = '{#',
    nunjucks = '{#',
    objc = '//',
    perl = '#',
    pgsql = '--',
    php = '//',
    pkgbuild = '#',
    po = '#',
    postcss = '/*',
    ps1 = '#',
    ps1xml = '<!--',
    python = '#',
    qml = '//',
    razor = '@*',
    ruby = '#',
    rust = '//',
    rst = '..',
    rst = '//',
    scala = '//',
    scdoc = ';',
    scss = '//',
    sed = '#',
    slim = '/',
    snippets = '#',
    soql = '//',
    sparql = '#',
    sugarss = '//',
    svg = '<!--',
    systemd = '#',
    systemverilog = '//',
    terraform = '#',
    toml = '#',
    typescript = '//',
    ['typescript.glimmer'] = '{{!',
    typescriptreact = '//',
    verilog = '//',
    vim = '"',
    x11basic = "'",
    xaml = '<!--',
    xdefaults = '!',
    xml = '<!--',
    yaml = '#',
    ['yaml.ansible'] = '#',
    ['yaml.docker-compose'] = '#',
    ['yaml.github'] = '#',
    ['yaml.gitlab'] = '#',
    ['yaml.helm-values'] = '#',
    zig = '//',
    ziggy = '//',
    ziggy_schema = '//',
    zir = '//',
    zon = '//',
    zsh = '#',
  }

  return map[ft] or '#'
end

---@param bufnr integer
---@return string
local function qompass_path(bufnr)
  local full = vim.api.nvim_buf_get_name(bufnr)
  local home = vim.env.HOME or ''
  local xdg = vim.env.XDG_CONFIG_HOME or ((home ~= '') and (home .. '/.config') or '')
  local nvim_cfg = (xdg ~= '') and (xdg .. '/nvim') or ''
  local path = full

  if nvim_cfg ~= '' and path:sub(1, #nvim_cfg) == nvim_cfg then
    path = path:sub(#nvim_cfg + 1)
  elseif home ~= '' and path:sub(1, #home) == home then
    path = path:sub(#home + 1)
  end

  if path == '' then
    path = '/' .. vim.fn.expand('%:t')
  elseif path:sub(1, 1) ~= '/' then
    path = '/' .. path
  end

  if not path:match('^/qompassai') then
    path = '/qompassai' .. path
  end

  return path
end

---@param bufnr integer
---@return string[]
local function make_header(bufnr)
  local prefix = comment_prefix(bufnr)
  local path = qompass_path(bufnr)
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t')
  local year = tostring(os.date('%Y'))
  local title
  local bar

  if name == '' then
    name = 'config'
  end

  title = derive_title(name)
  bar = prefix .. ' ' .. string.rep('#', 65)

  return {
    bar,
    prefix .. ' ' .. path,
    prefix .. ' ' .. title,
    prefix .. ' SPDX-License-Identifier: ' .. M.config.spdx,
    prefix .. ' Copyright (c) ' .. year .. ' ' .. M.config.org,
    prefix,
    prefix .. ' Licensed under the Apache License, Version 2.0 (the "License");',
    prefix .. ' you may not use this file except in compliance with the License.',
    prefix .. ' You may obtain a copy of the License at:',
    prefix .. '   http://www.apache.org/licenses/LICENSE-2.0',
    prefix,
    prefix .. ' Unless required by applicable law or agreed to in writing, software',
    prefix .. ' distributed under the License is distributed on an "AS IS" BASIS,',
    prefix .. ' WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.',
    prefix .. ' See the License for the specific language governing permissions and',
    prefix .. ' limitations under the License.',
    bar,
    '',
  }
end

---@param lines string[]
---@return boolean
local function is_managed(lines)
  local text = table.concat(lines, '\n')

  return text:find('SPDX%-License%-Identifier:', 1, false) ~= nil
    or text:find('Licensed under the Apache License, Version 2.0', 1, true) ~= nil
end

---@param lines string[]
---@return integer?
local function find_header_end(lines)
  local limit = math.min(#lines, 40)

  for idx = 1, limit do
    local line = lines[idx]
    if line and line:find('limitations under the License%.', 1, false) then
      return idx
    end
  end

  return nil
end

---@param bufnr? integer
function M.apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if vim.bo[bufnr].buftype ~= '' then
    return
  end

  ---@type integer
  local count = vim.api.nvim_buf_line_count(bufnr)
  ---@type string[]
  local top = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(count, 40), false)
  ---@type string[]
  local desired = make_header(bufnr)

  if count == 1 and (top[1] or '') == '' then
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, desired)
    return
  end

  if is_managed(top) then
    ---@type integer?
    local header_end = find_header_end(top)
    if header_end then
      ---@type string[]
      local current = vim.api.nvim_buf_get_lines(bufnr, 0, header_end, false)
      ---@type string[]
      local expected = vim.list_slice(desired, 1, #desired - 1)

      if not vim.deep_equal(current, expected) then
        vim.api.nvim_buf_set_lines(bufnr, 0, header_end, false, desired)
      end

      return
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, desired)
end

---@param opts? table<string, any>
function M.setup(opts)
  local group

  if type(opts) == 'table' then
    if type(opts.org) == 'string' then
      M.config.org = opts.org
    end
    if type(opts.spdx) == 'string' then
      M.config.spdx = opts.spdx
    end
    if type(opts.title_prefix) == 'string' then
      M.config.title_prefix = opts.title_prefix
    end
    if type(opts.auto) == 'boolean' then
      M.config.auto = opts.auto
    end
  end

  group = vim.api.nvim_create_augroup(group_name, { clear = true })

  vim.api.nvim_create_autocmd('BufNewFile', {
    group = group,
    callback = function(args)
      if args and args.buf then
        M.apply(args.buf)
      end
    end,
  })
  --[[
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = group,
    callback = function(args)
      if M.config.auto and args and args.buf then
        M.apply(args.buf)
      end
    end,
  })
--]]
  vim.api.nvim_create_user_command('LicenseApply', function()
    M.apply(0)
  end, {
    desc = 'Insert or normalize license header',
  })

  vim.api.nvim_create_user_command('LicenseTitle', function(cmdopts)
    if cmdopts.args ~= '' then
      M.config.title_prefix = cmdopts.args
      M.apply(0)
    end
  end, {
    nargs = 1,
    desc = 'Set license title prefix and reapply',
  })

  vim.api.nvim_create_user_command('LicenseOrg', function(cmdopts)
    if cmdopts.args ~= '' then
      M.config.org = cmdopts.args
      M.apply(0)
    end
  end, {
    nargs = 1,
    desc = 'Set copyright organization and reapply',
  })

  vim.api.nvim_create_user_command('LicenseSpdx', function(cmdopts)
    if cmdopts.args ~= '' then
      M.config.spdx = cmdopts.args
      M.apply(0)
    end
  end, {
    nargs = 1,
    desc = 'Set SPDX identifier and reapply',
  })

  vim.api.nvim_create_user_command('LicenseYear', function(cmdopts)
    local year = trim(cmdopts.args)
    local lines
    local current_year

    if year == '' then
      return
    end

    lines = vim.api.nvim_buf_get_lines(0, 0, 40, false)
    current_year = tostring(os.date('%Y'))

    for idx = 1, #lines do
      lines[idx] = lines[idx]:gsub(current_year, year, 1)
    end

    vim.api.nvim_buf_set_lines(0, 0, math.min(40, #lines), false, lines)
  end, {
    nargs = 1,
    desc = 'Replace current year in header',
  })

  vim.api.nvim_create_user_command('LicenseAuto', function(cmdopts)
    local arg = trim(cmdopts.args):lower()
    M.config.auto = (arg == 'on' or arg == 'true' or arg == '1')
  end, {
    nargs = 1,
    complete = function()
      return { 'on', 'off' }
    end,
    desc = 'Enable or disable auto header update',
  })
end

return M
