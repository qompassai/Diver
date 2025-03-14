local M = {}

local function safe_require(module)
  local ok, result = pcall(require, module)
  return ok and result or nil
end

local function load_mappings()
  -- Load your mappings
  M.buffmap = safe_require "mappings.aimap"
  M.buffmap = safe_require "mappings.buffmap"
  M.rustmap = safe_require "mappings.diagmap"
  M.ensure_installed = safe_require "mappings.ensure_installed"
  M.format = safe_require "mappings.format"
  M.genmap = safe_require "mappings.genmap"
  M.jupymap = safe_require "mappings.jupymap"
  M.langmap = safe_require "mappings.langmap"
  M.lsp = safe_require "mappings.lsp"
  M.lspmap = safe_require "mappings.lspmap"
  M.navmap = safe_require "mappings.navmap"
  M.rustmap = safe_require "mappings.rustmap"
  M.settings = safe_require "mappings.settings"
  M.source = safe_require "mappings.source"
  M.telemap = safe_require "mappings.telemap"
  M.automatic_setup = safe_require "mappings.automatic_setup"
end

-- Call load_mappings once at startup
load_mappings()

-- Define your mappings globally
vim.keymap.set("n", "gc", "<Nop>", { noremap = true })
vim.keymap.set("n", "gcc", "<Nop>", { noremap = true })
vim.keymap.set("x", "gc", "<Nop>", { noremap = true })
vim.keymap.set("o", "gc", "<Nop>", { noremap = true })

return M

