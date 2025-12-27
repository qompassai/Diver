-- /qompassai/Diver/linters/init.lua
-- Qompass AI Diver Linter Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
M.linters_by_ft = {
  asm = {
    'llvm-mc',
  },
  ansible = {
    'ansible_lint',
  },
  apkbuild = {
    'apkbuild-lint',
    'secfixes-check',
  },
  --astro = {},
  --awk = {},
  bash = {
    'bashlint',
    'shellcheck',
  },
  bazel = 'buildifier',
  bibtex = 'bibclean',
  -- c = {
  -- },
  cairo = 'scarb',
  chef = 'cookstyle', ---foodcritic deprecated
  clojure = {
    'cjl-kondo',
  },
  cmake = {
    'cmake-lint',
  },
  crystal = {
    'ameba',
  },
  --cpp = {},
  --csharp = {},
  css = {
    'csslint',
    'stylelint',
  },
  cuda = {
    'nvcc',
  },
  -- cypher = 'cypher-lint',
  cython = 'cython-lint',
  -- dart = 'dart-analyze',
  -- dhall = 'dhall-lint',
  desktop = 'desktop-validate-file',
  -- dockerfile = {
  --   'dockerlinter',
  --   'dprint',
  --   'hadolint',
  -- },
  --  ejs = {},
  -- elixir = {},
  -- elm = {},
  -- erlang = {
  --  'dialyzer',
  --  'elvis',
  -- },
  --fish = {
  --'fish -n',
  --'fish_indent',
  --'shellcheck',
  --},
  --gh_cations = 'zizmore',
  -- gleam = 'gleam_format',
  --glsl = {
  --'glslang',
  --'glslls',
  --},
  --go = {},
  --graphql = 'gqlint',
  --groovy = 'npm_groovy_lint',
  --[[
  handlebars = {
    'djlint',
    'ember-template-lint',
  },
  --]]
  --haskell = {
  --[[
},
  helm = {
  },
--]]
  htmlangular = {},
  htmldjango = {},
  --html = {
  -- },
  http = {},
  -- inko = 'inko',
  --java = {
  --  'checkstyle',
  --},
  javascript = {},
  javascriptreact = {},
  jinja = {
    'djlint',
    'j2lint',
  },
  --json = '',
  --[[
  jsonc = {
    ''
  },
  --]]
  jsonnet = {
    'jsonnetlint',
  },
  jsx = {},
  julia = {},
  just = {},
  justfile = {},
  kotlin = {
    'kotlinc',
    'ktlint',
  },
  latex = {
    'lacheck',
    'texlab',
  },
  -- llvm = 'llc',
  lua = {
    'luac',
  },
  luau = {
    'luac',
  },
  markdown = {
    'mado',
  },
  mail = {
    'alex',
    'proselint',
  },
  matlab = 'mlint',
  mustache = {},
  nix = {
    'deadnix',
    'statix',
  },
  php = {
    'intelephense',
    'phan',
    'php',
    'phpcs',
    'phpmd',
    'phpstan',
    'psalm',
  },
  prisma = {},
  proto = {},
  protobuf = {},
  python = {
    'bandit',
    --'pyrefly',
    'vulture',
    'yara',
  },
  powershell = {
    'psscriptanalyzer',
  },
  pug = 'pug-lint',
  qml = {
    'qmllint',
  },
  r = {},
  ruby = {
    'solargraph',
    'sorbet',
  },
  scala = {
    'scalac',
    'scalastyle',
  },
  sass = {
    'sass-lint',
  },
  scss = {},
  --[[
  solidity = {
    'forge',
    'solc',
    'solhint',
    'solium',
  },
  ]]
  --
  sphinx = 'sphinx-lint',
  sql = {
    'dprint',
    'sqlfluff',
  },
  sqlite = {},
  svelte = {},
  swift = 'swiftlint',
  terraform = 'tflint',
  --[[
  toml = {
    'dprint',
  },
  --]]
  -- tsx = {},
  typescript = {},
  typescriptreact = {},
  vue = {},
  wgsl = 'naga',
  xml = 'xmllint',
  yaml = {
    'yamllint',
  },
  yml = {},
  zig = {
    'zlint',
  },
  zine = {
    'zlint',
    'zlint',
  },
  zon = {
    'zlint',
  },
  zsh = {
    'shellcheck',
  },
}

return M