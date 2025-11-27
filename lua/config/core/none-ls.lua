-- /qompassai/Diver/lua/config/core/none-ls.lua
-- Qompass AI None-LS Plugin Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
local M = {}
local function collect_from(modname)
  local ok, mod = pcall(require, modname)
  if not ok then
    print("Failed to require: " .. modname)
    return {}
  end
  local sources = {}
  if type(mod.nls) == "function" then
    local ok2, val = pcall(mod.nls)
    if ok2 and type(val) == "table" then
      for _, v in ipairs(val) do
        if v ~= nil then
          table.insert(sources, v)
        end
      end
    end
    return sources
  end
  if type(mod.nls_sources) == "function" then
    local ok2, val = pcall(mod.nls_sources)
    if ok2 and type(val) == "table" then
      for _, v in ipairs(val) do
        if v ~= nil then
          table.insert(sources, v)
        end
      end
    end
    return sources
  end
  print("Empty or invalid for " .. modname)
  return {}
end

function M.nls_extras()
  return {
    require("none-ls-shellcheck.diagnostics"),
    require("none-ls-shellcheck.code_actions"),
    require("none-ls-luacheck.diagnostics.luacheck"),
    require("none-ls-php.diagnostics.php"),
    require("none-ls-ecs.formatting"),
    require("none-ls-external-sources.diagnostics.eslint"),
    require("none-ls-external-sources.diagnostics.eslint_d"),
    require("none-ls-external-sources.diagnostics.flake8"),
    require("none-ls-external-sources.diagnostics.luacheck"),
    require("none-ls-external-sources.diagnostics.psalm"),
    require("none-ls-external-sources.diagnostics.yamllint"),
    require("none-ls-external-sources.formatting.autopep8"),
    require("none-ls-external-sources.formatting.beautysh"),
    require("none-ls-external-sources.formatting.easy-coding-standard"),
    require("none-ls-external-sources.formatting.eslint"),
    require("none-ls-external-sources.formatting.eslint_d"),
    require("none-ls-external-sources.formatting.jq"),
    require("none-ls-external-sources.formatting.latexindent"),
    require("none-ls-external-sources.formatting.reformat_gherkin"),
    require("none-ls-external-sources.formatting.rustfmt"),
    require("none-ls-external-sources.formatting.standardrb"),
    require("none-ls-external-sources.formatting.yq"),
    require("none-ls-external-sources.code_actions.eslint"),
    require("none-ls-external-sources.code_actions.eslint_d"),
    require("none-ls-external-sources.code_actions.shellcheck"),
  }
end

function M.nls_cfg(opts)
  opts = opts or {}
  local null_ls = require("null-ls")
  local sources = {
    null_ls.builtins.formatting.fish_indent,
    null_ls.builtins.diagnostics.fish,
    null_ls.builtins.formatting.stylua,
    null_ls.builtins.formatting.shfmt,
  }
  local langs = { "go", "lua", "nix", "rust", "python", "ts", "php" }
  for _, l in ipairs(langs) do
    vim.list_extend(sources, collect_from("config.lang." .. l))
  end
  local ui = { "md", "css", "html" }
  for _, u in ipairs(ui) do
    vim.list_extend(sources, collect_from("config.ui." .. u))
  end
  local cicd = { "ansible" }
  for _, c in ipairs(cicd) do
    vim.list_extend(sources, collect_from("config.cicd." .. c))
  end
  local data = { "psql", "sqlite" }
  for _, d in ipairs(data) do
    vim.list_extend(sources, collect_from("config.data." .. d))
  end
  vim.list_extend(sources, M.nls_extras())
  if opts.sources then
    vim.list_extend(sources, opts.sources)
  end
  local filtered_sources = {}
  for i, src in ipairs(sources) do
    if src ~= nil then
      table.insert(filtered_sources, src)
    else
      print("Nil source at index " .. i)
    end
  end
  opts.root_dir = opts.root_dir
    or require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json5", "Makefile", ".git")

  null_ls.setup(vim.tbl_deep_extend("force", {
    sources = filtered_sources,
  }, opts))
end

return M
