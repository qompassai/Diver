-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local bo = vim.bo
local cmd = vim.cmd
local g = vim.g
local l = vim.loader
local o = vim.o ---@type Options
local opt = vim.opt
local wo = vim.wo
bo.expandtab = true
bo.iminsert = 0
bo.imsearch = -1
bo.modifiable = true
cmd('filetype plugin on')
cmd('filetype plugin indent on')
cmd('set completeopt+=noselect')
cmd.runtime('macros/matchit.vim')
g.deprecation_warnings = true
g.editorconfig = true
g.git_command_ssh = 1
g.guipty = true
g.highlight = true
g.loaded_illuminate = true
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1
g.loaded_node_provider = 1
g.loaded_perl_provider = 1
g.loaded_python_provider = 1
g.loaded_ruby_provider = 1
g.lsp_enable_on_demand = true
g.mapleader = ' '
g.maplocalleader = '\\'
g.mkdp_markdown_css = vim.fn.expand('$XDG_CONFIG_HOME/nvim/markdown.css') ---@type string
g.mkdp_theme = 'dark'
g.node_host_prog = '/usr/bin/node'
g.perl_host_prog = '/usr/bin/perl'
g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
g.python3_host_prog = '/usr/bin/python3'
g.ruby_host_prog = '/usr/bin/neovim-ruby-host'
g.rust_cargo_check_all_targets = true
g.rust_cargo_check_benches = true
g.rust_conceal = false
g.rust_conceal_pub = false
g.rust_playpen_url = 'https://play.rust-lang.org/'
g.rust_recommended_style = true
g.rustfmt_detect_version = false
g.rustfmt_emit_files = false
g.rust_shortener_url = 'https://is.gd/'
g.ruff_makeprg_params = '--max-line-length --preview '
g.semantic_tokens_enabled = true
g.table_mode_corner = '|'
g.table_mode_separator = '|'
g.table_mode_always_active = 1
g.table_mode_syntax = 1
g.table_mode_update_time = 300
g.use_blink_cmp = true
g.vim_markdown_folding_disabled = 1
g.vim_markdown_math = 1
g.vim_markdown_frontmatter = 1
g.vim_markdown_toml_frontmatter = 1
g.vim_markdown_json_frontmatter = 1
g.vim_markdown_follow_anchor = 1
g.which_key_disable_health_check = 1
l.enable()
require('config.init').config({
  core = true,
  cicd = true,
  cloud = true,
  debug = false,
  edu = true,
  nav = true,
  ui = true,
})
o.allowrevins = true
o.ambiwidth = 'single'
o.autochdir = true
o.autocomplete = false
o.autocompletetimeout = 80
o.autocompletedelay = 0
o.autoread = true
o.autowrite = true
o.autowriteall = true
o.backup = false
o.backupcopy = 'auto'
o.background = 'dark'
o.breakindent = true
o.clipboard = 'unnamedplus'
o.cmdheight = 0
o.completeitemalign = 'abbr,kind,menu'
o.completeopt = 'menu,menuone,noselect'

o.concealcursor = 'nc'
o.conceallevel = 0
o.confirm = true
o.cursorline = true
o.debug = 'msg'
o.diffopt = 'internal,filler,closeoff,algorithm:histogram,indent-heuristic,linematch:60'
o.encoding = 'utf-8'
o.errorbells = false
o.exrc = true
o.expandtab = true
o.fileencoding = 'utf-8'
o.fileencodings = 'utf-8,ucs-bom,default,latin1'
o.fileformats = 'unix,dos,mac'
o.foldenable = false
o.foldlevel = 99
o.foldexpr = 'nvim_treesitter#foldexpr()'
o.foldmethod = 'manual'
o.formatoptions = 'tcqj'
o.grepprg = 'rg --vimgrep'
o.guicursor = 'n-v-c:underline,i-ci:ver25,r-cr:hor20'
o.hidden = true
o.history = 1000
o.hlsearch = true
o.icon = false
o.ignorecase = true
o.inccommand = 'split'
o.incsearch = true
o.isprint = '@,161-255'
o.joinspaces = true
o.jumpoptions = 'clean'
o.langnoremap = true
o.langremap = false
o.laststatus = 3
o.lazyredraw = true
o.linebreak = true
o.linespace = 0
o.list = true
o.magic = true
o.mat = 2
o.maxsearchcount = 999
o.modeline = true
o.modelines = 5
o.mouse = 'a'
o.mousescroll = 'ver:3,hor:6'
o.number = true
o.pumheight = 15
o.redrawtime = 10000
o.relativenumber = true
o.ruler = true
o.report = 9999
o.scrolloff = 8
o.secure = true
o.sessionoptions = 'curdir,folds,help,tabpages,terminal,winsize'
o.shiftwidth = 4
o.shortmess = 'IF'
o.showmode = false
o.showtabline = 2
o.sidescroll = 1
o.sidescrolloff = 8
o.smartcase = true
o.smarttab = true
o.smoothscroll = true
o.softtabstop = 2
o.spell = true
o.spellfile = vim.fn.stdpath('config') .. '/nvim/spell/en.utf-8.add'
o.spelllang = 'en_us'
o.spelloptions = 'camel'
o.splitbelow = true
o.splitright = true
o.startofline = false
o.swapfile = false
o.switchbuf = 'uselast'
o.syntax = 'enable'
o.tabpagemax = 50
o.tabstop = 2
o.termguicolors = true
o.tm = 500
vim.opt_local.textwidth = 120
o.timeout = true
o.timeoutlen = 300
o.title = true
o.ttimeoutlen = 10
o.ttyfast = true
o.undodir = vim.fn.stdpath('config') .. '/undo'
o.undofile = true
o.updatetime = 50
o.viewoptions = 'unix,slash'
o.virtualedit = 'block'
o.wildignorecase = true
o.wildmenu = true
o.wildmode = 'noselect'
o.winborder = 'rounded'
o.wrap = true
o.writebackup = true
opt.backspace = { 'indent', 'eol', 'start' }
opt.comments:append('fb:•') ---@type OptionMethods
opt.complete:remove('i')
opt.listchars = {
  space = '_',
  tab = '>~',
}
opt.lispwords = opt.lispwords:get() ---@type OptionMethods
--opt.packpath = vim.opt.runtimepath:get() ---@type string[]
opt.nrformats = { 'bin', 'hex' }
opt.tags = { './tags;,tags' }
opt.viminfo:append('!')
opt.wildignore = {
  '*.a',
  '*.o',
  '*.obj',
  '*.class',
  '*.pyc',
  '__pycache__',
}
wo.conceallevel = 0
wo.cursorbind = false
wo.cursorline = true
wo.cursorlineopt = 'both'
wo.lhistory = 10
wo.list = true
wo.number = true