-- /qompassai/Diver/lsp/rpmspec_ls.lua
-- Qompass AI Redhat Package Manager (RPM) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/dcermak/rpm-spec-language-server
-- pip install rpm-spec-language-server
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'rpm_lsp_server',
    '--stdio',
  },
  docs = { ---@type table
    description = [[
  https://github.com/dcermak/rpm-spec-language-server

  Language server protocol (LSP) support for RPM Spec files.
  ]],
  },
  filetypes = { ---@type string[]
    'spec',
  },
  root_markers = { ---@type string[]
    '.git',
  },
  settings = { ---@type string[]
  },
}