-- /qompassai/Diver/lsp/bacon.lua
-- Qompass AI Bacon LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://github.com/crisidev/bacon-ls
return ---@type vim.lsp.Config
{
    cmd = {
        'bacon-ls',
    },
    filetypes = {
        'rust',
    },
    init_options = {
        cargo = {
            updateOnInsert = true, ---@source https://github.com/crisidev/bacon-ls#live-diagnostics-as-you-type-cargo-backend-only
        },
    },
    root_markers = {
        '.bacon-locations',
        'bacon.toml',
        'Cargo.lock',
        'Cargo.toml',
        '.git',
    },
    settings = {
        bacon_ls = {
            backend = 'bacon',
            cargo = {
                command = 'clippy',
                features = 'all',
                package = vim.NIL,
                allTargets = true,
                noDefaultFeatures = false,
                extraArgs = {
                    '--workspace',
                },
                env = vim.empty_dict(),
                cancelRunning = true,
                refreshIntervalSeconds = 1,
                separateChildDiagnostics = vim.NIL,
                checkOnSave = true,
                clearDiagnosticsOnCheck = false,
                updateOnInsertDebounceMillis = 500,
            },

            bacon = {
                createPreferencesFile = true,
                locationsFile = '.bacon-locations',
                runInBackground = true,
                runInBackgroundCommand = 'bacon',
                runInBackgroundCommandArguments = '--headless -j bacon-ls',
                synchronizeAllOpenFilesWaitMillis = 2000,
                updateOnSave = true,
                updateOnSaveWaitMillis = 1000,
                validatePreferences = true,
            },

            jobs = {
                ['bacon-ls'] = {
                    command = {
                        'cargo',
                        'clippy',
                        '--workspace',
                        '--all-targets',
                        '--all-features',
                        '--message-format',
                        'json-diagnostic-rendered-ansi',
                    },
                    analyzer = 'cargo_json',
                    need_stdout = true,
                },
            },
            exports = {
                ['cargo-json-spans'] = {
                    auto = true,
                    exporter = 'analyzer',
                    line_format = table.concat({
                        '{diagnostic.level}|:|',
                        '{span.file_name}|:|',
                        '{span.line_start}|:|',
                        '{span.line_end}|:|',
                        '{span.column_start}|:|',
                        '{span.column_end}|:|',
                        '{diagnostic.message}|:|',
                        '{diagnostic.rendered}|:|',
                        '{span.suggested_replacement}',
                    }),
                    path = '.bacon-locations',
                },
            },
        },
    },
}
