-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver TreeSitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}

function M.treesitter(opts)
  local ts_ok, configs = pcall(require, 'nvim-treesitter.configs')
  if not ts_ok then return end
  require("nvim-treesitter.install").prefer_git = true
local langs = { 'ui.html', 'ui.md', 'lang.go', 'lang.rust', 'lang.zig' }
local merged_lang_opts = {}

for _, lang_mod in ipairs(langs) do
  local ok, mod = pcall(require, "config." .. lang_mod)
  if ok and type(mod[lang_mod:match("[^.]+$") .. "_treesitter"]) == "function" then
    local ts_cfg = mod[lang_mod:match("[^.]+$") .. "_treesitter"]()
    if ts_cfg then
      merged_lang_opts = vim.tbl_deep_extend("force", merged_lang_opts, ts_cfg)
    end
  end
end
  local parser_path = vim.fn.stdpath("data") .. "/parsers"
  vim.opt.runtimepath:prepend(parser_path)
  local exclude = { "ipkg" }
  local default_opts = {
    ensure_installed = 'all',
    sync_install = true,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = true,
      disable = function(_, buf)
        local max_filesize = 100 * 1024
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        return ok and stats and stats.size > max_filesize
      end,
    },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_incremental = "grn",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
    },
  }
  local merged = vim.tbl_deep_extend("force", default_opts, opts or {})
  configs.setup(merged)
  vim.api.nvim_create_autocmd("FileType", {
    desc = "Use Tree-sitter for code folding",
    callback = function()
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end,
  })
end

function M.tree_cfg(opts)
	require("lazy").setup({
  {"nvim-treesitter/nvim-treesitter", branch = 'master', lazy = false, build = ":TSUpdate"}
})
  opts = opts or {}
  M.treesitter(opts)
  return {
    treesitter = vim.tbl_deep_extend("force", M.options.treesitter or {}, opts),
  }
end

return M
