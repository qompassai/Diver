-- /qompassai/Diver/lsp/perl_ls.lua
-- Qompass AI Perl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/richterger/Perl-LanguageServer/tree/master/clients/vscode/perl
vim.lsp.config['perl_ls'] = {
  cmd = {
    'perl',
    '-MPerl::LanguageServer',
    '-e', 'Perl::LanguageServer::run',
    '--',
    '--port', '13603',
    '--nostdio', '0',
  },
  filetypes = {
    'perl',
    'pl',
    'pm'
  },
  root_markers = {
    '.git'
  },
  settings = {
    perl = {
      enable = true,
      perlCmd = 'perl',
      perlArgs = {
      },
      useTaintForSyntaxCheck = true,
      perlInc = {
      },
      fileFilter = {
        '.pm',
        '.pl'
      },
      ignoreDirs = {
        '.git',
        '.svn',
        '.vscode'
      },
      checkSyntax = true,
      publishDiagnostics = true,
      workspaceSymbols = true,
      documentSymbols = true,
      minimalisticCompletions = false,
      showSyntaxErrors = true,
      showLocalVars = true,
      sshAddr = nil,
      sshPort = nil,
      sshUser = nil,
      sshCmd = 'ssh/plink',
      sshWorkspaceRoot = nil,
      sshArgs = nil,
      pathMap = {
      },
      containerCmd = 'docker',
      containerArgs = nil,
      containerMode = 'run',
      containerName = nil,
      debugAdapterPort = 13603,
      debugAdapterPortRange = 100,
      logLevel = 0,
      logFile = nil,
      disableCache = false,
    },
  },
}