-- ~/.config/nvim/init.lua
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
local utils = require("utils.safe_require")
_G.safe_require = utils.safe_require
require("config.autocmds")
require("config.options")
require("config.keymaps").setup()
require("config.types")
require("config.lazy")
local wk_ok, wk = pcall(require, "which-key")
if wk_ok and wk.health and wk.health.check then
    wk.health.check = function() return {} end
end
