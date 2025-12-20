-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
vim.loader.enable()
require('config.init').config({
  core = true,
  cicd = true,
  cloud = true,
  debug = false,
  edu = true,
  nav = true,
  ui = true
})
vim.opt.packpath = vim.opt.runtimepath:get() ---@type string[]
vim.pack.add {
  {
    src = 'https://github.com/dense-analysis/ale'
  },
  {
    src = 'https://github.com/trixnz/sops.nvim'
  },
  {
    src = 'https://github.com/Saghen/blink.cmp'
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter'
  },
  {
    src = 'https://github.com/L3MON4D3/LuaSnip'
  },
  {
    src = 'https://github.com/rafamadriz/friendly-snippets'
  },
  {
    src = 'https://github.com/hrsh7th/cmp-nvim-lua'
  },
  {
    src = 'https://github.com/hrsh7th/cmp-buffer'
  },
  {
    src = 'https://github.com/moyiz/blink-emoji.nvim'
  },
  {
    src = 'https://github.com/Kaiser-Yang/blink-cmp-dictionary'
  },
  {
    src = 'https://github.com/Saghen/blink.compat',
  },
}
vim.bo.expandtab = true
vim.bo.modifiable = true ---@type boolean
vim.cmd('set completeopt+=noselect')
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'
vim.g.editorconfig = true
vim.g.git_command_ssh = 1
vim.g.loaded_illuminate = true
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 0
vim.g.loaded_node_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.loaded_python_provider = 1
vim.g.loaded_ruby_provider = 1
vim.g.lsp_enable_on_demand = true
vim.g.vim_markdown_folding_disabled = 1
vim.g.vim_markdown_math = 1
vim.g.vim_markdown_frontmatter = 1
vim.g.vim_markdown_toml_frontmatter = 1
vim.g.vim_markdown_json_frontmatter = 1
vim.g.vim_markdown_follow_anchor = 1
vim.g.mkdp_theme = 'dark'
vim.g.semantic_tokens_enabled = true
vim.g.table_mode_corner = '|'
vim.g.table_mode_separator = '|'
vim.g.table_mode_always_active = 1
vim.g.table_mode_syntax = 1
vim.g.table_mode_update_time = 300
vim.g.use_blink_cmp = true
vim.g.which_key_disable_health_check = 1
vim.g.mkdp_markdown_css = vim.fn.expand('~/.config/nvim/markdown.css') ---@type string
vim.o.ambiwidth = 'single'
vim.o.autowrite = true
vim.o.autowriteall = true
vim.o.backup = false
vim.o.breakindent = true
vim.o.clipboard = 'unnamedplus'
vim.o.cmdheight = 0
vim.o.completeopt = 'menu,menuone,noselect'
vim.opt_local.concealcursor = 'nc'
vim.opt_local.spell = true
vim.o.conceallevel = 0
vim.o.confirm = true
vim.o.cursorline = true
vim.o.diffopt = "internal,filler,closeoff,algorithm:histogram,indent-heuristic,linematch:60"
vim.o.encoding = 'utf-8'
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
vim.o.lazyredraw = false
vim.o.linebreak = true
vim.o.list = true
vim.opt.listchars = {
  space = '_',
  tab = '>~'
}
vim.opt_local.wrap = false
vim.o.modeline = true
vim.o.modelines = 5
vim.o.mouse = 'a'
vim.o.mousescroll = 'ver:3,hor:6'
vim.o.number = true
vim.o.pumheight = 15
vim.o.redrawtime = 10000
vim.o.relativenumber = true
--vim.o.report = 9999
vim.o.scrolloff = 8
vim.o.secure = true
vim.o.shiftwidth = 4
vim.o.shortmess = 'IF'
vim.o.showtabline = 2
vim.o.sidescrolloff = 8
vim.o.smartcase = true
vim.o.smarttab = true
vim.o.smoothscroll = true
vim.o.softtabstop = 2
vim.o.spell = true
vim.o.spelllang = 'en_us'
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.swapfile = false
vim.o.syntax = 'enable'
vim.o.tabstop = 2
vim.o.termguicolors = true
vim.opt_local.textwidth = 120
vim.o.timeout = true
vim.o.timeoutlen = 300
vim.o.ttimeoutlen = 10
vim.o.ttyfast = true
vim.o.undodir = vim.fn.stdpath('config') .. '/undo'
vim.o.undofile = true
vim.o.updatetime = 100
vim.o.virtualedit = 'block'
vim.opt.wildignore = {
  '*.a',
  '*.o',
  '*.obj',
  '*.class',
  '*.pyc',
  '__pycache__'
}
vim.o.wildignorecase = true
vim.o.wildmenu = true
vim.o.wildmode = 'longest:full,full'
vim.o.winminwidth = 5
vim.o.writebackup = true
--------------------
vim.g.guipty = true
vim.g.highlight = true
vim.wo.number = true