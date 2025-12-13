-- /qompassai/Diver/lua/utils/lang/lua.lua
-- Qompass AI Lua Lang Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local U = {}

local defaults = {
  [".stylua.toml"] = [[
# Default style for Stylua when no project override exists
column_width = 120
indent_type  = "Spaces"
indent_width = 2
line_endings = "Unix"
quote_style  = "AutoPreferSingle"
]],
}

---@param dir string destination directory
local function ensure_files(dir)
  for name, body in pairs(defaults) do
    local path = dir .. "/" .. name
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile(vim.split(body, "\n"), path)
    end
  end
end


---@return string absolute path to ~/.config/lua
function U.lua_home()
  local cfg_root = vim.fn.stdpath("config"):gsub("/nvim$", "")
  local dir      = cfg_root .. "/lua"
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end
  ensure_files(dir)
  if not vim.o.runtimepath:find(dir, 1, true) then
    vim.opt.runtimepath:prepend(dir)
  end
  local glob = dir .. "/?.lua;" .. dir .. "/?/init.lua;"
  if not package.path:find(dir, 1, true) then
    package.path = glob .. package.path
  end
  return dir
end

---@param filenames string|string[] names to look for
---@return string|nil               absolute path or nil
function U.find_config(filenames)
  local util     = require("lspconfig.util")
  local cwd_file = vim.fn.expand("%:p")
  local root     = util.root_pattern(".git", ".hg", ".svn",
    "package.json", ".luarc.json")(cwd_file)
  filenames      = type(filenames) == "table" and filenames or { filenames }

  if root then
    local path = vim.fs.find(filenames, { upward = true, path = root })[1]
    if path then return path end
  end

  local lua_home = U.lua_home()
  for _, name in ipairs(filenames) do
    local path = lua_home .. "/" .. name
    if vim.fn.filereadable(path) == 1 then return path end
  end
end

local _local_versions = { "luajit", "lua54", "lua53", "lua52", "lua51" }

---@return string name, string path
function U.lua_version()
  for _, v in ipairs(_local_versions) do
    local p = vim.fn.expand("$HOME/.local/" .. v .. "/bin/lua")
    if vim.fn.filereadable(p) == 1 then return v, p end
  end
  for _, name in ipairs({
    "lua5.4", "lua5.3", "lua5.2", "lua5.1",
    "lua54", "lua53", "lua52", "lua51",
    "luajit", "lua",
  }) do
    local p = vim.fn.exepath(name)
    if p ~= "" then return name, p end
  end
  return "lua", "/usr/bin/lua"
end

---@param extra table[]|nil additional library entries
function U.lua_library(extra)
  local list = {
    { path = "${3rd}/luv/library",                  words = { "vim%.uv" } },
    { path = tostring(vim.fn.expand("$VIMRUNTIME")) },
    { path = vim.fn.stdpath("config") .. "/lua" },
    { path = vim.fn.stdpath("data") .. "/lazy" },
  }
  if extra then vim.list_extend(list, extra) end
  return list
end

---@return string[]      runtime path patterns
function U.lua_runtime(lua_path)
  return vim.tbl_filter(function(x) return x end, {
    "?.lua", "?/init.lua",
    lua_path and (lua_path .. "/share/lua/5.4/?.lua"),
    lua_path and (lua_path .. "/share/lua/5.4/?/init.lua"),
    lua_path and (lua_path .. "/share/lua/5.1/?.lua"),
    lua_path and (lua_path .. "/share/lua/5.1/?/init.lua"),
    vim.fn.stdpath("config") .. "/lua/?.lua",
    vim.fn.stdpath("config") .. "/lua/?/init.lua",
  })
end

return U
