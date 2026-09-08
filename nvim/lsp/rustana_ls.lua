-- #################################################################
-- /qompassai/diver/lsp/rustana_ls.lua
-- Qompass AI Diver Rustana Ls
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
---@source https://rust-analyzer.github.io/book/index.html
--[[
---@param fname string
local function is_library(fname) ---@return string|nil
  local user_home = vim.fs.normalize(vim.env.HOME)
  local cargo_home = os.getenv('CARGO_HOME') or (user_home .. '/.cargo')
  local registry = cargo_home .. '/registry/src'
  local git_registry = cargo_home .. '/git/checkouts'
  local rustup_home = os.getenv('RUSTUP_HOME') or (user_home .. '/.rustup')
  local toolchains = rustup_home .. '/toolchains'

  for _, item in ipairs({ toolchains, registry, git_registry }) do
    if vim.fs.relpath(item, fname) then
      local clients = vim.lsp.get_clients({ name = 'rust_analyzer' }) ---@type vim.lsp.Client[]
      return #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end
--]]
return ---@type vim.lsp.Config
{
    cmd = {
        'rust-analyzer',
    },
    filetypes = {
        'rust',
    },
    root_markers = {
        'Cargo.toml',
        'rust-project.json',
        '.git',
    },

    capabilities = {
        experimental = {
            serverStatusNotification = true,
            commands = {
                commands = {
                    'rust-analyzer.debugSingle',
                    'rust-analyzer.runSingle',
                    'rust-analyzer.showReferences',
                },
            },
        },
    },
    settings = {
        ['rust-analyzer'] = {
            assist = {
                emitMustUse = true,
                expressionFillDefault = false,
                preferSelf = false,
                termSearch = {
                    borrwcheck = true,
                    fuel = 1800,
                },
            },
            cachePriming = {
                enable = true,
                numThreads = 'physical',
            },
            cargo = {
                alltargets = true,
                autoreload = true,
                buildScripts = {
                    enable = true,
                    nvocationStrategy = 'per_workspace',
                    overrideCommand = nil,
                    rebuildOnSave = true,
                    useRustcWrapper = true,
                },
                cfgs = {
                    'debug_assertions',
                    'miri',
                },
                extraArgs = {},
                extraEnv = {},
                features = 'all',
                noDefaultFeatures = false,
                noDeps = false,
                sysroot = 'discover',
                sysrootSrc = {},
                target = {},
                targetDir = {},
            },
            cfg = {
                setTest = true,
            },
            check = {
                allTargets = nil,
                command = 'clippy',
                extraArgs = {
                    '--all-targets',
                },
                extraEnv = {
                    '-C target-cpu=native -C debuginfo=2',
                },
                features = 'all',
                ignore = {},
                invocationStrategy = 'per_workspace',
                noDefaultFeatures = {},
                overrideCommand = {},
                targets = {},
                workspace = {},
            },
            checkOnSave = false, ---handled by bacon-ls
            completion = {
                addSemicolonToUnit = true,
                autoAwait = {
                    enable = true,
                },
                autoIter = {
                    enable = true,
                },
                autoImport = {
                    enable = true,
                    exclude = {
                        {
                            path = 'core::borrow::Borrow',
                            type = 'methods',
                        },
                        {
                            path = 'core::borrow::BorrowMut',
                            type = 'methods',
                        },
                    },
                },
                autoself = {
                    enable = true,
                },
                callable = {
                    snippts = 'fill_arguments',
                },
                excludeTraits = {},
                fullFunctionSignatures = {
                    enable = true,
                },
                hideDeprecated = false,
                limit = 'None',
                postfix = {
                    enable = true,
                },
                privateEditable = {
                    enable = true,
                },
                snippets = {
                    custom = {
                        custom = {
                            ['Ok'] = {
                                postfix = 'ok',
                                body = 'Ok(${receiver})',
                                description = 'Wrap the expression in a `Result::Ok`',
                                scope = 'expr',
                            },
                            ['Box::pin'] = {
                                postfix = 'pinbox',
                                body = 'Box::pin(${receiver})',
                                requires = 'std::boxed::Box',
                                description = 'Put the expression into a `Result::Ok`',
                                scope = 'expr',
                            },
                            ['Arc::new'] = {
                                postfix = 'arc',
                                body = 'Arc::new(${receiver})',
                                requires = 'std::sync::Arc',
                                description = 'Put the expression into an `Arc`',
                                scope = 'expr',
                            },
                            ['Some'] = {
                                postfix = 'some',
                                body = 'Some(${receiver})',
                                description = 'Wrap the expression in an `Option::Some`',
                                scope = 'expr',
                            },
                            ['Err'] = {
                                postfix = 'err',
                                body = 'Err(${receiver})',
                                description = 'Wrap the expression in a `Result::Err`',
                                scope = 'expr',
                            },
                            ['Rc::new'] = {
                                postfix = 'rc',
                                body = 'Rc::new(${receiver})',
                                requires = 'std::rc::Rc',
                                description = 'Put the expression into an `Rc`',
                                scope = 'expr',
                            },
                        },
                    },
                },
                termSearch = {
                    enable = true,
                    fuel = 1000,
                },
            },
            diagnostics = {
                disabled = {},
                enable = false, ---handled by bacon-ls
                expertimental = {
                    enable = true,
                },
                remapPrefix = {},
                styleLints = {
                    enable = true,
                },
                warningsAsHint = {},
                warningsAsInfo = {},
            },
            document = {
                symbol = {
                    search = {
                        excludeLocals = true,
                    },
                },
            },
            files = {
                exclude = {},
                watcher = 'client',
            },
            gotoImplementations = {
                filterAdjacentDerives = true,
            },
            highlightRelated = {
                brachExitPoints = {
                    enable = true,
                },
                breakPoints = {
                    enable = true,
                },
                closureCaptures = {
                    enable = true,
                },
                exitPoints = {
                    enable = true,
                },
                references = {
                    enable = true,
                },
                yieldpoints = {
                    enable = true,
                },
            },
            hover = {
                actions = {
                    debug = {
                        enable = true,
                        implementations = {
                            enable = true,
                        },
                    },
                    enable = true,
                    gotoTypeDef = {
                        enable = true,
                    },
                    implementations = {
                        enable = true,
                    },
                    references = {
                        enable = true,
                    },
                    run = {
                        enable = true,
                    },
                },
                documentation = {
                    enable = true,
                    keywords = {
                        enable = true,
                    },
                },
                links = {
                    enable = true,
                },
                memoryLayout = {
                    alignment = 'hexadecimal',
                    enable = true,
                    niches = true,
                    offset = 'hexadecimal',
                    size = 'both',
                },
            },
            imports = {
                granularity = {
                    enforce = true,
                    group = 'crate',
                },
                groups = {
                    enable = true,
                },
                merge = {
                    glob = true,
                },
                preferNoStd = false,
                preferPrelude = false,
                prefix = 'plain',
            },
            inlayHints = {
                bindingModeHints = {
                    enable = true,
                },
                chainingHints = {
                    enable = true,
                },
                closingBraceHints = {
                    minLines = 0,
                    enable = true,
                },
                closureCaptureHints = {
                    enable = true,
                },
                closureReturnTypeHints = {
                    enable = true,
                },
                closureStyle = 'impl_fn',
                discriminantHints = {
                    enable = 'always',
                },
                expressionAdjustmentHints = {
                    enable = 'always',
                    hideOutsideUnsafe = false,
                    mode = 'prefix',
                },
                lifetimeElisionHints = {
                    enable = 'always',
                    useParameterNames = true,
                },
                maxLength = nil,
                parameterHints = {
                    enable = true,
                },
                reborrowHints = {
                    enable = 'always',
                },
                renderColons = true,
                typeHints = {
                    enable = true,
                    hideClosureInitialization = false,
                    hideNamedConstructor = false,
                },
            },
            interpret = {
                tests = true,
            },
            joinLines = {
                joinAssignments = true,
                joinElseIf = true,
                removeTrailingComma = true,
                unwrapTrivialBlock = true,
            },
            lens = {
                debug = {
                    enable = true,
                },
                enable = true,
                forceCustomCommands = true,
                implementations = {
                    enable = true,
                },
                location = 'above_name',
                references = {
                    adt = {
                        enable = true,
                    },
                    enumVariant = {
                        enable = true,
                    },
                    method = {
                        enable = true,
                    },
                    references = {
                        method = {
                            enable = true,
                        },
                        trait = {
                            enable = true,
                        },
                    },
                    run = {
                        enable = true,
                    },
                },
            },
            linkedProjects = {},
            lru = {
                capacity = nil,
                query = {
                    capacities = {},
                },
            },
            notifications = {
                cargoTomlNotFound = true,
            },
            numThreads = nil,
            procMacro = {
                procMacro = {
                    attributes = {
                        enable = true,
                    },
                },
                enable = true,
                ignored = {},
                server = {},
            },
            references = {
                excludeImports = false,
            },
            runnables = {
                command = {},
                extraArgs = {},
            },
            rust = {
                analyzerTargetDir = {},
            },
            rustc = {
                source = 'discover',
            },
            rustfmt = {
                extraArgs = {
                    '--edition',
                    '2024',
                    '--style-edition',
                    '2024',
                    '--unstable-features',
                    '--verbose',
                },
                overrideCommand = {},
                rangeFormatting = {
                    enable = true,
                },
            },
            semanticHighlighting = {
                comments = {
                    enable = true,
                },
                doc = {
                    comment = {
                        inject = {
                            enable = true,
                        },
                    },
                },
                nonStandardTokens = true,
                operator = {
                    enable = true,
                    specialization = {
                        enable = true,
                    },
                },
                punctuation = {
                    enable = true,
                    separate = {
                        macro = {
                            bang = true,
                        },
                    },
                    specialization = {
                        enable = true,
                    },
                },
                strings = {
                    enable = true,
                },
            },
            signatureInfo = {
                detail = 'full',
                enable = true,
            },
            typing = {
                autoClosingAngleBrackets = {
                    enable = true,
                },
            },
            workspace = {
                symbol = {
                    search = {
                        discoverConfig = nil,
                        excludeImports = false,
                        kind = 'only_types',
                        limit = 128,
                    },
                },
            },
        },
    },
    ---@param init_params lsp.InitializeParams
    before_init = function(init_params, config) ---@param config vim.lsp.Config
        if config.settings and config.settings['rust-analyzer'] then
            init_params.initializationOptions = config.settings['rust-analyzer']
        end
        ---@type RaRunnableArgs
        ---@param command table{ title: string, command: string, arguments: any[] }
        vim.lsp.commands['rust-analyzer.runSingle'] = function(command)
            local r = command.arguments[1] ---@type RaRunnable
            local cmd = { 'cargo', unpack(r.args.cargoArgs) }
            if r.args.executableArgs and #r.args.executableArgs > 0 then
                vim.list_extend(cmd, { '--', unpack(r.args.executableArgs) })
            end
            local proc = vim.system(cmd, { cwd = r.args.cwd })
            local result = proc:wait()
            if result.code == 0 then
                vim.notify(result.stdout, vim.log.levels.INFO)
            else
                vim.notify(result.stderr, vim.log.levels.ERROR)
            end
        end
    end,
}
