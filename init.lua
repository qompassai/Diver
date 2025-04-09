-- bootstrap lazy.nvim, LazyVim and your plugins
vim.g.mapleader = " "
vim.keymap.set("n", "gc", "<Nop>", { noremap = true })
vim.keymap.set("n", "gcc", "<Nop>", { noremap = true })
vim.keymap.set("x", "gc", "<Nop>", { noremap = true })
vim.keymap.set("o", "gc", "<Nop>", { noremap = true })
vim.opt.shortmess:append "I"
vim.opt.shm:append "I"
vim.o.number = true
vim.o.relativenumber = true
vim.o.undodir = vim.fn.expand("~/.config/nvim/undo")
vim.o.undofile = true
vim.o.history = 300
vim.opt.guicursor = {
    "n-v-c:underline",      -- Normal, Visual, Command modes: underline cursor
    "i-ci:ver25",           -- Insert, Command-line Insert modes: vertical bar
    "r-cr:hor20",           -- Replace, Command-line Replace modes: horizontal bar
}
local function safe_require(module)
  if package.loaded[module] then
    return true, package.loaded[module]
  end
  local success, result = pcall(require, module)
  if not success then
    local error_message = type(result) == "table" and vim.inspect(result) or result
    vim.notify("Error loading ".. module ..":".. error_message, vim.log.levels.ERROR)

  end
  return success, result
end
vim.g.which_key_disable_health_check = 1
safe_require("mappings")
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.clipboard = "unnamedplus"
require("config.lazy")
vim.g.lightline = {
  active = {
    left = {
      { 'mode', 'paste' },
      { 'gitbranch', 'readonly', 'filename', 'modified' }
    },
    right = {
      { 'lineinfo' },
      { 'percent' },
      { 'fileformat', 'fileencoding', 'filetype' }
    }
  },
  component_function = {
    gitbranch = 'FugitiveHead'
  },
  separator = { left = '', right = '' },
  subseparator = { left = '', right = '' }
}

vim.g.lightline.tabline = {
  left = { { 'buffers' } },
  right = { { 'close' } }
}

-- Enable statusline and tabline
vim.opt.laststatus = 2
vim.opt.showtabline = 2
vim.opt.modifiable = true

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})
vim.g.loaded_node_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.loaded_ruby_provider = 1

vim.api.nvim_create_autocmd({ "CursorHold" }, {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end
})
