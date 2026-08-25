-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver Tree-sitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------
local M = {}
local api = vim.api
---@type string[]
local parsers = {
  'ada',
  'agda',
  'angular',
  'apex',
  'arduino',
  'asm',
  'astro',
  'awk',
  'bash',
  'bass',
  'beancount',
  'bibtex',
  'bicep',
  'bitbake',
  'blade',
  'bp',
  'c',
  'c_sharp',
  'caddy',
  'cairo',
  'clojure',
  'cmake',
  'comment',
  'commonlisp',
  'cpp',
  'css',
  'csv',
  'cuda',
  'cue',
  'd',
  'dart',
  'desktop',
  'devicetree',
  'diff',
  'dockerfile',
  'dot',
  'doxygen',
  'editorconfig',
  'eex',
  'elixir',
  'elm',
  'embedded_template',
  'erlang',
  'facility',
  'faust',
  'fennel',
  'fish',
  'foam',
  'fortran',
  'fsh',
  'fsharp',
  'func',
  'gap',
  'gdscript',
  'gdshader',
  'gitattributes',
  'git_config',
  'git_rebase',
  'gitignore',
  'gleam',
  'glsl',
  'go',
  'goctl',
  'godot_resource',
  'gomod',
  'gosum',
  'gotmpl',
  'gowork',
  'gpg',
  'graphql',
  'gstlaunch',
  'hack',
  'haskell',
  'hcl',
  'helm',
  'hlsl',
  'hoon',
  'html',
  'htmldjango',
  'hyprlang',
  'idl',
  'idris',
  'inko',
  'ini',
  'java',
  'javadoc',
  'jinja',
  'jq',
  'jsdoc',
  'json',
  'json5',
  'julia',
  'just',
  'kcl',
  'kconfig',
  'kotlin',
  'latex',
  'llvm',
  'lua',
  'luadoc',
  'luap',
  'luau',
  'm68k',
  'make',
  'markdown',
  'markdown_inline',
  'matlab',
  'mermaid',
  'meson',
  'mlir',
  'nginx',
  'ninja',
  'nix',
  'objc',
  'objdump',
  'ocaml',
  'ocaml_interface',
  'ocamllex',
  'odin',
  'passwd',
  'pem',
  'perl',
  'php',
  'php_only',
  'phpdoc',
  'po',
  'powershell',
  'printf',
  'properties',
  'proto',
  'puppet',
  'pymanifest',
  'python',
  'query',
  'r',
  'regex',
  'rego',
  'requirements',
  'rescript',
  'robot',
  'robots_txt',
  'roc',
  'rst',
  'ruby',
  'rust',
  'scala',
  'scfg',
  'scheme',
  'scss',
  'smithy',
  'solidity',
  'sql',
  'ssh_config',
  'starlark',
  'supercollider',
  'superhtml',
  'svelte',
  'sway',
  'swift',
  'systemverilog',
  'tablegen',
  'tcl',
  'teal',
  'templ',
  'terraform',
  'textproto',
  'tiger',
  'toml',
  'tsv',
  'tsx',
  'turtle',
  'typescript',
  'typst',
  'udev',
  'usd',
  'v',
  'vala',
  'vhdl',
  'vim',
  'vimdoc',
  'vue',
  'wgsl',
  'wgsl_bevy',
  'xcompose',
  'xml',
  'yaml',
  'yang',
  'zig',
  'ziggy',
  'ziggy_schema',
  'zsh',
}

---@class TreeOptions
---@field install_dir? string
---@field parsers? string[]
---@field highlight? boolean
---@field indent? boolean
---@field folds? boolean

---@type TreeOptions
local defaults = {
  install_dir = vim.fn.stdpath('data') .. '/site',
  parsers = parsers,
  highlight = true,
  indent = true,
  folds = false,
}

local function register_languages()
  vim.treesitter.language.register('json', 'jsonc')
  vim.treesitter.language.register('markdown', 'mdx')
  vim.treesitter.language.register('systemverilog', 'verilog')

  vim.treesitter.language.register('hcl', {
    'atlas-config',
    'atlas-schema-mysql',
    'atlas-schema-postgresql',
    'atlas-schema-sqlite',
    'atlas-schema-clickhouse',
    'atlas-schema-mssql',
    'atlas-schema-redshift',
    'atlas-test',
    'atlas-plan',
    'atlas-rule',
  })
end

