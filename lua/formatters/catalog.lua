-- #################################################################
-- ~/.config/nvim/lua/formatters/catalog.lua
-- Trusted formatter package metadata and installation recipes
-- #################################################################
local fs = vim.fs
local root = fs.joinpath(vim.fn.stdpath('data'), 'formatter-toolchains')

local M = {
  root = root,
  paths = {
    fs.joinpath(root, 'bin'),
    fs.joinpath(root, 'cargo', 'bin'),
    fs.joinpath(root, 'composer', 'vendor', 'bin'),
  },
  entries = {},
}

local function github(repository)
  return {
    url = 'https://api.github.com/repos/' .. repository .. '/releases/latest',
    field = 'tag_name',
  }
end

local function cargo(name, crate, repository)
  M.entries[name] = {
    source = {
      url = 'https://crates.io/api/v1/crates/' .. crate,
      field = 'crate.max_stable_version',
    },
    probe = function(command)
      return { command, '--version' }
    end,
    url = 'https://github.com/' .. repository,
    install = function(version)
      return {
        argv = {
          'cargo',
          'install',
          '--locked',
          '--version',
          version,
          '--root',
          fs.joinpath(root, 'cargo'),
          crate,
        },
      }
    end,
  }
end

local function go_tool(name, module, package_path, version_args)
  M.entries[name] = {
    source = {
      url = 'https://proxy.golang.org/' .. module .. '/@latest',
      field = 'Version',
    },
    probe = function(command)
      if version_args then
        local argv = { command }
        vim.list_extend(argv, version_args)
        return argv
      end
      return { 'go', 'version', '-m', command }
    end,
    build_info = version_args == nil,
    url = 'https://pkg.go.dev/' .. package_path,
    install = function(version)
      return {
        argv = { 'go', 'install', package_path .. '@v' .. version },
        env = {
          GOBIN = fs.joinpath(root, 'bin'),
          GOTOOLCHAIN = 'local',
        },
      }
    end,
  }
end

local function npm_api(name, package_name, directory_name, pin)
  local prefix = fs.joinpath(vim.fn.stdpath('data'), 'formatters', directory_name)
  M.entries[name] = {
    private = true,
    pin = pin,
    manifest = fs.joinpath(prefix, 'node_modules', package_name, 'package.json'),
    source = {
      url = 'https://registry.npmjs.org/' .. package_name .. '/latest',
      field = 'version',
    },
    url = 'https://www.npmjs.com/package/' .. package_name,
    install = function(version)
      return {
        argv = {
          'npm',
          'install',
          '--prefix',
          prefix,
          '--ignore-scripts',
          '--no-audit',
          '--no-fund',
          '--save-exact',
          package_name .. '@' .. version,
        },
      }
    end,
  }
end

cargo('alejandra', 'alejandra', 'kamadorueda/alejandra')
cargo('dioxus', 'dioxus-cli', 'DioxusLabs/dioxus')
cargo('stylua', 'stylua', 'JohnnyMorganz/StyLua')
cargo('shellharden', 'shellharden', 'anordal/shellharden')

go_tool('goimports', 'golang.org/x/tools', 'golang.org/x/tools/cmd/goimports')
go_tool('gofumpt', 'mvdan.cc/gofumpt', 'mvdan.cc/gofumpt', { '--version' })
go_tool('shfmt', 'mvdan.cc/sh/v3', 'mvdan.cc/sh/v3/cmd/shfmt', { '--version' })

npm_api('wgslfmt', '@wasm-fmt/wgslfmt', 'wgslfmt', '0.1.0')
npm_api('bibtex_tidy', 'bibtex-tidy', 'bibtex-tidy', '1.15.1')

M.entries.clang_format = {
  source = github('llvm/llvm-project'),
  probe = function(command)
    return { command, '--version' }
  end,
  arch_package = 'clang',
  url = 'https://clang.llvm.org/docs/ClangFormat.html',
  instructions = 'Install clang-format through your LLVM package manager.',
}

M.entries.phpcsfixer = {
  source = github('PHP-CS-Fixer/PHP-CS-Fixer'),
  probe = function(command)
    return { command, '--version' }
  end,
  url = 'https://github.com/PHP-CS-Fixer/PHP-CS-Fixer',
  install = function(version)
    return {
      argv = {
        'composer',
        'global',
        'require',
        '--no-interaction',
        '--no-scripts',
        '--no-plugins',
        'friendsofphp/php-cs-fixer:' .. version,
      },
      env = {
        COMPOSER_HOME = fs.joinpath(root, 'composer'),
      },
    }
  end,
}

local ktfmt_root = fs.joinpath(vim.fn.stdpath('data'), 'formatters', 'ktfmt')
local ktfmt_jar = fs.joinpath(ktfmt_root, 'ktfmt-0.64-with-dependencies.jar')

M.entries.ktfmt = {
  private = true,
  pin = '0.64',
  files = {
    ktfmt_jar,
    fs.joinpath(ktfmt_root, 'KtfmtStdin.java'),
  },
  source = github('Kotlin/ktfmt'),
  probe = function(command)
    return { command, '-jar', ktfmt_jar, '--version' }
  end,
  url = 'https://github.com/Kotlin/ktfmt/releases/tag/v0.64',
  instructions = 'Use the pinned ktfmt installation instructions supplied '
    .. 'with your adapter. Both the JAR and KtfmtStdin.java are required. '
    .. 'Updating the JAR alone may break the adapter.',
}

---@param name string
---@param entry table
function M.register(name, entry)
  assert(name:match('^[%w_-]+$'), 'Invalid formatter name')
  assert(type(entry) == 'table', 'Metadata must be a table')
  M.entries[name] = entry
end

return M
