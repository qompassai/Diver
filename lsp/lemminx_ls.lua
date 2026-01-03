-- /qompassai/Diver/lsp/lemminx.lua
-- Qompass AI Lemminx XML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'lemminx',
  },
  filetypes = {
    'atom',
    'rss',
    'svg',
    'xsd',
    'xsl',
    'xslt',
    'xml',
  },
  root_markers = {
    '.git',
    'pom.xml',
    'build.gradle',
    'settings.gradle',
    'build.xml',
    'ivy.xml',
  },
  settings = {
    xml = {
      format = {
        enabled = true,
        splitAttributes = false,
        joinCDATALines = false,
        joinCommentLines = false,
        joinContentLines = false,
        spaceBeforeEmptyCloseTag = true,
      },
      completion = {
        autoCloseTags = true,
        defaultNamespace = '',
        useSchemaLocation = true,
      },
      validation = {
        enabled = true,
        schemas = {
          {
            fileMatch = {
              '*.xsd',
              '*.xml',
            },
            url = 'https://www.w3.org/2001/XMLSchema.xsd',
          },
        },
      },
      logs = {
        enabled = true,
        file = vim.fn.expand("$XDG_DATA_HOME/lemminx/lemminx.log"),
        trace = true,
      },
      hover = {
        enabled = true,
      },
      folding = {
        enabled = true,
      },
    },
  },
  init_options = {
    settings = {
      xml = {
        trace = {
          server = "verbose",
        },
        catalogs = {
          "catalog.xml",
          "catalog2.xml",
        },
        logs = {
          client = true,
          file = vim.fn.expand("~/.local/state/lemminx/lemminx.log"),
        },
        format = {
          enabled = true,
          splitAttributes = false,
          joinCDATALines = false,
          joinCommentLines = false,
          joinContentLines = false,
          spaceBeforeEmptyCloseTag = true,
        },
        completion = {
          autoCloseTags = true,
        },
        useCache = true,
        validation = {
          noGrammar = "hint",
          enabled = true,
          schema = true,
        },
        capabilities = {
          formatting = true,
        },
      },
    },
  },
}