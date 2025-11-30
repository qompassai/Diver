-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Lua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['lua_ls'] = {
  cmd = {
    'lua-language-server',
  },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor.rewrite",
      "refactor.extract",
    },
    resolveProvider = true,
  },
  colorProvider = true,
  filetypes = {
    "lua",
    "luau",
  },
  semanticTokensProvider = {
    full = true,
    legend = {
      tokenModifiers = {
        "declaration",
        "definition",
        "readonly",
        "static",
        "deprecated",
        "abstract",
        "async",
        "modification",
        "documentation",
        "defaultLibrary",
        "global",
      },
      tokenTypes = {
        "namespace",
        "type",
        "class",
        "enum",
        "interface",
        "struct",
        "typeParameter",
        "parameter",
        "variable",
        "property",
        "enumMember",
        "event",
        "function",
        "method",
        "macro",
        "keyword",
        "modifier",
        "comment",
        "string",
        "number",
        "regexp",
        "operator",
        "decorator",
      },
    },
    range = true,
  },
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luarc.json5",
    ".stylua.toml",
    "luacheckrc",
    ".luacheckrc",
  },
  settings = {
    Lua = {
      format = {
        enable = true,
        defaultConfig = {
          align_continuous_rect_table_field = true,
          align_array_table = true,
          indent_style = 'space',
          indent_size = "2",
          quote_style = "ForceSingle",
          trailing_table_separator = "always",
          align_continuous_assign_statement = true,
        },
      },
      runtime = {
        version = "LuaJIT",
        path = {
          "lua/?.lua",
          "lua/?/init.lua",
        },
      },
      diagnostics = {
        enable = true,
        globals = {
          "vim",
          "jit",
          "use",
          "require",
        },
        disable = {
          "lowercase-global",
        },
        severity = {
          ["unused-local"] = "Hint",
        },
        unusedLocalExclude = {
          "_*",
        },
      },
      workspace = {
        checkThirdParty = true,
        library = {
          vim.api.nvim_get_runtime_file("", true),
          vim.env.VIMRUNTIME,
          "${3rd}/luv/library",
          "${3rd}/busted/library",
          "${3rd}/neodev.nvim/types/nightly",
          "${3rd}/luassert/library",
          "${3rd}/lazy.nvim/library",
          "${3rd}/blink.cmp/library",
          vim.fn.expand("$HOME") .. "/.config/nvim/lua/",
        },
        ignoreDir = { "node_modules", "build" },
        maxPreload = 2000,
        preloadFileSize = 50000,
      },
      telemetry = {
        enable = false,
      },
      completion = {
        callSnippet = "Replace",
        keywordSnippet = "Enable",
        displayContext = 4,
      },
      hint = {
        enable = true,
        setType = true,
        paramType = true,
        paramName = "All",
        arrayIndex = "Enable",
        await = true,
      },
    },
  },
}