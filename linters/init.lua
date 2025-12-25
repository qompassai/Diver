-- /qompassai/Diver/linters/init.lua
-- Qompass AI Diver Linter Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
M.formatters_by_ft = {
    ['_'] = { 'trim_whitespace' },
    --gh_cations = 'zizmore',
    --asm = { 'llvm-mc' },
    -- ansible = 'ansible_lint',
    --[[ apkbuild = {
        'apkbuild-lint',
        'secfixes-check',
    },]]
    --
    --astro = { 'biome' },
    --awk = 'gawk',
    --[[bash = {
        'bashate',
        'bashlint',
        'cspell',
        'bash-language-server',
        'shellharden',
        'shell -n',
        'shellcheck',
        'shfmt',
    }, --]]
    --bazel = 'buildifier',
    --bibtex = 'bibclean',
    -- c = {
    --   'ccls',
    -- },
    --cairo = 'scarb',
    --chef = 'cookstyle', ---foodcritic deprecated
    --clojure = {
    --   'cljfmt',
    --  'cjl-kondo',
    -- },
    -- cmake = {
    --  'cmake-lint',
    -- },
    --  crystal = {
    --    'ameba',
    --   'crystal',
    --  },
    --cpp = {},
    -- csharp = { },
    --  css = {
    --    'biome',
    --    'csslint',
    --    'css-beautify',
    --  },
    cuda = {
        'nvcc',
    },
    -- cypher = 'cypher-lint',
    -- cython = 'cython',
    -- dart = 'dart-analyze',
    -- dhall = 'dhall-lint',
    --desktop = 'desktop-validate-file',
    -- dockerfile = {
    --   'dockerlinter',
    --   'dprint',
    --   'hadolint',
    -- },
    --  ejs = 'biome',
    -- elixir = {},
    -- elm = {},
    -- erlang = {
    --  'dialyzer',
    --  'elvis',
    -- },
    --[[fish = {
    'fish -n',
    'fish_indent',
    'shellcheck',
  }, --]]
    -- gleam = 'gleam_format',
    --[[
 --glsl = {
    'glslang',
    'glslls',
  },
  go = {
    'goimports',
    'gofumpt',
  },
  graphql = 'gqlint',
  groovy = 'npm_groovy_lint',
  handlebars = {
    'biome',
    'djlint',
    'ember-template-lint',
  },
  haskell = {
    'brittany',
    'ormolu',
    'fourmolu',
  },
  helm = { 'helm_format' },
  htmlangular = { 'biome', 'djlint' },
  htmldjango = {
    'biome',
    'djlint',
  },
  html = { 'biome', 'htmlbeautify', 'superhtml' },
  http = 'kulala_fmt',
  inko = 'inko',
  java = { 'checkstyle', 'google-java-format' },
  javascript = { 'biome' },
  javascriptreact = { 'biome' },
  jinja = {
    'djlint',
    'j2lint',
  },
  json = 'biome',
  jsonc = { 'biome' },
  jsonnet = {
    'jsonnetfmt',
    'jsonnetlint',
  },
  jsx = { 'biome' },
  julia = { 'julia_format' },
  just = { 'just_fmt' },
  justfile = { 'just_fmt' },

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
    'stylua'
  },
  luau = { 'stylua' },
  markdown = {
    'mado',
    'biome',
  },
  mail = {
    'alex',
    'proselint',
  },
  matlab = 'mlint',
  mustache = 'biome',
  nix = {
    'alejandra',
    'deadnix',
    'statix',
  },
  php = {
    'intelephense',
    'phan',
    'php',
    'php-cs-fixer',
    'phpcbf',
    'phpcs',
    'phpmd',
    'phpstan',
    'pint',
    'psalm',
    'tlint',
  },
  prisma = { 'prisma_format' },
  proto = { 'buf' },
  protobuf = { 'buf' },
  python = {
    'bandit',
    'pyrefly',
    'ruff',
    'vulture',
    'yapf',
    'yara',
  },
  powershell = {
    'powershell',
    'psscriptanalyzer',
  },
  pug = 'pug-lint',
  qml = {
    'qmlfmt',
    'qmllint',
  },
  r = 'styler',
  ruby = {
    'solargraph',
    'sorbet',
  },
  scala = {
    'scalac',
    'scalafmt',
    'scalastyle',
  },
  sass = {
    'sass-lint',
    'stylelint',
  },
  scss = 'biome',
  sh = 'shfmt',
  solidity = {
    'forge',
    'solc',
    'solhint',
    'solium',
  },
  sphinx = 'sphinx-lint',
  sql = {
    'dprint',
    'sqlfluff',
    'sql-formatter',
  },
  sqlite = {},
  svelte = {},
  swift = 'swiftlint',
  terraform = 'tflint',
  toml = {
    'dprint',
    'tombi',
  },
  tsx = 'biome',
  typescript = {
    'biome',
    'deno',
  },
  typescriptreact = {
    'biome',
    'deno',
  },
  vue = 'biome',
  wgsl = 'naga',
  xml = 'xmllint',
  yaml = {
    'biome',
    'yamllint',
  },
  yml = {
    'biome',
  },
  zig = {
    'zlint',
  },
  zine = { 'zigfmt', 'zigfmt_ast' },
  zon = { 'zigfmt', 'zigfmt_ast' },
  zsh = { 'shfmt', 'shellcheck' },
  --]]
}

return M
