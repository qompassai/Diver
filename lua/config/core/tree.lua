-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver TreeSitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

local M = {}

function M.treesitter(opts)
  opts = opts or {}
  require("nvim-treesitter.install").prefer_git = true
  local configs = require("nvim-treesitter.configs")
  local langs = { 'lang.go', 'lang.rust', 'ui.html', 'ui.md' }
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
  local base_config = {
    auto_install = true,
    ensure_installed = {
      'css',
      'go',
      'html',
      'json',
      'json5',
      'lua',
      'markdown',
      'python',
      'rust',
    },
    highlight = {
      additional_vim_regex_highlighting = true,
      enable = true,
    },
    ignore_install = { "ipkg", "norg" },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_decremental = "grm",
        node_incremental = "grn",
        scope_incremental = "grc",
      },
    },
    indent = { enable = true },
    modules = {
      'folke/twilight.nvim',
      'nvim-treesitter/nvim-treesitter-context',
      'nvim-treesitter/playground',
      'SmiteshP/nvim-navic',
      'nvim-treesitter-refactor',
      'nvim-treesitter-textobjects',
      'milisims/tree-sitter-org',
    },
    textobjects = {
      select = {
        enable = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
        },
      },
    },
  }
  local final_config = vim.tbl_deep_extend("force", base_config, merged_lang_opts, opts or {})
  configs.setup(final_config)
  vim.api.nvim_create_autocmd("FileType", {
    desc = "Use Tree-sitter for code folding",
    callback = function()
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end,
  })
end

function M.tree_cfg(opts)
  opts = opts or {}
  M.treesitter(opts)
  return {
    treesitter = vim.tbl_deep_extend("force", M.options and M.options.treesitter or {}, opts),
  }
end

return M
