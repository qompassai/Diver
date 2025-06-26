--~/.config/nvim/lua/config/init.lua
---@module 'config.init'
---@class ConfigInitModule
---@field setup_all fun(opts?: table): nil

local M = {}

---@param opts? table
---@return nil
function M.setup_all(opts)
  opts = opts or {}
  local core = require("config.core")
  core.setup_all_core(opts)
  local lang = require("config.lang")
  lang.setup_all_lang(opts)
  local ui = require("config.ui")
  ui.setup_all_ui(opts)
  local cicd = require("config.cicd")
  cicd.setup_all_cicd(opts)
  pcall(function()
    local cloud = require("config.cloud")
    if cloud.setup_all_cloud then
      cloud.setup_all_cloud(opts)
    end
  end)
end

---@return ConfigInitModule
return M
