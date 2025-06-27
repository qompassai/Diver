-- ~/.config/nvim/lua/config/options.lua

---@type Options
local options = {
  ambiwidth = 'single',
  backup = false,
  breakindent = true,
  clipboard = 'unnamedplus',
  cmdheight = 0,
  conceallevel = 0,
  cursorline = true,
  diffopt = { 'internal', 'filler', 'closeoff', 'algorithm:histogram', 'indent-heuristic', 'linematch:60' },
  encoding = 'utf-8',
  exrc = true,
  expandtab = true,
  fileencoding = 'utf-8',
  fileencodings = { 'utf-8', 'ucs-bom', 'default', 'latin1' },
  fileformats = { 'unix', 'dos', 'mac' },
  foldexpr = 'nvim_treesitter#foldexpr()',
  foldenable = false,
  foldlevel = 99,
  foldmethod = 'expr',
  guicursor = {
    'n-v-c:underline',
    'i-ci:ver25',
    'r-cr:hor20',
  },
  hidden = true,
  history = 300,
  hlsearch = true,
  ignorecase = true,
  inccommand = 'split',
  incsearch = true,
  laststatus = 3,
  lazyredraw = false,
  linebreak = true,
  list = true,
  listchars = {
    tab = '→ ',
    trail = '·',
    nbsp = '␣',
    extends = '»',
    precedes = '«',
  },
  modeline = true,
  modelines = 5,
  mouse = 'a',
  mousescroll = 'ver:3,hor:6',
  number = true,
  relativenumber = true,
  scrolloff = 8,
  secure = true,
  shiftwidth = 4,
  shortmess = 'I',
  showtabline = 2,
  sidescrolloff = 8,
  smartcase = true,
  smoothscroll = true,
  softtabstop = 4,
  spell = true,
  spelllang = { 'en_us' },
  splitbelow = true,
  splitright = true,
  swapfile = false,
  syntax = 'enable',
  tabstop = 4,
  termguicolors = true,
  timeout = true,
  timeoutlen = 300,
  ttimeoutlen = 10,
  ttyfast = true,
  undodir = vim.fn.expand('~/.config/qai/diver/undo'),
  undofile = true,
  updatetime = 100,
  virtualedit = 'block',
  wildmenu = true,
  wildmode = 'longest:full,full',
  writebackup = true,
}
---@type Globals
local globals = {
  editorconfig = true,
  git_command_ssh = 0,
  loaded_illuminate = true,
  loaded_netrw = 0,
  loaded_netrwPlugin = 0,
  loaded_node_provider = 0,
  loaded_perl_provider = 0,
  loaded_python_provider = 0,
  loaded_ruby_provider = 0,
  lsp_enable_on_demand = true,
  mkdp_theme = 'dark',
  semantic_tokens_enabled = true,
  syntax_on = true,
  use_blink_cmp = true,
  which_key_disable_health_check = 0,
}
for k, v in pairs(globals) do
  vim.g[k] = v
end
for k, v in pairs(options) do
  vim.opt[k] = v
end
vim.bo.modifiable = true
vim.opt.shortmess:append('c')
vim.opt.shortmess:append('c')
if vim.fn.executable('rg') == 1 then
  vim.opt.grepprg = 'rg --vimgrep --no-heading --smart-case'
  vim.opt.grepformat = '%f:%l:%c:%m,%f:%l:%m'
elseif vim.fn.executable('ag') == 1 then
  vim.opt.grepprg = 'ag --vimgrep'
  vim.opt.grepformat = '%f:%l:%c:%m'
end
local is_windows = vim.fn.has('win32') ~= 0
local sep = is_windows and '\\' or '/'
local delim = is_windows and ';' or ':'
local new_path = table.concat({ vim.fn.stdpath('data'), 'mason', 'bin' }, sep) .. delim .. vim.env.PATH
vim.fn.setenv('PATH', new_path)
