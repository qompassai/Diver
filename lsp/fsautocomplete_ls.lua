-- /qompassai/Diver/lsp/fsautocomplete_ls.lua
-- Qompass AI F# AutoComplete LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- References:  https://github.com/ionide/FsAutoComplete?tab=readme-ov-file#settings
-- dotnet tool install --global fsautocomplete
vim.lsp.config['fsautocomplete_ls'] = {
  cmd = {
    'fsautocomplete',
    '--adaptive-lsp-server-enabled'
  },
  filetypes = {
    'fsharp'
  },
  init_options = {
    AutomaticWorkspaceInit = true,
  },
  root_markers = {
    '*.fsproj',
    '.git',
    '*.sln'
  },
  settings = {
    FSharp = {
      keywordsAutocomplete = true,
      ExternalAutocomplete = true,
      Linter = true,
      UnionCaseStubGeneration = true,
      UnionCaseStubGenerationBody = 'failwith "Not Implemented"',
      RecordStubGeneration = true,
      RecordStubGenerationBody = 'failwith "Not Implemented"',
      InterfaceStubGeneration = true,
      InterfaceStubGenerationObjectIdentifier = 'this',
      InterfaceStubGenerationMethodBody = 'failwith "Not Implemented"',
      UnusedOpensAnalyzer = true,
      UnusedDeclarationsAnalyzer = true,
      UseSdkScripts = true,
      SimplifyNameAnalyzer = true,
      ResolveNamespaces = true,
      EnableReferenceCodeLens = true,
    },
  },
}