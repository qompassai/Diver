-- Set leader key
vim.g.mapleader = " "
vim.keymap.set("n", "gc", "<Nop>", { noremap = true })
vim.keymap.set("n", "gcc", "<Nop>", { noremap = true })
vim.keymap.set("x", "gc", "<Nop>", { noremap = true })
vim.keymap.set("o", "gc", "<Nop>", { noremap = true })

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    local repo = "https://github.com/folke/lazy.nvim.git"
    vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end
vim.opt.rtp:prepend(lazypath)

-- providers

-- Node.js Provider
vim.g.npm_host_prog = vim.fn.expand("~/.npm-global/bin/neovim-node-host")
-- Perl Provider
vim.g.perl_host_prog = vim.fn.expand("/usr/bin/perl")

-- Ruby Provider
vim.g.ruby_host_prog = vim.fn.expand("/usr/bin/ruby")
vim.opt.rtp:append(vim.fn.stdpath "config" .. "/lua/providers")
-- Color settings
vim.o.termguicolors = true

-- disable whichkey
vim.g.which_key_disable_health_check = 1

-- Define safe_require function
local function safe_require(module)
    if package.loaded[module] then
        return true, package.loaded[module]
    end
    local success, result = pcall(require, module)
    if not success then
        local error_message = type(result) == "table" and vim.inspect(result) or result
        vim.api.nvim_err_writeln("Error loading " .. module .. ": " .. error_message)
    end
    return success, result
end

-- Define load_directory function
local function load_directory(directory)
    local path = vim.fn.stdpath("config") .. "/lua/" .. directory
    local files = vim.fn.glob(path .. "/*.lua", true, true)
    for _, file in ipairs(files) do
        local module = file:match(".*/lua/(.*)%.lua$")
        if module then
            module = module:gsub("/", ".")
            safe_require(module)
        else
            print("Warning: Could not match module name for file: " .. file)
        end
    end
end

-- Environment Variables
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand "/usr/cargo/bin"
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand "~/.cargo/bin"
vim.env.CARGO_HOME = vim.fn.expand "~/.cargo"
vim.env.RUSTUP_HOME = vim.fn.expand "~/.rustup"
vim.env.CC = "clang"
vim.env.CXX = "clang++"
vim.env.LD = "lld"
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand "$HOME/.npm-global/bin"
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand "/usr/bin"
vim.env.PYENV_ROOT = os.getenv "HOME" .. "/.pyenv"
vim.env.PATH = vim.env.PYENV_ROOT .. "/bin:" .. vim.env.PATH

