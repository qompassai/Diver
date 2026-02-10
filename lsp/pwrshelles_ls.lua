-- /qompassai/Diver/lsp/powershell_es.lua
-- Qompass AI PowerShell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local function find_pses_bundle()
    local possible_paths = {
        '/opt/powershell-editor-services',
        vim.fn.stdpath('data') .. '/mason/packages/powershell-editor-services',
        vim.fn.expand('~/.local/share/powershell-editor-services'),
        '/usr/share/powershell-editor-services',
        '/usr/local/share/powershell-editor-services',
    }
    for _, path in ipairs(possible_paths) do
        if vim.fn.isdirectory(path) == 1 then
            vim.notify('Found PowerShell Editor Services at: ' .. path, vim.log.levels.INFO)
            return path
        end
    end
    vim.notify('PowerShell Editor Services not found in any known location', vim.log.levels.ERROR)
    return possible_paths[1]
end
local bundle_path = find_pses_bundle()
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'pwsh',
        '-NoLogo',
        '-NoProfile',
        '-Command',
        string.format(
            [[& '%s/PowerShellEditorServices/Start-EditorServices.ps1' -BundledModulesPath '%s' -LogLevel Normal -HostName nvim -HostProfileId 0 -SessionDetailsPath '%s' -Stdio]],
            bundle_path,
            bundle_path,
            vim.fn.stdpath('cache') .. '/pses_session.json'
        ),
    },
    filetypes = {
        'ps1',
        'psm1',
        'psd1',
    },
  on_attach = require('config.core.lsp').on_attach,
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