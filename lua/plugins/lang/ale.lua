-- /qompassai/Diver/lua/plugins/lang/ale.lua
-- Qompass AI Asynchronous Lint Engine (ALE) Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------------------
return {
  'dense-analysis/ale',
  ft = {
    'ansible',
    'awk',
    'bash',
    'bibtex',
    'c',
    'cairo',
    'css',
    'd',
    'dafny',
    'dart',
    'desktop',
    'dhall',
    'dockerfile',
    'elixir',
    'elm',
    'erb',
    'erlang',
    'go',
    'haskell',
    --"html",
    'http',
    'java',
    'javascript',
    'jinja',
    'json',
    'jsonc',
    'jsonnet',
    'kotlin',
    'latex',
    'llvm',
    'lua',
    'mail',
    'make',
    'matlab',
    'mercery',
    'nasm',
    'nickel',
    'nim',
    'nix',
    'objective-c',
    'ocaml',
    'odin',
    'openapi',
    'openscad',
    'perl',
    'php',
    'powershell',
    'proto',
    'pug',
    'puppet',
    'python',
    'qml',
    'r',
    'reasonml',
    'rego',
    'rest',
    'robot',
    'ruby',
    'rust',
    'salt',
    'sass',
    'scala',
    'scss',
    'sml',
    'solidity',
    'sql',
    'svelte',
    'swift',
    'systemd',
    'tcl',
    'terraform',
    'texinfo',
    'text',
    'toml',
    'typescript',
    'typst',
    'v',
    'vala',
    'verilog',
    'vhdl',
    'vim',
    'vue',
    'wgsl',
    'xhtml',
    'xml',
    'yaml',
    'zig',
  },
  config = function()
    local g = vim.g
    g.ale_completion_enabled = 0
    g.ale_ruby_rubocop_auto_correct_all = 1
    g.ale_fix_on_save = 1
    g.ale_lint_on_text_changed = 'normal'
    g.ale_lint_on_insert_leave = 1
    g.ale_lint_on_save = 1
    g.ale_echo_msg_error_str = ''
    g.ale_echo_msg_warning_str = ''
    g.ale_maximum_file_size = 1024 * 1024
    g.ale_sign_error = '✗'
    g.ale_sign_warning = '!'
    g.ale_echo_cursor = 0
    g.ale_echo_msg_format = ''
    g.ale_set_highlights = 1
    g.ale_virtualtext_cursor = 1
    g.ale_pattern_options = {
      ['.min%.js$'] = { ale_linters = {}, ale_fixers = {} },
      ['/vendor/'] = { ale_linters = {}, ale_fixers = {} },
    }
    g.ale_pattern_options_enabled = 1
    g.ale_fixers = {
      ansible = {
        'ansible-lint',
      },
      awk = {},
      bash = {
        'beautysh',
        'shfmt',
      },
      bibtex = {},
      c = {
        'clang-format',
      },
      d = {
        'dfmt',
        'uncrustify',
      },
      dafny = {},
      dart = {
        'dart-format',
        'dartfmt',
      },
      desktop = {},
      dhall = {
        'dhall-format',
      },
      elm = {
        'elm-format',
      },
      erb = {
        'erb-formatter',
        'htmlbeautifier',
      },
      erlang = {
        'erlfmt',
      },
      go = {
        'gofmt',
        'goimports',
      },
      haskell = {
        'brittany',
        'hfmt',
      },
      -- html = {
      --   "prettierd",
      -- },
      jinja = {
        'djhtml',
      },
      json = {
      },
      kotlin = {
        'ktlint',
      },
      lua = {},
      nix = {
        'alejandra',
      },
      ocaml = {
        'ocamlformat',
      },
      perl = {
        'perltidy',
      },
      php = {
        'php_cs_fixer',
        'phpcbf',
      },
      puppet = {
        'puppet-lint',
      },
      python = {
        'ruff_format',
      },
      robot = {
        'robotidy',
      },
      ruby = {
        'rubocop',
      },
      rust = {
        'rustfmt',
      },
      toml = {
        'dprint',
      },
      zig = {
        'zigfmt',
        'zls',
      },
    }
    g.ale_linters = {
      awk = {
        'gawk'
      },
      bash = {
        'bashate',
        'bashlint',
        'language_server',
        'shellharden',
        'shell -n',
        'shellcheck',
        'shfmt',
      },
      bibtex = {
        'bibclean',
      },
      c = {
        'astyle',
        'clangd',
        'flawfinder',
      },
      cairo = {
        'scarb',
      },
      cmake = {
        'cmake-format',
        'cmake-lint',
      },
      crystal = {
        'ameba',
        'crystal',
      },
      css = {
        'csslint',
        'fecs',
      },
      d = {
        'dmd',
        'dls',
      },
      desktop = {
        'desktop-file-validate',
      },
      dockerfile = {
        'dockerfile_lint',
        'dockerlinter',
        'hadolint',
      },
      elm = {
        'elm-make',
        'elm-ls',
      },
      go = {
        'gosimple',
        'golangci-lint',
        'staticcheck',
      },
      http = {
        'curl',
      },
      javascript = {
        'biome',
      },
      json = {
      },
      jsonc = {
      },
      latex = {
        'texlab',
      },
      lua = {
        'stylua -s',
      },
      make = {
        'checkmake',
      },
      nix = {
        'deadnix',
        'nix',
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
      python = {
        'bandit',
        'pyrefly',
        'ruff',
        'vulture',
        'yapf',
        'yara',
      },
      ruby = {
        'rubocop',
        'ruby',
      },
      rust = {
        'bacon',
        'cargo',
        'rust-analyzer',
        'rustc',
        'rustfmt',
      },
      systemd = {
        'systemd-analyze',
      },
      toml = {
        'dprint',
        'tombi',
      },
      typescript = {
        'deno',
      },
      xml = {
        'xmllint',
      },
      wgsl = {
        'naga',
      },
      yaml = {
        'yamllint'
      },
      zig = {
        'zlint',
      },
    }
  end,
}