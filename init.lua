-- /qompassai/Diver/init.lua
-- Qompass AI Diver Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
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
if vim.pack and vim.pack.add then
  vim.pack.add({
    {
      src = 'https://github.com/trixnz/sops.nvim',
      version = 'main',
    },
  })
end
vim.g.mapleader = ' '
vim.g.editorconfig = true
vim.g.git_command_ssh = 1
vim.g.loaded_illuminate = true
vim.g.loaded_netrw = 0
vim.g.loaded_netrwPlugin = 0
vim.g.loaded_node_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.loaded_python_provider = 1
vim.g.loaded_ruby_provider = 1
vim.g.lsp_enable_on_demand = true
vim.g.mkdp_theme = 'dark'
vim.g.semantic_tokens_enabled = true
vim.g.syntax_on = true
--vim.g.use_blink_cmp = true
vim.g.which_key_disable_health_check = 1
--vim.g.mkdp_markdown_css = vim.fn.expand("~/.config/nvim/markdown.css")
vim.o.ambiwidth = 'single'
vim.g.asmsyntax = 'asm68k'
vim.o.backup = false
vim.o.breakindent = true
vim.o.clipboard = 'unnamedplus'
vim.o.cmdheight = 0
vim.o.completeopt = 'menu,menuone,noselect'
vim.o.conceallevel = 0
vim.o.confirm = true
vim.o.cursorline = true
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
vim.o.modeline = true
vim.o.modelines = 5
vim.o.mouse = 'a'
vim.o.mousescroll = 'ver:3,hor:6'
vim.o.number = true
vim.o.redrawtime = 10000
vim.o.relativenumber = true
vim.o.scrolloff = 8
vim.o.secure = true
vim.o.shiftwidth = 4
vim.o.shortmess = 'I'
vim.o.showtabline = 2
vim.o.sidescrolloff = 8
vim.o.smartcase = true
vim.o.smoothscroll = true
vim.o.softtabstop = 4
vim.o.spell = true
vim.o.spelllang = 'en_us'
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.swapfile = false
vim.o.syntax = 'enable'
vim.o.tabstop = 4
vim.o.termguicolors = true
vim.o.timeout = true
vim.o.timeoutlen = 300
vim.o.ttimeoutlen = 10
vim.o.ttyfast = true
vim.o.undodir = vim.fn.stdpath('config') .. '/undo'
vim.o.undofile = true
vim.o.updatetime = 100
vim.o.virtualedit = 'block'
vim.o.wildignore = '*.o,*.obj,*.class,*.pyc'
vim.o.wildmenu = true
vim.o.wildmode = 'longest:full,full'
vim.o.wildignorecase = true
vim.o.winminwidth = 5
vim.o.writebackup = true
vim.o.foldenable = false
vim.o.foldmethod = 'manual'
vim.o.listchars = 'tab:→ ,trail:·,nbsp:␣,extends:»,precedes:«'
--vim.o.diffopt = "internal,filler,closeoff,algorithm:histogram,indent-heuristic,linematch:60"
vim.bo.modifiable = true
if vim.fn.executable('rg') == 1 then
  vim.o.grepprg = 'rg --vimgrep --no-heading --smart-case'
  vim.o.grepformat = '%f:%l:%c:%m,%f:%l:%m'
elseif vim.fn.executable('ag') == 1 then
  vim.o.grepprg = "ag --vimgrep"
  vim.o.grepformat = '%f:%l:%c:%m'
end
local is_windows = vim.fn.has('win32') ~= 0
local sep = is_windows and '\\' or '/'
local delim = is_windows and ';' or ':'
local new_path = table.concat({
    vim.fn.stdpath('data'),
    'mason', 'bin'
  },
  sep) .. delim .. vim.env.PATH
vim.fn.setenv('PATH', new_path)