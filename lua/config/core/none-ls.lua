-- /qompassai/Diver/lua/config/core/none-ls.lua
-- Qompass AI None-LS Plugin Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
local M = {}

function M.nls_extras()
  local extras = {
    require("none-ls-shellcheck.diagnostics.shellcheck"),
    require("none-ls-luacheck.diagnostics.luacheck"),
    require("none-ls-php.code_actions.php"),
    require("none-ls-php.formatting.php_cs_fixer"),
    require("none-ls-ecs.formatting.ecs"),
    require("none-ls-extras.formatting.prettierd"),
    require("none-ls-extras.formatting.eslint_d"),
    require("none-ls-extras.diagnostics.ruff"),
  }
   local has_lua, lua_cfg = pcall(require, "config.lang.lua")
  if has_lua then
    local lua_sources = lua_cfg.go_cfg().nls or {}
    vim.list_extend(extras, lua_sources)
  else
    vim.notify("[none-ls] Go config not loaded", vim.log.levels.WARN)
  end
 local has_go, go_cfg = pcall(require, "config.lang.go")
  if has_go then
    local go_sources = go_cfg.go_cfg().nls or {}
    vim.list_extend(extras, go_sources)
  else
    vim.notify("[none-ls] Go config not loaded", vim.log.levels.WARN)
  end

  local has_nix, nix_cfg = pcall(require, "config.lang.nix")
  if has_nix then
    local nix_sources = nix_cfg.nix_cfg().nls or {}
    vim.list_extend(extras, nix_sources)
  else
    vim.notify("[none-ls] Nix config not loaded", vim.log.levels.WARN)
  end
   local has_rust, rust_cfg = pcall(require, "config.lang.rust")
  if has_rust then
    local rust_sources = rust_cfg.rust_cfg().nls or {}
    vim.list_extend(extras, rust_sources)
  else
    vim.notify("[none-ls] Rust config not loaded", vim.log.levels.WARN)
  end

  return extras
end

return M

