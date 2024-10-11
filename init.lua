-- Set leader key
vim.g.mapleader = " "
pcall(require, "impatient")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Color
vim.o.termguicolors = true

-- Set environment variables within Neovim
local has_openresty = vim.loop.fs_stat("/opt/openresty/luajit")

if has_openresty then
  vim.env.LUAJIT_INC = "/opt/openresty/luajit/include/luajit-2.1"
  vim.env.LUAJIT_LIB = "/opt/openresty/luajit/lib"
end

vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand("$HOME/.cargo/bin")
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand("$HOME/.npm-global/bin")
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand("/usr/bin")
vim.env.PYENV_ROOT = os.getenv("HOME") .. "/.pyenv"
vim.env.PATH = vim.env.PYENV_ROOT .. "/bin:" .. vim.env.PATH

-- Define safe_require function
local function safe_require(module)
  if package.loaded[module] then
    return true, package.loaded[module]
  end
  local success, result = pcall(require, module)
  if not success then
    vim.api.nvim_err_writeln("Error loading " .. module .. ": " .. result)
  end
  return success, result
end

-- Load plugins using lazy.nvim
local plugin_imports = {
    "plugins",
    "plugins.ai",
    "plugins.cloud",
    "plugins.core",
    "plugins.data",
    "plugins.edu",
    "plugins.lang",
    "plugins.nav",
    "plugins.flow",
    "plugins.ui",
}

local plugins = {}
for _, import in ipairs(plugin_imports) do
    if import == "plugins.core" then
        table.insert(plugins, { import = import })
    else
        table.insert(plugins, { import = import, lazy = true })
    end
end
require("lazy").setup(plugins)

-- After the plugin loading code, add this part:
vim.defer_fn(function()
    local builtins_modules = {
        "builtins.init",
        "builtins._meta.code_actions",
    }
    for _, module in ipairs(builtins_modules) do
        safe_require(module)
    end

    local api_modules = {
        "api.command",
    }
    for _, module in ipairs(api_modules) do
        safe_require(module)
    end

    local function load_directory(directory)
        local path = vim.fn.stdpath("config") .. "/lua/" .. directory
        local files = vim.fn.glob(path .. "/*.lua", true, true)
        for _, file in ipairs(files) do
            local module = file:match(".*/lua/(.*)%.lua$"):gsub("/", ".")
            safe_require(module)
        end
    end

    load_directory("helpers")
    safe_require("sources")
    safe_require("autocmds")
    safe_require("options")
    require("mappings")
end, 0)
-- Providers setup
vim.g.node_host_prog = "/usr/bin/node"
vim.g.python3_host_prog = "/usr/bin/python"
vim.g.ruby_host_prog = "/usr/bin/ruby"
vim.g.rustfmt_command = "/usr/bin/rustfmt"
vim.g.jupyter_command = "/usr/bin/jupyter"

-- Set up Lua runtime path for Neovim conditionally for OpenResty
if has_openresty then
  vim.opt.runtimepath:append("/opt/openresty/lualib")
  vim.opt.runtimepath:append("/opt/openresty/luajit/share/luajit-2.1")
end

-- Set up Lua C path for binary modules conditionally for OpenResty
if has_openresty then
  local lua_cpath = table.concat({
    "/opt/openresty/lualib/?.so",
    vim.fn.expand("~/.luarocks/lib/lua/5.1/?.so"),
    package.cpath,
  }, ";")
  package.cpath = lua_cpath
end

-- Set up Lua path for require statements conditionally for OpenResty
if has_openresty then
  local lua_path = table.concat({
    "/opt/openresty/lualib/?.lua",
    "/opt/openresty/lualib/?/init.lua",
    vim.fn.expand("~/.luarocks/share/lua/5.1/?.lua"),
    vim.fn.expand("~/.luarocks/share/lua/5.1/?/init.lua"),
    package.path,
  }, ";")
  package.path = lua_path
end

-- Set up Neovim to use OpenResty's LuaJIT conditionally
if has_openresty then
  vim.g.lua_interpreter_path = "/opt/openresty/luajit/bin/luajit"
end

