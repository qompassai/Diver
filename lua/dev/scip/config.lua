-- #################################################################
-- /qompassai/diver/lua/scip/config.lua
-- Qompass AI Diver SCIP Config
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
-- #################################################################
local fs = vim.fs
local M = {}
---@class ScipContext
---@field bufnr integer Buffer being indexed.
---@field filename string Current source filename.
---@field index_file string Resolved SCIP index path.
---@field name string Indexer name.
---@field root string Resolved project root.

---@class ScipIndexer
---@field args string[]|fun(context: ScipContext): string[]
---@field command string|fun(context: ScipContext): string
---@field enabled? boolean
---@field filetypes table<string, boolean>
---@field markers string[]

---@class ScipConfig
---@field index_file string
---@field indexer_order string[]
---@field indexers table<string, ScipIndexer>
---@field lint_after_index boolean
---@field notify boolean
---@field root_markers string[]
---@field timeout integer

---@class ScipConfigOpts
---@field index_file? string
---@field indexer_order? string[]
---@field indexers? table<string, ScipIndexer>
---@field lint_after_index? boolean
---@field notify? boolean
---@field root_markers? string[]
---@field timeout? integer

---Load the built-in SCIP indexers.
---
---Each language-specific indexer definition is inlined below as an
---immediately-invoked function expression returning its `ScipIndexer`
---table, so this module remains responsible only for global SCIP
---configuration.
---
---@return table<string, ScipIndexer>
local function default_indexers()
    return {
        apex = (function()
            --
            ---@source https://github.com/octoberswimmer/scip-apex
            --
            -- Community (third-party, not Salesforce-official) SCIP indexer for Apex.
            -- Like every other indexer in this directory it degrades gracefully: the
            -- registry skips it with an "is not executable" notice when the
            -- `scip-apex` binary is absent, so nothing errors on machines without it.

            --- Arguments passed to scip-apex.
            ---
            --- `index` selects SCIP indexing mode.
            --- `.` indexes the project rooted at the cwd selected by the SCIP framework.
            ---@type string[]
            local args = {
                'index',
                '.',
            }

            ---@type ScipIndexer
            local indexer = {
                args = args,
                command = 'scip-apex',

                filetypes = {
                    apex = true,
                },

                markers = {
                    '.git',
                    '.sf',
                    '.sfdx',
                    'sfdx-project.json',
                },
            }

            return indexer
        end)(),
        clang = (function()
            local utils = require('dev.scip.utils')

            ---Locate the compilation database used by scip-clang.
            ---
            ---The compilation database describes the exact compiler invocation for each
            ---translation unit and is required for accurate C/C++/Objective-C indexing.
            ---
            ---@param context ScipContext SCIP indexing context.
            ---@return string[] args Arguments passed to scip-clang.
            local function args(context)
                return {
                    '--compdb-path=' .. utils.compilation_database(context.root),
                }
            end

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = 'scip-clang',

                filetypes = {
                    c = true,
                    cpp = true,
                    cuda = true,
                    objc = true,
                    objcpp = true,
                },

                markers = {
                    '.git',
                    'CMakeLists.txt',
                    'compile_commands.json',
                    'meson.build',
                },
            }

            return indexer
        end)(),
        dart = (function()
            ---Arguments used to invoke the globally installed scip_dart package.
            ---
            ---The final `.` instructs scip_dart to index the project represented by the
            ---SCIP context's working directory.
            ---
            ---@type string[]
            local args = {
                'pub',
                'global',
                'run',
                'scip_dart',
                '.',
            }

            ---@type ScipIndexer
            local indexer = {
                args = args,
                command = 'dart',
                filetypes = {
                    dart = true,
                },
                markers = {
                    '.git',
                    'analysis_options.yaml',
                    'pubspec.yaml',
                },
            }

            return indexer
        end)(),
        dotnet = (function()
            ---@type ScipIndexer

            local indexer = {
                args = {
                    'index',
                },
                command = 'scip-dotnet',
                filetypes = {
                    cs = true,
                    fsharp = true,
                    vb = true,
                },
                markers = {
                    '.git',
                    'Directory.Build.props',
                    'Directory.Build.targets',
                    'Directory.Packages.props',
                    'global.json',
                },
            }

            return indexer
        end)(),
        go = (function()
            ---scip-go discovers the Go module or workspace from its working directory,
            ---so no additional command-line arguments are required.
            ---@type string[]
            local args = {}

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = 'scip-go',

                filetypes = {
                    go = true,
                    gomod = true,
                    gosum = true,
                    gowork = true,
                },

                markers = {
                    '.git',
                    'go.mod',
                    'go.work',
                },
            }

            return indexer
        end)(),
        java = (function()
            local utils = require('dev.scip.utils')

            ---Return whether a project contains a path.
            ---@param root string Project root.
            ---@param name string Relative path.
            ---@return boolean
            local function has(root, name)
                return utils.path_exists(fs.joinpath(root, name))
            end

            ---Detect the JVM project's build tool.
            ---
            ---scip-java supports Gradle, Maven, and sbt project layouts. Explicit build
            ---tool selection makes indexing more predictable when multiple metadata files
            ---exist in a repository.
            ---
            ---@param root string Project root.
            ---@return 'gradle'|'maven'|'sbt'|nil
            local function build_tool(root)
                if
                    has(root, 'build.gradle')
                    or has(root, 'build.gradle.kts')
                    or has(root, 'gradlew')
                    or has(root, 'settings.gradle')
                    or has(root, 'settings.gradle.kts')
                then
                    return 'gradle'
                end

                if has(root, 'pom.xml') then
                    return 'maven'
                end

                if has(root, 'build.sbt') or has(root, 'project/build.properties') then
                    return 'sbt'
                end

                return nil
            end

            ---Build arguments for scip-java.
            ---
            ---The index subcommand generates `index.scip` in the project working
            ---directory. When the build system can be identified, it is passed
            ---explicitly rather than relying on ambiguous auto-detection.
            ---
            ---@param context ScipContext SCIP indexing context.
            ---@return string[] args Arguments passed to scip-java.
            local function args(context)
                local arguments = {
                    'index',
                }

                local tool = build_tool(context.root)

                if tool ~= nil then
                    arguments[#arguments + 1] = '--build-tool=' .. tool
                end

                return arguments
            end

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = 'scip-java',

                filetypes = {
                    java = true,
                    kotlin = true,
                    scala = true,
                    sbt = true,
                },

                markers = {
                    '.git',
                    'build.gradle',
                    'build.gradle.kts',
                    'build.sbt',
                    'gradlew',
                    'pom.xml',
                    'settings.gradle',
                    'settings.gradle.kts',
                },
            }

            return indexer
        end)(),
        latex = (function()
            ---Native SCIP indexer definition for LaTeX.
            ---
            ---No verified standard LaTeX-to-SCIP indexer is currently available.
            ---Existing LaTeX indexing utilities generally generate document indexes,
            ---rather than SCIP code-intelligence indexes.
            ---
            ---This definition is disabled until a compatible `scip-latex` executable is
            ---installed or implemented.
            ---@type ScipIndexer
            local indexer = {
                args = {
                    'index',
                    '.',
                },

                command = 'scip-latex',

                enabled = true,

                filetypes = {
                    bib = true,
                    latex = true,
                    plaintex = true,
                    tex = true,
                },

                markers = {
                    '.git',
                    '.latexmkrc',
                    'latexmkrc',
                    'texmf.cnf',
                },
            }

            return indexer
        end)(),
        lua = (function()
            ---Native SCIP indexer definition for Lua.
            ---
            ---There is currently no verified standard Lua SCIP indexer comparable to
            ---scip-go or scip-typescript. This definition is therefore disabled by
            ---default and serves as a registration point for a compatible external
            ---`scip-lua` executable.
            ---
            ---Enable this indexer only after installing or implementing a command that
            ---writes a valid SCIP index.
            ---@type ScipIndexer
            local indexer = {
                args = {
                    'index',
                    '.',
                },

                command = 'scip-lua',

                enabled = true,
                filetypes = {
                    lua = true,
                },

                markers = {
                    '.git',
                    '.luarc.json',
                    '.luarc.jsonc',
                    'lua',
                    'rockspec',
                },
            }

            return indexer
        end)(),
        nix = (function()
            ---Native SCIP indexer definition for the Nix language.
            ---
            ---No verified Nix-language SCIP generator is currently available as a
            ---standard SCIP indexer. The fact that parts of the SCIP ecosystem use Nix
            ---for packaging/build infrastructure does not imply that they index Nix
            ---source code.
            ---
            ---This entry remains disabled until a compatible external `scip-nix`
            ---executable is installed or implemented.
            ---@type ScipIndexer
            local indexer = {
                args = {
                    'index',
                    '.',
                },
                command = 'scip-nix',

                enabled = true,

                filetypes = {
                    nix = true,
                },

                markers = {
                    '.git',
                    'default.nix',
                    'flake.lock',
                    'flake.nix',
                    'shell.nix',
                },
            }

            return indexer
        end)(),
        php = (function()
            local utils = require('dev.scip.utils')

            ---Build command-line arguments for scip-php.
            ---
            ---scip-php discovers Composer/project configuration from the working
            ---directory supplied by the native SCIP runner, so no additional arguments
            ---are required for the normal project-indexing case.
            ---
            ---@param _context ScipContext SCIP indexing context.
            ---@return string[] args Arguments passed to scip-php.
            local function args(_context)
                return {}
            end

            ---Resolve the scip-php executable for the current project.
            ---
            ---Composer projects may install scip-php locally under `vendor/bin`.
            ---The project-local executable is preferred so the indexer version follows
            ---the project's dependency lockfile rather than an unrelated global version.
            ---
            ---If no project-local executable exists, the globally available `scip-php`
            ---command is used instead.
            ---
            ---@param context ScipContext SCIP indexing context.
            ---@return string command Resolved scip-php executable.
            local function command(context)
                local local_command = fs.joinpath(context.root, 'vendor', 'bin', 'scip-php')

                if utils.path_exists(local_command) then
                    return local_command
                end

                return 'scip-php'
            end

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = command,

                filetypes = {
                    php = true,
                },

                markers = {
                    '.git',
                    'composer.json',
                    'composer.lock',
                },
            }
            return indexer
        end)(),
        python = (function()
            --- Arguments passed to scip-python.
            ---
            --- `index` selects SCIP indexing mode.
            --- `.` indexes the project rooted at the cwd selected by the SCIP framework.
            ---@type string[]
            local args = {
                'index',
                '.',
            }

            ---@type ScipIndexer
            local indexer = {
                args = args,
                command = 'scip-python',

                filetypes = {
                    python = true,
                },

                markers = {
                    '.git',
                    'Pipfile',
                    'poetry.lock',
                    'pyproject.toml',
                    'pyrightconfig.json',
                    'requirements.txt',
                    'setup.cfg',
                    'setup.py',
                    'uv.lock',
                },
            }

            return indexer
        end)(),
        ruby = (function()
            local utils = require('dev.scip.utils')
            ---Build scip-ruby arguments for the current project.
            ---
            ---Projects containing `sorbet/config` already provide Sorbet's input paths and
            ---configuration, so no explicit project path is needed.
            ---
            ---Projects without `sorbet/config` fall back to indexing the current project
            ---directory using `.`.
            ---
            ---@param context ScipContext SCIP indexing context.
            ---@return string[] args Arguments passed to scip-ruby.
            local function args(context)
                local sorbet_config = fs.joinpath(context.root, 'sorbet', 'config')

                if utils.path_exists(sorbet_config) then
                    return {}
                end

                return {
                    '.',
                }
            end

            ---@type ScipIndexer
            local indexer = {
                args = args,
                command = 'scip-ruby',

                filetypes = {
                    ruby = true,
                },
                markers = {
                    '.git',
                    '.ruby-version',
                    'Gemfile',
                    'Gemfile.lock',
                    'Rakefile',
                    'sorbet',
                },
            }

            return indexer
        end)(),
        rust = (function()
            ---Arguments passed to rust-analyzer.
            ---
            ---rust-analyzer provides SCIP generation directly through:
            ---
            ---    rust-analyzer scip .
            ---
            ---The final `.` indexes the Rust workspace rooted at the cwd selected by the
            ---native SCIP framework.
            ---@type string[]
            local args = {
                'scip',
                '.',
            }

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = 'rust-analyzer',

                filetypes = {
                    rust = true,
                },

                markers = {
                    '.git',
                    'Cargo.lock',
                    'Cargo.toml',
                    'rust-toolchain',
                    'rust-toolchain.toml',
                },
            }

            return indexer
        end)(),
        typescript = (function()
            local utils = require('dev.scip.utils')

            --- Return whether a package.json declares Yarn/npm-style workspaces.
            ---
            --- This deliberately performs only a lightweight JSON inspection. Invalid
            --- package.json content falls back to normal SCIP configuration detection.
            ---@param root string Project root.
            ---@return boolean
            local function has_package_workspaces(root)
                local package_json = fs.joinpath(root, 'package.json')

                if not utils.path_exists(package_json) then
                    return false
                end

                local file = io.open(package_json, 'r')

                if file == nil then
                    return false
                end

                local content = file:read('*a')

                file:close()

                if content == nil or content == '' then
                    return false
                end

                local ok, decoded = pcall(vim.json.decode, content)

                if not ok or type(decoded) ~= 'table' then
                    return false
                end

                return decoded.workspaces ~= nil
            end

            --- Return whether the project is configured as a pnpm workspace.
            ---@param root string Project root.
            ---@return boolean
            local function has_pnpm_workspace(root)
                return utils.path_exists(fs.joinpath(root, 'pnpm-workspace.yaml'))
                    or utils.path_exists(fs.joinpath(root, 'pnpm-workspace.yml'))
            end

            --- Return whether a project contains a TypeScript or JavaScript configuration.
            ---@param root string Project root.
            ---@return boolean
            local function has_tsconfig(root)
                return utils.path_exists(fs.joinpath(root, 'tsconfig.json'))
                    or utils.path_exists(fs.joinpath(root, 'jsconfig.json'))
            end

            --- Build scip-typescript arguments for the current project.
            ---
            --- Resolution order:
            ---
            --- 1. pnpm workspace
            --- 2. package.json workspace
            --- 3. existing tsconfig/jsconfig
            --- 4. inferred configuration
            ---
            --- Explicit workspace modes are preferred when their project metadata clearly
            --- indicates that structure.
            ---@param context ScipContext SCIP indexing context.
            ---@return string[] args Arguments passed to scip-typescript.
            local function args(context)
                local project_root = context.root

                if has_pnpm_workspace(project_root) then
                    return {
                        'index',
                        '--pnpm-workspaces',
                    }
                end

                if has_package_workspaces(project_root) then
                    return {
                        'index',
                        '--yarn-workspaces',
                    }
                end

                if has_tsconfig(project_root) then
                    return {
                        'index',
                    }
                end

                return {
                    'index',
                    '--infer-tsconfig',
                }
            end

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = 'scip-typescript',

                filetypes = {
                    javascript = true,
                    javascriptreact = true,
                    typescript = true,
                    typescriptreact = true,
                },

                markers = {
                    '.git',
                    'bun.lock',
                    'bun.lockb',
                    'deno.json',
                    'deno.jsonc',
                    'jsconfig.json',
                    'package.json',
                    'pnpm-lock.yaml',
                    'pnpm-workspace.yaml',
                    'pnpm-workspace.yml',
                    'tsconfig.json',
                    'yarn.lock',
                },
            }

            return indexer
        end)(),
        zig = (function()
            local utils = require('dev.scip.utils')

            ---@type string[]
            local source_candidates = {
                'src/main.zig',
                'src/lib.zig',
                'main.zig',
                'lib.zig',
            }

            ---Return a filesystem-safe project/package name.
            ---
            ---scip-zig requires both `--pkg` and `--root-pkg`. The repository directory
            ---name provides a deterministic fallback without requiring additional project
            ---configuration.
            ---
            ---@param root string Project root.
            ---@return string
            local function package_name(root)
                local normalized = fs.normalize(root)
                local name = fs.basename(normalized)

                if name == nil or name == '' then
                    return 'root'
                end

                return name
            end

            ---Find the root Zig source file.
            ---
            ---Conventional executable and library entrypoints are checked in priority
            ---order. If none exist, the current Zig buffer is used when it belongs to the
            ---same project.
            ---
            ---@param context ScipContext SCIP indexing context.
            ---@return string
            local function root_source(context)
                for _, relative in ipairs(source_candidates) do
                    local candidate = fs.joinpath(context.root, relative)

                    if utils.path_exists(candidate) then
                        return candidate
                    end
                end

                if
                    context.filename ~= ''
                    and context.filename:match('%.zig$') ~= nil
                    and utils.path_exists(context.filename)
                then
                    return context.filename
                end

                error(
                    'No Zig root source file found under '
                        .. context.root
                        .. '. Expected src/main.zig, src/lib.zig, '
                        .. 'main.zig, or lib.zig.'
                )
            end

            ---Build arguments for scip-zig.
            ---
            ---scip-zig requires an explicit project root, package declaration, source
            ---entrypoint, and root-package declaration.
            ---
            ---@param context ScipContext SCIP indexing context.
            ---@return string[]
            local function args(context)
                local package = package_name(context.root)
                local source = root_source(context)

                return {
                    '--root-path',
                    context.root,
                    '--pkg',
                    package,
                    source,
                    '--root-pkg',
                    package,
                }
            end

            ---@type ScipIndexer
            local indexer = {
                args = args,

                command = 'scip-zig',

                filetypes = {
                    zig = true,
                },

                markers = {
                    '.git',
                    'build.zig',
                    'build.zig.zon',
                },
            }

            return indexer
        end)(),
    }
