-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
vim.loader.enable()
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'
vim.cmd('filetype plugin on')
vim.cmd('filetype plugin indent on')
require('config.init').config({
  core = true,
  cicd = true,
  cloud = true,
  debug = false,
  edu = true,
  nav = true,
  ui = true,
})
--vim.opt.packpath = vim.opt.runtimepath:get() ---@type string[]
vim.bo.expandtab = true
vim.bo.modifiable = true ---@type boolean
vim.cmd('set completeopt+=noselect')
vim.g.deprecation_warnings = false
vim.g.editorconfig = true
vim.g.git_command_ssh = 1
vim.g.loaded_illuminate = true
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_node_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.loaded_python_provider = 1
vim.g.loaded_ruby_provider = 1
vim.g.node_host_prog = '/usr/bin/node'
vim.g.perl_host_prog = '/usr/bin/perl'
vim.g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
vim.g.python3_host_prog = '/usr/bin/python3.13'
vim.g.ruby_host_prog = '/usr/bin/neovim-ruby-host'
vim.g.lsp_enable_on_demand = true
vim.g.vim_markdown_folding_disabled = 1
vim.g.vim_markdown_math = 1
vim.g.vim_markdown_frontmatter = 1
vim.g.vim_markdown_toml_frontmatter = 1
vim.g.vim_markdown_json_frontmatter = 1
vim.g.vim_markdown_follow_anchor = 1
vim.g.mkdp_theme = 'dark'
vim.g.ruff_makeprg_params = "--max-line-length --preview "
vim.g.semantic_tokens_enabled = true
vim.g.table_mode_corner = '|'
vim.g.table_mode_separator = '|'
vim.g.table_mode_always_active = 1
vim.g.table_mode_syntax = 1
vim.g.table_mode_update_time = 300
vim.g.use_blink_cmp = true
vim.g.which_key_disable_health_check = 1
vim.g.mkdp_markdown_css = vim.fn.expand('$XDG_CONFIG_HOME/nvim/markdown.css') ---@type string
vim.o.ambiwidth = 'single'
vim.o.autoread = true
vim.o.autowrite = true
vim.o.autowriteall = true
vim.o.backup = false
vim.o.background = 'dark'
vim.o.breakindent = true
vim.o.clipboard = 'unnamedplus'
vim.o.cmdheight = 0
vim.o.completeopt = 'menu,menuone,noselect'
vim.opt_local.concealcursor = 'nc'
vim.opt_local.spell = true
vim.o.conceallevel = 0
vim.o.confirm = true
vim.o.cursorline = true
vim.o.diffopt = 'internal,filler,closeoff,algorithm:histogram,indent-heuristic,linematch:60'
vim.o.encoding = 'utf-8'
vim.o.errorbells = false
vim.o.exrc = true
vim.o.expandtab = true
vim.o.fileencoding = 'utf-8'
vim.o.fileencodings = 'utf-8,ucs-bom,default,latin1'
vim.o.fileformats = 'unix,dos,mac'
vim.o.foldenable = false
vim.o.foldlevel = 99
vim.o.foldexpr = 'nvim_treesitter#foldexpr()'
vim.o.foldmethod = 'manual'
vim.o.guicursor = 'n-v-c:underline,i-ci:ver25,r-cr:hor20'
vim.o.hidden = true
vim.o.history = 300
vim.o.hlsearch = true
vim.o.ignorecase = true
vim.o.inccommand = 'split'
vim.o.incsearch = true
vim.o.laststatus = 3
vim.o.lazyredraw = true
vim.o.linebreak = true
vim.o.list = true
vim.opt.listchars = {
  space = '_',
  tab = '>~',
}
vim.o.magic = true
vim.o.mat = 2
vim.o.modeline = true
vim.o.modelines = 5
vim.o.mouse = 'a'
vim.o.mousescroll = 'ver:3,hor:6'
vim.o.number = true
vim.o.pumheight = 15
vim.o.redrawtime = 10000
vim.o.relativenumber = true
vim.o.ruler = true
--vim.o.report = 9999
vim.o.scrolloff = 8
vim.o.secure = true
vim.o.sessionoptions = 'curdir,folds,help,tabpages,terminal,winsize'
vim.o.shiftwidth = 4
vim.o.shortmess = 'IF'
vim.o.showmode = false
vim.o.showtabline = 2
vim.o.sidescrolloff = 8
vim.o.smartcase = true
vim.o.smarttab = true
vim.o.smoothscroll = true
vim.o.softtabstop = 2
vim.o.spell = true
vim.o.spellfile = vim.fn.stdpath('config') .. '/nvim/spell/en.utf-8.add'
vim.o.spelllang = 'en_us'
vim.o.spelloptions = 'camel'
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.swapfile = false
vim.o.syntax = 'enable'
vim.o.tabstop = 2
vim.o.termguicolors = true
vim.o.tm = 500
vim.opt_local.textwidth = 120
vim.o.timeout = true
vim.o.timeoutlen = 300
vim.o.title = true
vim.o.ttimeoutlen = 10
vim.o.ttyfast = true
vim.o.undodir = vim.fn.stdpath('config') .. '/undo'
vim.o.undofile = true
vim.o.updatetime = 50
vim.o.virtualedit = 'block'
vim.opt.wildignore = {
  '*.a',
  '*.o',
  '*.obj',
  '*.class',
  '*.pyc',
  '__pycache__',
}
vim.o.wildignorecase = true
vim.o.wildmenu = true
vim.o.wildmode = 'noselect'
vim.o.winborder = 'rounded'
vim.o.wrap = true
vim.o.writebackup = true
--------------------
vim.g.guipty = true
vim.g.highlight = true
vim.wo.number = true
vim.api.nvim_create_autocmd({
  'BufNewFile',
  'BufRead',
}, {
  pattern = {
    '*',
  },
  callback = function(args)
    local filename = vim.fn.expand('%:t')
    if filename:match('%.js$') or filename:match('%.jsx$') then
      vim.bo.filetype = 'javascriptreact'
    elseif filename:match('%.ts$') or filename:match('%.tsx$') then
      vim.bo.filetype = 'typescriptreact'
    elseif filename:match('%.snippets$') then
      vim.bo.filetype = 'snippets'
    elseif filename:match('%.html$') then
      vim.bo.filetype = 'jsx'
    end
    local is_file = vim.bo[args.buf].buftype == '' and vim.bo[args.buf].filetype ~= 'gitcommit'
    if is_file then
      vim.opt_local.numberwidth = 4
    else
      vim.opt_local.numberwidth = 1
      vim.opt_local.statuscolumn = ''
    end
  end,
})
vim.cmd([[
    iabbr cosnt const
    iabbr imprt import
    iabbr imoprt import
    iabbr udpate update
    iabbr imrpvoe improve
    iabbr imrpvoe improve
    iabbr ipmrove  improve
    iabbr imrpve improve
    iabbr imprve improve
    iabbr Imrpvoe Improve
    iabbr Imrpvoe Improve
    iabbr Ipmrove Improve
    iabbr Imrpve Improve
    iabbr Imprve Improve
    " function misspellings
    iabbr funcition function
    iabbr funciton function
    iabbr fucntion function
    iabbr functoin function
    iabbr funtion function
    iabbr fucntoin function
    " action misspellings
    iabbr aciton action
    iabbr acton action
    iabbr actoin action
    iabbr actin action
    iabbr ation action
    iabbr actoins actions
    iabbr acitns actions
    " response misspellings
    iabbr resposne response
    iabbr respnse response
    iabbr reponse response
    iabbr respone response
    iabbr resonse response
    iabbr resopnse response
    iabbr resposnes responses
    iabbr respnses responses
    iabbr reponses responses
    " transaction misspellings
    iabbr transation transaction
    iabbr transaciton transaction
    iabbr transacton transaction
    iabbr transction transaction
    iabbr trasaction transaction
    iabbr trasnsaction transaction
    iabbr transactoin transaction
    iabbr transactoins transactions
    iabbr transations transactions
    iabbr transacitons transactions
    iabbr transactons transactions
    iabbr transctions transactions
    " report misspellings
    iabbr repot report
    iabbr reort report
    iabbr rport report
    iabbr reprt report
    iabbr reoprt report
    iabbr repots reports
    iabbr reorts reports
    iabbr rports reports
    " reportAction misspellings
    iabbr repotAction reportAction
    iabbr reportAciton reportAction
    iabbr reportActoin reportAction
    iabbr reprotAction reportAction
    iabbr reoprtAction reportAction
    iabbr reprtAction reportAction
    " Onyx misspellings
    iabbr Onxy Onyx
    iabbr Onix Onyx
    iabbr Onyix Onyx
    iabbr Onxyx Onyx
    iabbr onxy onyx
    iabbr onix onyx
    iabbr onyix onyx
    iabbr onxyx onyx
    " transactionID misspellings
    iabbr transationID transactionID
    iabbr transacitonID transactionID
    iabbr transactonID transactionID
    iabbr transctionID transactionID
    iabbr trasactionID transactionID
    iabbr trasnsactionID transactionID
    iabbr transactoinID transactionID
    " reportActionID misspellings
    iabbr repotActionID reportActionID
    iabbr reportAcitonID reportActionID
    iabbr reportActoinID reportActionID
    iabbr reprotActionID reportActionID
    iabbr reoprtActionID reportActionID
    iabbr reprtActionID reportActionID
    " reportID misspellings
    iabbr repotID reportID
    iabbr reortID reportID
    iabbr rportID reportID
    iabbr reprtID reportID
    iabbr reoprtID reportID
]])
vim.api.nvim_create_autocmd({
    'BufWinEnter'
  },
  {
    desc = 'return cursor to where it was last time closing the file',
    pattern = '*',
    command = 'silent! normal! g`"zv',
  })
