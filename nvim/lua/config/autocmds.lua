-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Autocmds Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local augroups = {
  ansible = vim.api.nvim_create_augroup('AnsibleFT', { clear = true }),
  json = vim.api.nvim_create_augroup('JSON', { clear = true }),
  lsp = vim.api.nvim_create_augroup('LSP', { clear = true }),
  markdown = vim.api.nvim_create_augroup('MarkdownSettings', { clear = true }),
  python = vim.api.nvim_create_augroup('Python', { clear = true }),
  rust = vim.api.nvim_create_augroup('Rust', { clear = true }),
  yaml = vim.api.nvim_create_augroup('YAML', { clear = true }),
  zig = vim.api.nvim_create_augroup('Zig', { clear = true })
}

M = M or {}
vim.cmd([[autocmd BufRead,BufNewFile *.hcl set filetype=hcl]])
vim.cmd([[autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform]])
vim.api.nvim_create_autocmd("BufWinEnter", {
  pattern = "*",
  callback = function()
    vim.opt.foldenable = false
    vim.opt.foldmethod = "manual"
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt.clipboard = "unnamedplus"
    vim.wo.conceallevel = 0
    vim.wo.number = true
    vim.wo.relativenumber = true
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  group = augroups.python,
  pattern = 'python',
  callback = function()
    vim.opt_local.autoindent = true
    vim.opt_local.smartindent = true
    vim.api.nvim_buf_create_user_command(0, 'PythonLint', function()
      vim.lsp.buf.format()
      vim.cmd('write')
      vim.notify('Python code linted and formatted', vim.log.levels.INFO)
    end, {})
    vim.api.nvim_buf_create_user_command(0, 'PyTestFile', function()
      local file = vim.fn.expand('%:p')
      vim.cmd('split | terminal pytest ' .. file)
    end, {})
    vim.api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
      local file = vim.fn.expand('%:p')
      local cmd = 'pytest ' .. file .. '::' .. vim.fn.expand('<cword>') ..
          ' -v'
      vim.cmd('split | terminal ' .. cmd)
    end, {})
  end
})
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroups.ansible,
  pattern = {
    '*/ansible/*.yml', '*/playbooks/*.yml', '*/tasks/*.yml',
    '*/roles/*.yml', '*/handlers/*.yml'
  },
  callback = function() vim.bo.filetype = 'ansible' end
})
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroups.yaml,
  pattern = { '*.yml', '*.yaml' },
  callback = function()
    local content = table.concat(
      vim.api.nvim_buf_get_lines(0, 0, 30, false), '\n')
    if content:match('ansible_') or
        (content:match('hosts:') and content:match('tasks:')) then
      vim.bo.filetype = 'yaml.ansible'
    elseif content:match('apiVersion:') and content:match('kind:') then
      vim.bo.filetype = 'yaml.kubernetes'
    elseif content:match('version:') and content:match('services:') then
      vim.bo.filetype = 'yaml.docker'
    end
  end
})
local function get_relative_path(filepath)
  local qompass_idx = filepath:find("/qompassai/")
  if qompass_idx then
    return filepath:sub(qompass_idx + 1)
  else
    local rel = vim.fn.fnamemodify(filepath, ":~:.")
    return rel
  end
end

local function make_qompass_header(filepath, comment)
  local relpath = get_relative_path(filepath)
  local description = "Qompass AI - [Add description here]"
  local copyright = "Copyright (C) 2025 Qompass AI, All rights reserved"
  local solid

  if comment == '<!--' then
    solid = '<!-- ' .. string.rep('-', 40) .. ' -->'
    return {
      '<!-- ' .. relpath .. ' -->',
      '<!-- ' .. description .. ' -->',
      '<!-- ' .. copyright .. ' -->',
      solid
    }
  elseif comment == '/*' then
    solid = '/* ' .. string.rep('-', 40) .. ' */'
    return {
      '/* ' .. relpath .. ' */',
      '/* ' .. description .. ' */',
      '/* ' .. copyright .. ' */',
      solid
    }
  else
    solid = comment .. ' ' .. string.rep('-', 40)
    return {
      comment .. ' ' .. relpath,
      comment .. ' ' .. description,
      comment .. ' ' .. copyright,
      solid
    }
  end
end

vim.api.nvim_create_autocmd('BufNewFile', {
  pattern = '*',
  callback = function()
    local filepath = vim.fn.expand('%:p')
    local ext = vim.fn.expand('%:e')
    local filetype = vim.bo.filetype
    local comment_map = {
      arduino = '//',
      asciidoc = '//',
      asm = ';',
      astro = '//',
      avro = '#',
      bash = '#',
      bicep = '//',
      c = '//',
      cf = '#',
      cff = '#',
      cfn = '#',
      clojure = ';',
      cmake = '#',
      compute = '//',
      conf = '#',
      cpp = '//',
      cs = '//',
      css = '/*',
      cuda = '//',
      cue = '//',
      dhall = '--',
      dockerfile = '#',
      dosini = ';',
      elixir = '#',
      fish = '#',
      fix = '#',
      glsl = '//',
      go = '//',
      graphql = '#',
      h = '//',
      haskell = '--',
      hlsl = '//',
      hocon = '#',
      hpp = '//',
      html = '<!--',
      ini = ';',
      java = '//',
      javascript = '//',
      javascriptreact = '//',
      js = '//',
      json = '//',
      jsonc = '//',
      julia = '#',
      kotlin = '//',
      latex = '%',
      less = '/*',
      lua = '--',
      markdown = '<!--',
      md = '<!--',
      mdx = '//',
      meson = '#',
      mlir = '//',
      mojo = '#',
      mql4 = '//',
      mql5 = '//',
      nix = '#',
      opencl = '//',
      openqasm = '//',
      parquet = '#',
      perl = '#',
      php = '//',
      pine = '//',
      pl = '#',
      plsql = '--',
      powershell = '#',
      proto = '//',
      protobuf = '//',
      py = '#',
      python = '#',
      qsharp = '//',
      quil = '#',
      r = '#',
      rb = '#',
      renderdoc = '#',
      rmd = '#',
      rs = '//',
      rst = '..',
      ruby = '#',
      rust = '//',
      sass = '//',
      scala = '//',
      scss = '/*',
      sh = '#',
      sql = '--',
      svelte = '//',
      swift = '//',
      systemverilog = '//',
      terraform = '#',
      tex = '%',
      toml = '#',
      ts = '//',
      typescript = '//',
      typescriptreact = '//',
      unity = '//',
      verilog = '//',
      vhdl = '--',
      vim = '"',
      vue = '//',
      wasm = ';;',
      wat = ';;',
      x86asm = ';',
      xml = '<!--',
      yaml = '#',
      yml = '#',
      zig = '//',
      zsh = '#'
    }
    local comment = comment_map[ext] or comment_map[filetype] or '#'
    if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == '' then
      local header = make_qompass_header(filepath, comment)
      vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
      vim.cmd('normal! G')
    end
  end
})
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = {
    'Dockerfile.*', '*.Dockerfile', 'Containerfile', '*.containerfile'
  },
  callback = function() vim.bo.filetype = 'dockerfile' end
})

return M
