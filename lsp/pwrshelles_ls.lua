-- /qompassai/Diver/lsp/powershell_es.lua
-- Qompass AI PowerShell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pwsh',
        '-NoLogo',
        '-NoProfile',
        '-Command',
        table.concat({
            'Import-Module PowerShellEditorServices;',
            'Start-EditorServices',
            '-BundledModulesPath /usr/share/powershell-editor-services/',
            '-LogLevel Normal',
            '-HostName nvim',
            '-HostProfileId 0',
            '-SessionDetailsPath session.json',
            '-Stdio',
        }, ' '),
    },
    filetypes = {
        'ps1',
        'psm1',
        'psd1',
    },
    settings = {
        powershell = {
            codeFormatting = {
                AutoCorrectAliases = true,
                ExpandShortcut = true,
                Preset = 'Allman',
                TrimWhitespaceAroundPipe = true,
                UseCorrectCasing = true,
                WhitespaceAfterSeparator = true,
            },
            completion = {
                enable = true,
                useLanguageServer = true,
                triggerCharacters = {
                    '.',
                    '$',
                    '[',
                },
            },
            diagnostics = {
                enable = true,
                severity = {
                    MissingImport = 'Warning',
                    UnusedVariable = 'Hint',
                },
            },
            editor = {
                highlightString = true,
                showTokenClassification = true,
                enableOnTypeFormatting = true,
                enableInlayHints = true,
            },
            scriptAnalysis = {
                enable = true,
                settingsPath = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config'))
                    .. '/powershell/ScriptAnalyzerSettings.psd1',
            },
            telemetry = {
                enable = false,
            },
        },
    },
}