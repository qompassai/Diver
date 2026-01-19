-- /qompassai/Diver/lsp/perl_ls.lua
-- Qompass AI Perl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'perl',
        '-MPerl::LanguageServer',
        '-e',
        'Perl::LanguageServer::run',
        '--',
        '--port',
        '13603',
        '--nostdio',
        '0',
    },
    filetypes = {
        'perl',
        'pl',
        'pm',
    },
    root_markers = {
        '.git',
    },
    settings = {
        perl = {
            enable = true,
            perlCmd = 'perl',
            perlArgs = {},
            useTaintForSyntaxCheck = true,
            perlInc = {},
            fileFilter = {
                '.pm',
                '.pl',
            },
            ignoreDirs = {
                '.git',
                '.svn',
                '.vscode',
            },
            checkSyntax = true,
            containerArgs = nil,
            containerCmd = 'docker',
            containerMode = 'run',
            containerName = nil,
            debugAdapterPort = 13603,
            debugAdapterPortRange = 100,
            disableCache = false,
            documentSymbols = true,
            logFile = nil,
            logLevel = 0,
            minimalisticCompletions = false,
            pathMap = {},
            publishDiagnostics = true,
            showSyntaxErrors = true,
            showLocalVars = true,
            sshAddr = nil,
            sshArgs = nil,
            sshCmd = 'ssh/plink',
            sshPort = nil,
            sshUser = nil,
            sshWorkspaceRoot = nil,
            workspaceSymbols = true,
        },
    },
}