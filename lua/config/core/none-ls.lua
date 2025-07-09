-- /qompassai/Diver/lua/config/core/none-ls.lua
-- Qompass AI None-LS Plugin Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
local M = {}
local function collect_from(modname)
  local ok, mod = pcall(require, modname)
  if not ok then return {} end
  if type(mod.nls) == "function" then return mod.nls() end
  if type(mod.nls_sources) == "function" then return mod.nls_sources() end
  return {}
end

function M.nls_extras()
  return {
    require('none-ls-shellcheck.diagnostics'),
    require("none-ls-shellcheck.code_actions"),
    require('none-ls-luacheck.diagnostics.luacheck'),
    require("none-ls-php.diagnostics.php"),
    require("none-ls-ecs.formatting"),
  }
end

function M.nls_cfg(opts)
  opts = opts or {}
  local null_ls = require('null-ls')
  local sources = {
    null_ls.builtins.formatting.fish_indent,
    null_ls.builtins.diagnostics.fish,
    null_ls.builtins.formatting.stylua,
    null_ls.builtins.formatting.shfmt,
  }
  local langs = { "go", "lua", "nix", "rust", "python", "java", "scala", "typescript", "javascript", "php", "zig", "mojo" }
  for _, l in ipairs(langs) do
    vim.list_extend(sources, collect_from("config.lang." .. l))
  end
  local ui = { "css", "html", "md", "themes", "icons" }
  for _, u in ipairs(ui) do
    vim.list_extend(sources, collect_from("config.ui." .. u))
  end
  local cicd = { "ansible", "git", "shell", "containers" }
  for _, c in ipairs(cicd) do
    vim.list_extend(sources, collect_from("config.cicd." .. c))
  end
  local data = { "sqlite", "psql", "csv", "dadbod", "rego" }
  for _, d in ipairs(data) do
    vim.list_extend(sources, collect_from("config.data." .. d))
  end
  vim.list_extend(sources, M.nls_extras())
  if opts.sources then
    vim.list_extend(sources, opts.sources)
  end
  opts.root_dir = opts.root_dir or require("null-ls.utils").root_pattern(
    ".null-ls-root", ".neoconf.json", "Makefile", ".git"
  )
  null_ls.setup(vim.tbl_deep_extend("force", {
    sources = sources,
  }, opts))
end
return M
