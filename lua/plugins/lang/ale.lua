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
    'javascript',
    'json',
    'jsonc',
    'latex',
    'lua',
    'make',
    'nix',
    'python',
    'systemd',
    'toml',
    'typscript',
    'xml',
    'zig'
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
    g.ale_virtualtext_cursor = 0
    g.ale_pattern_options = {
      [".min%.js$"] = { ale_linters = {}, ale_fixers = {} },
      ["/vendor/"] = { ale_linters = {}, ale_fixers = {} },
    }
    g.ale_pattern_options_enabled = 1
    g.ale_fixers = {
      bash = {
        'shfmt',
      },
      lua = {
        'emmylua_ls',
      },
      nix = {
        'alejandra'
      },
      php = {
        'php_cs_fixer',
        'phpcbf',
      },
      python = {
        'ruff_format',
      },
      ruby = {
        'rubocop',
      },
      rust = {
        'rustfmt',
      },
      zig = {
        'zigfmt',
        'zls'
      }
    }
    g.ale_linters = {
      awk = { 'gawk'
      },
      bash = {
        'bashate',
        'bashlint',
        'cspell',
        'bash-language-server',
        'shellharden',
        'shell -n',
        'shellcheck',
        'shfmt',
      },
      bibtex = {
        'bibclean'
      },
      c = {
        'astyle',
        'clangd',
        'flawfinder'
      },
      cairo = {
        'scarb'
      },
      cmake = {
        'cmake-format',
        'cmake-lint'
      },
      crystal = {
        'ameba',
        'crystal'
      },
      css = {
        'csslint',
        'fecs'
      },
      javascript = {
        'biome'
      },
      json = {
        'biome'
      },
      jsonc = {
        'biome'
      },
      latex = {
        'texlab'
      },
      lua = {
        'luacheck',
        'stylua',
        'emmylua_ls'
      },
      make = {
        'checkmake'
      },
      nix = {
        'deadnix',
        'nix',
        'statix'
      },
      php = {
        'intelephense',
        'phan',
        'php',
        'php-cs-fixer',
        'phpcbf',
        "phpcs",
        'phpmd',
        'phpstan',
        'pint',
        "psalm",
        "tlint",
      },
      python = {
        "bandit",
        'pyrefly',
        "ruff",
        'vulture',
        'yapf',
        'yara',
      },
      ruby = {
        'rubocop',
        "ruby",
      },
      rust = {
        'bacon',
        "cargo",
        "rust-analyzer",
        "rustc",
        "rustfmt",
      },
      systemd = {
        'systemd-analyze'
      },
      toml = {
        'dprint',
        'tombi'
      },
      typescript = {
        'biome',
        'deno'
      },
      xml = {
        'xmllint'
      },
      wgsl = {
        'naga'
      },
      zig = {
        'zlint'
      }
    }
  end,
}