-- Import Plugins
local plugin_imports = {
    "plugins.core",
    "plugins.ai",
    "plugins.cloud",
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
        table.insert(plugins, { import = import, lazy = false })
    end
end
require("lazy").setup(plugins)

-- Load Additional Configurations
load_directory "helpers"
safe_require "sources"
safe_require "autocmds"
safe_require "options"
safe_require "mappings"


-- System Language Providers Configuration

------------------------ | System Language Providers | ------------------------

------------------------------- | C/C++ | -------------------------------
vim.g.c_host_prog = "/usr/bin/gcc"
vim.g.cpp_host_prog = "/usr/bin/g++"
vim.g.c_host_prog = "/usr/bin/clang"
vim.g.cpp_host_prog = "/usr/bin/clang++"
------------------------------- | C/C++ | -------------------------------

-------------------------- | C# (Mono or .NET) | --------------------------
vim.g.cs_host_prog = "/usr/bin/csharp"
vim.g.dotnet_host_prog = "/usr/bin/dotnet"
-------------------------- | C# (Mono or .NET) | --------------------------

----------------------------- | Erlang | -----------------------------
vim.g.erlang_host_prog = "/usr/bin/erl"
----------------------------- | Erlang | -----------------------------

----------------------------- | Fortran | -----------------------------
vim.g.fortran_host_prog = "/usr/bin/gfortran"
----------------------------- | Fortran | -----------------------------

------------------------------- | Go | -------------------------------
vim.g.go_host_prog = "/usr/bin/go"
------------------------------- | Go | -------------------------------

------------------------------- | GPG | -------------------------------
vim.g.gpg_host_prog = "/usr/bin/gpg"
------------------------------- | GPG | -------------------------------

----------------------------- | Haskell | -----------------------------
vim.g.haskell_host_prog = "/usr/bin/ghci"
----------------------------- | Haskell | -----------------------------

------------------------------- | Java | -------------------------------
vim.g.java_host_prog = "/usr/bin/java"
------------------------------- | Java | -------------------------------

---------------------- | JavaScript/Node.js | --------------------------

if not vim.fn.executable('nvm') == 1 then
    print("NVM is not installed. Attempting to install...")
    os.execute('curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash')
end

local nvm_dir = vim.fn.expand('$HOME/.nvm')
local nvm_sh = nvm_dir .. '/nvm.sh'

if vim.fn.filereadable(nvm_sh) == 1 then
    -- Get the current Node.js version managed by NVM
    local current_version = vim.fn.system('bash -c "source ' .. nvm_sh .. ' && nvm current"'):gsub('\n', '')

    if current_version and current_version ~= "none" and current_version ~= "" then
        local nvm_bin_path = nvm_dir .. "/versions/node/" .. current_version .. "/bin"
        vim.env.PATH = nvm_bin_path .. ":" .. vim.env.PATH
    else
        print("NVM is installed, but no Node.js version is currently in use.")
    end
else
    print("NVM is not installed properly. Please check your installation.")
end

---------------------- | JavaScript/Node.js | --------------------------

------------------------------- | Lua Configuration | --------------------------------
vim.g.lua_host_prog = vim.fn.expand("~/.hererocks/bin/lua")
vim.env.PATH = vim.fn.expand("~/.hererocks/bin") .. ":" .. vim.env.PATH

package.path = table.concat({
    vim.fn.expand("~/.hererocks/share/lua/5.1/?.lua"),
    vim.fn.expand("~/.hererocks/share/lua/5.1/?/init.lua"),
    "/usr/share/lua/5.1/?.lua",
    "/usr/share/lua/5.1/?/init.lua",
    vim.fn.expand("~/.luarocks/share/lua/5.1/?.lua"),
    vim.fn.expand("~/.luarocks/share/lua/5.1/?/init.lua"),
    package.path,
}, ";")

package.cpath = table.concat({
    vim.fn.expand("~/.hererocks/lib/lua/5.1/?.so"),
    "/usr/lib/lua/5.1/?.so",
    vim.fn.expand("~/.luarocks/lib/lua/5.1/?.so"),
    package.cpath,
}, ";")
------------------- | Lua OpenResty Integration (Conditional) | -------------------
local has_openresty = vim.loop.fs_stat("/opt/openresty/luajit")

if has_openresty then
    vim.opt.runtimepath:append("/opt/openresty/lualib")
    vim.opt.runtimepath:append("/opt/openresty/luajit/share/luajit-2.1")

    package.cpath = table.concat({
        "/opt/openresty/lualib/?.so",
        vim.fn.expand("~/.luarocks/lib/lua/5.1/?.so"),
        package.cpath,
    }, ";")

    package.path = table.concat({
        "/opt/openresty/lualib/?.lua",
        "/opt/openresty/lualib/?/init.lua",
        vim.fn.expand("~/.luarocks/share/lua/5.1/?.lua"),
        vim.fn.expand("~/.luarocks/share/lua/5.1/?/init.lua"),
        package.path,
    }, ";")

    vim.g.lua_host_prog = "/opt/openresty/luajit/bin/luajit"
end
------------------- | Lua OpenResty Integration (Conditional) | -------------------

------------------------------- | Lua | -------------------------------
vim.g.lua_host_prog = "/usr/bin/lua5.1"
------------------------------- | Lua | -------------------------------

------------------------------ | OCaml | ------------------------------
vim.g.ocaml_host_prog = "/usr/bin/ocaml"
------------------------------ | OCaml | ------------------------------

------------------------------ | Perl | ------------------------------
vim.g.perl_host_prog = "/usr/bin/perl"
------------------------------ | Perl | ------------------------------

------------------------------ | PHP | ------------------------------
vim.g.php_host_prog = "/usr/bin/php"
------------------------------ | PHP | ------------------------------

--------------------------- | PostgreSQL | ---------------------------
vim.g.postgres_host_prog = "/usr/bin/psql"
--------------------------- | PostgreSQL | ---------------------------

----------------------------- | Python | -----------------------------
vim.g.python3_host_prog = "/usr/bin/python3"
----------------------------- | Python | -----------------------------

-------------------------------- | R | --------------------------------
vim.g.r_host_prog = "/usr/bin/R"
-------------------------------- | R | --------------------------------

------------------------------ | Ruby | ------------------------------
vim.g.ruby_host_prog = "/usr/bin/ruby"
------------------------------ | Ruby | ------------------------------

------------------------------ | Rust | ------------------------------
vim.g.rustc_host_prog = "/usr/bin/rustc"
vim.g.rustfmt_command = "/usr/bin/rustfmt"
------------------------------ | Rust | ------------------------------

------------------------------ | Swift | ------------------------------
vim.g.swift_host_prog = "/usr/bin/swift"
------------------------------ | Swift | ------------------------------

------------------------------- | Zig | -------------------------------
vim.g.zig_host_prog = "/usr/local/bin/zig"
------------------------------- | Zig | -------------------------------

----------------- | Jupyter (for IPython Notebook) | -----------------
vim.g.jupyter_command = "/usr/bin/jupyter"
----------------- | Jupyter (for IPython Notebook) | -----------------
--Spell-check
vim.opt.spell = true
vim.opt.spelllang = "en_us"
