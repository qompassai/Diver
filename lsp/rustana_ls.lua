-- #################################################################
-- /qompassai/diver/lsp/rustana_ls.lua
-- Qompass AI Diver Rustana Ls
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
---@source https://rust-analyzer.github.io/book/configuration.html

local function run_single(command)
    local runnable = command.arguments and command.arguments[1]
    if not runnable or not runnable.args then
        return
    end
    local cmd = {
        'cargo',
    }
    vim.list_extend(cmd, runnable.args.cargoArgs or {})
    if runnable.args.executableArgs and #runnable.args.executableArgs > 0 then
        cmd[#cmd + 1] = '--'
        vim.list_extend(cmd, runnable.args.executableArgs)
    end

    vim.system(cmd, { cwd = runnable.args.cwd, text = true }, function(result)
        vim.schedule(function()
            local output = result.code == 0 and result.stdout or result.stderr
            vim.notify(
                output ~= '' and output or ('cargo exited with code %d'):format(result.code),
                result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
            )
        end)
    end)
end
vim.lsp.commands['rust-analyzer.runSingle'] = run_single
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
                    'rust-analyzer.runSingle',
                },
            },
        },
    },
    settings = {
        ['rust-analyzer'] = {
            assist = {
                emitMustUse = true,
                expressionFillDefault = 'todo',
                preferSelf = false,
                termSearch = {
                    fuel = 1800,
                },
            },
            cachePriming = {
                enable = true,
                numThreads = 'physical',
            },
            cargo = {
                allTargets = true,
                autoreload = true,
                buildScripts = {
                    enable = true,
                    invocationStrategy = 'per_workspace',
                    overrideCommand = vim.NIL,
                    rebuildOnSave = true,
                    useRustcWrapper = true,
                },
                cfgs = {
                    'debug_assertions',
                    'miri',
                },
                configPath = vim.NIL,
                extraArgs = {},
                extraEnv = vim.empty_dict(),
                features = 'all',
                metadataExtraArgs = {},
                noDefaultFeatures = false,
                noDeps = false,
                sysroot = 'discover',
                sysrootSrc = vim.NIL,
                target = vim.NIL,
                targetDir = true,
            },
            cfg = {
                setTest = true,
            },
            checkOnSave = false,
            check = {
                allTargets = true,
                command = 'clippy',
                extraArgs = {},
                extraEnv = {
                    RUSTFLAGS = '-C target-cpu=native -C debuginfo=2',
                },
                features = 'all',
                ignore = {},
                invocationStrategy = 'per_workspace',
                noDefaultFeatures = false,
                overrideCommand = vim.NIL,
                targets = vim.NIL,
                workspace = true,
            },
            completion = {
                addColonsToModule = true,
                addSemicolonToUnit = true,
                autoAwait = {
                    enable = true,
                },
                autoIter = {
                    enable = true,
                },
                autoimport = {
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
                    snippets = 'fill_arguments',
                },
                excludeTraits = {},
                fullFunctionSignatures = {
                    enable = true,
                },
                hideDeprecated = false,
                limit = vim.NIL,
                postfix = {
                    enable = true,
                },
                privateEditable = {
                    enable = true,
                },
                snippets = {
                    custom = {
                        Ok = {
                            postfix = 'ok',
                            body = 'Ok(${receiver})',
                            description = 'Wrap the expression in a `Result::Ok`',
                            scope = 'expr',
                        },
                        ['Box::pin'] = {
                            postfix = 'pinbox',
                            body = 'Box::pin(${receiver})',
                            requires = 'std::boxed::Box',
                            description = 'Put the expression into a pinned `Box`',
                            scope = 'expr',
                        },
                        ['Arc::new'] = {
                            postfix = 'arc',
                            body = 'Arc::new(${receiver})',
                            requires = 'std::sync::Arc',
                            description = 'Put the expression into an `Arc`',
                            scope = 'expr',
                        },
                        Some = {
                            postfix = 'some',
                            body = 'Some(${receiver})',
                            description = 'Wrap the expression in an `Option::Some`',
                            scope = 'expr',
                        },
                        Err = {
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
                termSearch = {
                    enable = true,
                    fuel = 1000,
                },
            },
            diagnostics = {
                disabled = {},
                enable = false,
                experimental = {
                    enable = true,
                },
                remapPrefix = vim.empty_dict(),
                styleLints = {
                    enable = true,
                },
                warningsAsHint = {},
                warningsAsInfo = {},
            },
            disableFixtureSupport = false,
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
                branchExitPoints = {
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
                yieldPoints = {
                    enable = true,
                },
            },
            hover = {
                actions = {
                    debug = {
                        enable = true,
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
                    updateTest = {
                        enable = true,
                    },
                },
                documentation = {
                    enable = true,
                    keywords = {
                        enable = true,
                    },
                },
                dropGlue = {
                    enable = true,
                },
                links = {
                    enable = true,
                },
                maxSubstitutionLength = 20,
                memoryLayout = {
                    alignment = 'hexadecimal',
                    enable = true,
                    niches = true,
                    offset = 'hexadecimal',
                    padding = vim.NIL,
                    size = 'both',
                },
                show = {
                    enumVariants = 5,
                    fields = 5,
                    traitAssocItems = vim.NIL,
                },
            },
            imports = {
                granularity = {
                    enforce = true,
                    group = 'crate',
                },
                group = {
                    enable = true,
                },
                merge = {
                    glob = true,
                },
                preferNoStd = false,
                preferPrelude = false,
                prefix = 'plain',
                prefixExternPrelude = false,
            },
            inlayHints = {
                bindingModeHints = {
                    enable = true,
                },
                chainingHints = {
                    enable = true,
                },
                closingBraceHints = {
                    enable = true,
                    minLines = 0,
                },
                closureCaptureHints = {
                    enable = true,
                },
                closureReturnTypeHints = {
                    enable = 'always',
                },
                closureStyle = 'impl_fn',
                discriminantHints = {
                    enable = 'always',
                },
                expressionAdjustmentHints = {
                    disableReborrows = true,
                    enable = 'always',
                    hideOutsideUnsafe = false,
                    mode = 'prefix',
                },
                genericParameterHints = {
                    const = {
                        enable = true,
                    },
                    lifetime = {
                        enable = false,
                    },
                    type = {
                        enable = false,
                    },
                },
                implicitDrops = {
                    enable = false,
                },
                implicitSizedBoundHints = {
                    enable = false,
                },
                impliedDynTraitHints = {
                    enable = true,
                },
                lifetimeElisionHints = {
                    enable = 'always',
                    useParameterNames = true,
                },
                maxLength = vim.NIL,
                parameterHints = {
                    enable = true,
                    missingArguments = {
                        enable = false,
                    },
                },
                rangeExclusiveHints = {
                    enable = false,
                },
                reborrowHints = {
                    enable = 'never',
                },
                renderColons = true,
                typeHints = {
                    enable = true,
                    hideClosureInitialization = false,
                    hideClosureParameter = false,
                    hideInferredTypes = false,
                    hideNamedConstructor = false,
                    location = 'inline',
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
                    trait = {
                        enable = true,
                    },
                },
                run = {
                    enable = true,
                },
                updateTest = {
                    enable = true,
                },
            },
            linkedProjects = {},
            lru = {
                capacity = vim.NIL,
                query = {
                    capacities = vim.empty_dict(),
                },
            },
            notifications = {
                cargoTomlNotFound = true,
            },
            numThreads = vim.NIL,
            procMacro = {
                attributes = {
                    enable = true,
                },
                enable = true,
                ignored = vim.empty_dict(),
                processes = 2,
                server = vim.NIL,
            },
            profiling = {
                memoryProfile = vim.NIL,
            },
            references = {
                excludeImports = false,
                excludeTests = false,
            },
            rename = {
                showConflicts = true,
            },
            runnables = {
                bench = {
                    command = 'bench',
                    overrideCommand = vim.NIL,
                },
                command = vim.NIL,
                doctest = {
                    overrideCommand = vim.NIL,
                },
                extraArgs = {},
                extraTestBinaryArgs = {
                    '--nocapture',
                },
                test = {
                    command = 'test',
                    overrideCommand = vim.NIL,
                },
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
                    '--verbose',
                },
                overrideCommand = vim.NIL,
                rangeFormatting = {
                    enable = false,
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
                documentation = {
                    enable = true,
                },
            },
            typing = {
                triggerChars = '=.{(><',
            },
            vfs = {
                extraIncludes = {},
            },
            workspace = {
                discoverConfig = vim.NIL,
                symbol = {
                    search = {
                        excludeImports = false,
                        kind = 'only_types',
                        limit = 128,
                        scope = 'workspace',
                    },
                },
            },
        },
    },
    ---@param init_params lsp.InitializeParams
    ---@param config vim.lsp.Config
    before_init = function(init_params, config)
        if config.settings and config.settings['rust-analyzer'] then
            init_params.initializationOptions = config.settings['rust-analyzer']
        end
    end,
}
