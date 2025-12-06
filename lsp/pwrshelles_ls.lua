-- /qompassai/Diver/lsp/powershell_es.lua
-- Qompass AI PowerShell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['pwrshelles_ls'] = {
  cmd = {
    'pwsh',
    '-NoLogo',
    '-NoProfile',
    "-Command",
    table.concat({
      "Import-Module PowerShellEditorServices;",
      "Start-EditorServices",
      "-BundledModulesPath /usr/share/powershell-editor-services/",
      "-LogLevel Normal",
      "-HostName nvim",
      "-HostProfileId 0",
      "-SessionDetailsPath session.json",
    }, " "),
    filetypes = {
      'ps1',
      'psm1',
      'psd1',
    },
    settings = {
      powershell = {
        codeFormatting = {
          Preset = 'Allman',
          AutoCorrectAliases = true,
          UseCorrectCasing = true,
          TrimWhitespaceAroundPipe = true,
          WhitespaceAfterSeparator = true,
          ExpandShortcut = true,
        },
        scriptAnalysis = {
          enable = true,
          settingsPath = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config"))
              .. "/powershell/ScriptAnalyzerSettings.psd1",
        },
        editor = {
          highlightString = true,
          showTokenClassification = true,
          enableOnTypeFormatting = true,
          enableInlayHints = true,
        },
        diagnostics = {
          enable = true,
          severity = {
            MissingImport = 'Warning',
            UnusedVariable = 'Hint',
          },
        },
        telemetry = {
          enable = false,
        },
        completion = {
          enable = true,
          useLanguageServer = true,
          triggerCharacters = {
            ".",
            "$",
            "[",
          },
        },
      },
    },
  },
}