local function getPathAndLineNumber(str)
  local file, line = str:match('^(.-)\' function.- line \'(%d+)\'')
  if file and line and tonumber(line) then
    return file, line
  end
  file, line = str:match('^(.-)\' exceptionLine: \'(%d+)\'')
  if file and line and tonumber(line) then
    return file, line
  end
  if not string.find(str, ':') and not string.find(str, '#L') then
    return nil
  end
  return file, line
end
vim.api.nvim_create_user_command('GotoFile', function(opts)
  local filepath, line = getPathAndLineNumber(opts.args)
  local fidget = require('fidget') ---@type table
  if not filepath or not line then
    fidget.notify('Not a valid line number `' .. opts.args .. '`')
    return
  end
  if filepath and not io.open(filepath, 'r') then
    fidget.notify('File doesn\'t exist: `' .. filepath .. '`')
    return
  end
  vim.cmd('edit ' .. filepath)
end, { nargs = 1 })
vim.keymap.set('n', '<leader>gt', ':GotoFile <C-r>*<CR>', {
  noremap = true,
  silent = true,
})
vim.api.nvim_create_autocmd({
  'FocusGained',
  'BufEnter',
  'CursorHold',
  'CursorHoldI',
}, {
  callback = function()
    if vim.bo.filetype ~= '' and vim.bo.filetype ~= 'vim' and vim.fn.mode() ~= 'c' then
      vim.cmd('checktime')
    end
  end,
})