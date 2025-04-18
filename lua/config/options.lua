-- ~/.config/nvim/lua/config/options.lua

-- Show diagnostics in floating window on hover
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_node_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.loaded_python_provider = 1
vim.g.loaded_ruby_provider = 1
vim.g.which_key_disable_health_check = 1
vim.o.history = 300
vim.o.number = true
vim.o.relativenumber = true
vim.o.syntax = "enable"
vim.o.undodir = vim.fn.expand("~/.config/nvim/undo")
vim.o.undofile = true
vim.opt.backup = false
vim.opt.clipboard = "unnamedplus"
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.guicursor = {
  "n-v-c:underline",
  "i-ci:ver25",
  "r-cr:hor20",
}
vim.opt.laststatus = 2
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.tabstop = 4
vim.opt.modeline = true
vim.opt.modelines = 5
vim.opt.modifiable = true
vim.opt.mouse = "a"
vim.opt.secure = true
vim.opt.shm:append("I")
vim.opt.shortmess:append("I")
vim.opt.shortmess:append("c")
vim.opt.showtabline = 2
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.wildmenu = true
vim.opt.wildmode = "longest:full,full"
vim.opt.writebackup = false
