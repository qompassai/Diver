-- /qompassai/Diver/lsp/smithy_ls.lua
-- Qompass AI Smithy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---    coursier launch software.amazon.smithy:smithy-language-server:0.7.0

vim.lsp.config['smithy_ls'] = {
  cmd = {
    'coursier',
    'launch',
    'software.amazon.smithy:smithy-language-server:0.7.0',
    '-M',
    'software.amazon.smithy.lsp.Main',
    '--',
    '0',
  },
  filetypes = {
    'smithy'
  },
  root_markers = {
    'smithy-build.json',
    'build.gradle',
    'build.gradle.kts',
    '.git'
  },
  message_level = vim.lsp.protocol.MessageType.Log,
  init_options = {
    statusBarProvider = 'show-message',
    isHttpEnabled = true,
    compilerOptions = {
      snippetAutoIndent = true,
    },
  },
}