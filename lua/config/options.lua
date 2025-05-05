-- ~/.config/nvim/lua/config/options.lua

vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})
vim.g.git_command_ssh = 1
vim.g.editorconfig = true
if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg = "rg --vimgrep --no-heading --smart-case"
  vim.opt.grepformat = "%f:%l:%c:%m,%f:%l:%m"
elseif vim.fn.executable("ag") == 1 then
  vim.opt.grepprg = "ag --vimgrep"
  vim.opt.grepformat = "%f:%l:%c:%m"
end
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_node_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.loaded_python_provider = 1
vim.g.loaded_ruby_provider = 1
vim.g.lsp_enable_on_demand = true
vim.g.mkdp_theme = "dark"
if vim.g.neovide then
  vim.g.neovide_scroll_animation_length = 0.3
  vim.g.neovide_cursor_animation_length = 0.08
end
vim.g.semantic_tokens_enabled = true
vim.g.syntax_on = true
vim.g.which_key_disable_health_check = 1
vim.o.history = 300
vim.o.number = true
vim.o.relativenumber = true
vim.o.syntax = "enable"
vim.o.undodir = vim.fn.expand("~/.config/nvim/undo")
vim.o.undofile = true
vim.opt.ambiwidth = "single"
vim.opt.backup = false
vim.opt.breakindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.cmdheight = 1
vim.opt.conceallevel = 0
vim.opt.cursorline = true
vim.opt.diffopt:append{"algorithm:histogram", "indent-heuristic", "linematch:60"}
vim.opt.encoding = "utf-8"
vim.opt.exrc = true
vim.opt.fileformats = { "unix", "dos", "mac" }
vim.opt.fileencodings = { "utf-8", "ucs-bom", "default", "latin1" }
vim.opt.fileencoding = "utf-8"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.foldmethod = "expr"
vim.opt.hidden = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.incsearch = true
vim.opt.inccommand = "split"
vim.opt.guicursor = {
  "n-v-c:underline",
  "i-ci:ver25",
  "r-cr:hor20",
}
vim.opt.laststatus = 3
vim.opt.lazyredraw = false --conflicts with Noice if true
vim.opt.linebreak = true        -- Break lines at word boundaries
vim.opt.list = true
vim.opt.listchars = {
  tab = "→ ",
  trail = "·",
  nbsp = "␣",
  extends = "»",
  precedes = "«"
}
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.modeline = true
vim.opt.modelines = 5
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:3,hor:6"
vim.opt.scrolloff = 8
vim.opt.secure = true
vim.opt.shm:append("I")
vim.opt.shortmess:append("I")
vim.opt.shortmess:append("c")
vim.opt.showtabline = 2
vim.opt.sidescrolloff = 8
vim.opt.smartcase = true
vim.opt.smoothscroll = true
vim.opt.spelllang = { "en_us" }
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.swapfile = false
vim.opt.termguicolors = true
--if vim.env.TMUX then
--  vim.opt.term = "tmux-256color"
--end
vim.opt.timeout = true
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10
vim.opt.ttyfast = true
vim.opt.updatetime = 100
vim.opt.virtualedit = "block"
vim.opt.wildmenu = true
vim.opt.wildmode = "longest:full,full"
vim.opt.writebackup = true
local is_windows = vim.fn.has "win32" ~= 0
local sep = is_windows and "\\" or "/"
local delim = is_windows and ";" or ":"
vim.env.PATH = table.concat({ vim.fn.stdpath "data", "mason", "bin" }, sep) .. delim .. vim.env.PATH
