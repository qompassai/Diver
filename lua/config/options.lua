-- ~/.config/nvim/lua/config/options.lua

---@module 'config.options'
---@class ConfigOptions
---@field git_command_ssh integer
---@field editorconfig boolean
---@field loaded_illuminate boolean
---@field loaded_netrw integer
---@field loaded_netrwPlugin integer
---@field loaded_node_provider integer
---@field loaded_perl_provider integer
---@field loaded_python_provider integer
---@field loaded_ruby_provider integer
---@field lsp_enable_on_demand boolean
---@field mkdp_theme string
---@field semantic_tokens_enabled boolean
---@field syntax_on boolean
---@field use_blink_cmp boolean
---@field which_key_disable_health_check integer

vim.bo.modifiable = true
---@type integer
vim.g.git_command_ssh = 0
---@type boolean
vim.g.editorconfig = true
if vim.fn.executable('rg') == 1 then
  vim.opt.grepprg = 'rg --vimgrep --no-heading --smart-case'
  vim.opt.grepformat = '%f:%l:%c:%m,%f:%l:%m'
elseif vim.fn.executable('ag') == 1 then
  vim.opt.grepprg = 'ag --vimgrep'
  vim.opt.grepformat = '%f:%l:%c:%m'
end
---@type boolean
vim.g.loaded_illuminate = true
vim.g.loaded_netrw = 0
vim.g.loaded_netrwPlugin = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.lsp_enable_on_demand = true
vim.g.mkdp_theme = 'dark'
---@type boolean
vim.g.semantic_tokens_enabled = true
vim.g.syntax_on = true
vim.g.use_blink_cmp = true
vim.g.which_key_disable_health_check = 0
---@type integer
vim.o.history = 300
---@type boolean
vim.o.number = true
vim.o.relativenumber = true
vim.o.syntax = 'enable'
vim.o.undodir = vim.fn.expand('~/.config/nvim/undo')
vim.o.undofile = true
vim.opt.ambiwidth = 'single'
---@type boolean
vim.opt.backup = false
vim.opt.breakindent = true
vim.opt.clipboard = 'unnamedplus'
vim.opt.cmdheight = 0
vim.opt.conceallevel = 0
---@type boolean
vim.opt.cursorline = true
vim.opt.diffopt:append({ 'algorithm:histogram', 'indent-heuristic', 'linematch:60' })
vim.opt.encoding = 'utf-8'
vim.opt.exrc = true
vim.opt.fileformats = { 'unix', 'dos', 'mac' }
vim.opt.fileencodings = { 'utf-8', 'ucs-bom', 'default', 'latin1' }
vim.opt.fileencoding = 'utf-8'
vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.foldmethod = 'expr'
vim.opt.hidden = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.incsearch = true
vim.opt.inccommand = 'split'
vim.opt.guicursor = {
  'n-v-c:underline',
  'i-ci:ver25',
  'r-cr:hor20',
}
vim.opt.laststatus = 3
vim.opt.lazyredraw = false --conflicts with Noice if true
vim.opt.linebreak = true -- Break lines at word boundaries
vim.opt.list = true
vim.opt.listchars = {
  tab = '→ ',
  trail = '·',
  nbsp = '␣',
  extends = '»',
  precedes = '«',
}
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.modeline = true
vim.opt.modelines = 5
vim.opt.mouse = 'a'
vim.opt.mousescroll = 'ver:3,hor:6'
vim.opt.scrolloff = 8
vim.opt.secure = true
vim.opt.shm:append('I')
vim.opt.shortmess:append('I')
vim.opt.shortmess:append('c')
vim.opt.showtabline = 2
vim.opt.sidescrolloff = 8
vim.opt.smartcase = true
vim.opt.smoothscroll = true
---@type string[]
vim.opt.spelllang = { 'en_us' }
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.swapfile = false
vim.opt.termguicolors = true
--if vim.env.TMUX then
--  vim.opt.term = 'tmux-256color'
--end
vim.opt.timeout = true
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10
vim.opt.ttyfast = true
vim.opt.updatetime = 100
---@type string
vim.opt.virtualedit = 'block'
vim.opt.wildmenu = true
vim.opt.wildmode = 'longest:full,full'
vim.opt.writebackup = true
vim.wo.spell = true
local is_windows = vim.fn.has('win32') ~= 0
local sep = is_windows and '\\' or '/'
local delim = is_windows and ';' or ':'
vim.env.PATH = table.concat({ vim.fn.stdpath('data'), 'mason', 'bin' }, sep) .. delim .. vim.env.PATH