---@param nvim_treesitter table
---@param wanted string[]
local function install_missing(nvim_treesitter, wanted)
  if
    type(nvim_treesitter.install) ~= 'function'
    or type(nvim_treesitter.get_available) ~= 'function'
    or type(nvim_treesitter.get_installed) ~= 'function'
  then
    local sources = api.nvim_get_runtime_file('lua/nvim-treesitter/init.lua', true)

    vim.notify(
      table.concat({
        'The loaded nvim-treesitter does not provide the main-branch API.',
        'Pin nvim-treesitter to version = "main", update it, and restart.',
        'Loaded candidates:',
        vim.inspect(sources),
      }, '\n'),
      vim.log.levels.ERROR
    )
    return
  end

  local available = {}
  for _, language in ipairs(nvim_treesitter.get_available()) do
    available[language] = true
  end

  local installed = {}
  for _, language in ipairs(nvim_treesitter.get_installed('parsers')) do
    installed[language] = true
  end

  local missing = {}
  local unavailable = {}

  for _, language in ipairs(wanted) do
    if not available[language] then
      unavailable[#unavailable + 1] = language
    elseif not installed[language] then
      missing[#missing + 1] = language
    end
  end
  if #unavailable > 0 then
    table.sort(unavailable)
    vim.notify('Skipping unavailable Tree-sitter parsers: ' .. table.concat(unavailable, ', '), vim.log.levels.WARN)
  end
  if #missing == 0 then
    return
  end
  local ok, result = xpcall(function()
    return nvim_treesitter.install(missing, {
      summary = true,
    })
  end, debug.traceback)
  if not ok then
    vim.notify('Tree-sitter parser installation failed:\n' .. tostring(result), vim.log.levels.ERROR)
  end
end
---@param opts TreeOptions
local function configure_buffer(opts)
  ---@param buf integer
  return function(buf)
    if not api.nvim_buf_is_valid(buf) or not api.nvim_buf_is_loaded(buf) then
      return
    end

    local filetype = vim.bo[buf].filetype or ''
    if filetype == '' then
      return
    end

    local language = vim.treesitter.language.get_lang(filetype) or filetype
    local parser = vim.treesitter.get_parser(buf, language, { error = false })
    if parser == nil then
      return
    end

    if opts.highlight then
      pcall(vim.treesitter.start, buf, language)
    end
    if opts.indent then
      local ok_query, query = pcall(vim.treesitter.query.get, language, 'indents')
      if ok_query and query ~= nil then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    if opts.folds then
      for _, win in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_get_buf(win) == buf then
          vim.wo[win].foldmethod = 'expr'
          vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        end
      end
    end
  end
end

---@param opts TreeOptions
local function setup_native_features(opts)
  local attach = configure_buffer(opts)
  local group = api.nvim_create_augroup('TreeSitter', {
    clear = true,
  })
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = '*',
    callback = function(args)
      attach(args.buf)
    end,
    desc = 'Enable native Tree-sitter features when a parser is available',
  })

  api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'TSUpdate',
    callback = function()
      for _, buf in ipairs(api.nvim_list_bufs()) do
        attach(buf)
      end
    end,
    desc = 'Reattach Tree-sitter after parser updates',
  })

  for _, buf in ipairs(api.nvim_list_bufs()) do
    attach(buf)
  end
end

---@param lhs string
---@param method string
---@param capture string
---@param group string
---@param desc string
local function map_move(lhs, method, capture, group, desc)
  vim.keymap.set(
    {
      'n',
      'x',
      'o',
    },
    lhs,
    function()
      local move = require('nvim-treesitter-textobjects.move')
      move[method](capture, group)
    end,
    {
      silent = true,
      desc = desc,
    }
  )
end

function M.textobjects()
  local ok, textobjects = pcall(require, 'nvim-treesitter-textobjects')
  if not ok then
    vim.notify('Tree-sitter textobjects setup skipped: nvim-treesitter-textobjects is unavailable', vim.log.levels.WARN)
    return
  end

  textobjects.setup({
    move = {
      set_jumps = true,
    },
  })

  map_move(']c', 'goto_next_start', '@class.outer', 'textobjects', 'Next class start')
  map_move(']i', 'goto_next_start', '@conditional.outer', 'textobjects', 'Next conditional start')
  map_move(']l', 'goto_next_start', '@loop.outer', 'textobjects', 'Next loop start')
  map_move(']m', 'goto_next_start', '@function.outer', 'textobjects', 'Next function start')
  map_move(']s', 'goto_next_start', '@local.scope', 'locals', 'Next scope')
  map_move(']z', 'goto_next_start', '@fold', 'folds', 'Next fold')

  map_move(']C', 'goto_next_end', '@class.outer', 'textobjects', 'Next class end')
  map_move(']F', 'goto_next_end', '@call.outer', 'textobjects', 'Next call end')
  map_move(']I', 'goto_next_end', '@conditional.outer', 'textobjects', 'Next conditional end')
  map_move(']L', 'goto_next_end', '@loop.outer', 'textobjects', 'Next loop end')
  map_move(']M', 'goto_next_end', '@function.outer', 'textobjects', 'Next function end')

  map_move('[c', 'goto_previous_start', '@class.outer', 'textobjects', 'Previous class start')
  map_move('[f', 'goto_previous_start', '@call.outer', 'textobjects', 'Previous call start')
  map_move('[i', 'goto_previous_start', '@conditional.outer', 'textobjects', 'Previous conditional start')
  map_move('[l', 'goto_previous_start', '@loop.outer', 'textobjects', 'Previous loop start')
  map_move('[m', 'goto_previous_start', '@function.outer', 'textobjects', 'Previous function start')

  map_move('[C', 'goto_previous_end', '@class.outer', 'textobjects', 'Previous class end')
  map_move('[F', 'goto_previous_end', '@call.outer', 'textobjects', 'Previous call end')
  map_move('[I', 'goto_previous_end', '@conditional.outer', 'textobjects', 'Previous conditional end')
  map_move('[L', 'goto_previous_end', '@loop.outer', 'textobjects', 'Previous loop end')
  map_move('[M', 'goto_previous_end', '@function.outer', 'textobjects', 'Previous function end')
end

---@param opts? TreeOptions
function M.treesitter(opts)
  opts = vim.tbl_extend('force', {}, defaults, opts or {})

  local ok, nvim_treesitter = pcall(require, 'nvim-treesitter')
  if not ok or type(nvim_treesitter) ~= 'table' then
    vim.notify('Tree-sitter setup failed: nvim-treesitter is unavailable', vim.log.levels.ERROR)
    return
  end

  if type(nvim_treesitter.setup) ~= 'function' then
    vim.notify(
      'Tree-sitter setup failed: incompatible nvim-treesitter API; ' .. 'the main branch is required',
      vim.log.levels.ERROR
    )
    return
  end

  nvim_treesitter.setup({
    install_dir = opts.install_dir,
  })
  register_languages()
  setup_native_features(opts)
  install_missing(nvim_treesitter, opts.parsers or {})
end

M.parsers = parsers

return M
