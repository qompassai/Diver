-- powershell_es.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- /qompassai/Diver/lsp/powershell_es.lua
-- Qompass AI PowerShell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['powershell_es'] = {
  cmd = { 'pwsh', '-NoLogo', '-NoProfile', '-Command', 'Import-Module PowerShellEditorServices; Start-EditorServices -BundledModulesPath /usr/share/powershell-editor-services/ -LogLevel Normal -HostName nvim -HostProfileId 0 -AdditionalModules @{ "PSES" = "latest" } -SessionDetailsPath session.json -FeatureFlags @{ "PSReadLine" = $false }' },
  filetypes = { 'ps1', 'psm1', 'psd1' },
  settings = {
    powershell = {
      codeFormatting = {
        Preset = "Allman",
        UseCorrectCasing = true,
        AutoCorrectAliases = true,
        TrimWhitespaceAroundPipe = true,
        WhitespaceAfterSeparator = true,
        ExpandShortcut = true,
      },
      scriptAnalysis = {
        enable = true,
        settingsPath = vim.env.HOME .. "/.config/powershell/ScriptAnalyzerSettings.psd1",
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
          MissingImport = "Warning",
          UnusedVariable = "Hint",
        },
      },
      telemetry = {
        enable = false,
      },
      completion = {
        enable = true,
        useLanguageServer = true,
        triggerCharacters = { ".", "$", "[" },
      },
    },
  },
  capabilities = vim.lsp.protocol.make_client_capabilities(),
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "H", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = false }) end, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    if client.server_capabilities.inlayHintProvider and type(vim.lsp.inlay_hint) == "function" then
      vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
      vim.lsp.inlay_hint(bufnr, true)
    end
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function() vim.lsp.buf.format({ async = false }) end,
    })
  end,
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}