end

---@type ScipConfig
local defaults = {
    index_file = 'index.scip',
    indexer_order = {
        'apex',
        'clang',
        'dart',
        'dotnet',
        'go',
        'java',
        'latex',
        'lua',
        'nix',
        'php',
        'python',
        'ruby',
        'rust',
        'typescript',
        'zig',
    },

    indexers = default_indexers(),

    lint_after_index = true,

    notify = true,

    root_markers = {
        '.git',
        '.hg',
    },

    timeout = 300000,
}

---@type ScipConfig
M.values = vim.deepcopy(defaults)

---Return the currently active SCIP configuration.
---@return ScipConfig
function M.get()
    return M.values
end

---Resolve the configured SCIP index path for a project.
---
---Absolute paths are preserved. Relative paths are resolved underneath the
---provided project root.
---
---@param root string Project root.
---@return string index_path Resolved SCIP index path.
function M.index_path(root)
    local configured = M.values.index_file

    if configured:sub(1, 1) == '/' then
        return fs.normalize(configured)
    end

    return fs.joinpath(root, configured)
end

---Reset the active configuration to the built-in defaults.
---
---The indexer modules are reloaded from their cached Lua module values through
---`default_indexers()` so the returned configuration is independent from any
---runtime mutations made to `M.values`.
---@return nil
function M.reset()
    defaults.indexers = default_indexers()

    M.values = vim.deepcopy(defaults)
end

---Apply user configuration on top of the built-in defaults.
---
---`vim.tbl_deep_extend()` allows individual indexer settings to be overridden
---without replacing the entire default configuration.
---
---@param opts? ScipConfigOpts User SCIP configuration.
---@return nil
function M.setup(opts)
    opts = opts or {}

    defaults.indexers = default_indexers()

    M.values = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)

    table.sort(M.values.indexer_order)
end

return M
