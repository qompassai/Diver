-- qompassai/Diver/lua/config/lang/conform.lua
-- Qompass AI Diver Conform Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local function biome_cmd(cmd)
  return {
    cmmmand = "biome",
    args = { cmd, "check", "--apply", "--stdin-file-path", "$FILENAME" },
    cwd = vim.fn.expand(vim.env.XDG_CONFIG_HOME or "~/.config") .. "/biome",
  }
end
local nix_cfg = require("config.lang.nix")
local M = {}
    M.formatters_by_ft = {
      ['_'] = { 'trim_whitespace' },
      asm = { 'asmfmt' },
      ansible = { 'ansible_lint' },
      astro = { 'biome' },
      bash = { 'shfmt', 'shellcheck' },
      c = { 'clang_format', 'uncrustify' },
      clojure = { 'cljfmt' },
      cmake = { 'cmake_format' },
      conf = { 'trim_whitespace' },
      cpp = { 'clang_format' },
      csharp = { 'csharpier' },
      css = { 'biome' },
      cue = { 'cue_fmt' },
      dart = { 'dart_format' },
      dhall = { 'dhall_format' },
      dockerfile = { 'dockerfmt' },
      ejs = { 'biome' },
      elixir = { 'mix_format' },
      elm = { 'elm_format' },
      erlang = { 'erlfmt' },
      fish = { 'fish_indent' },
      gleam = { 'gleam_format' },
      go = { 'goimports', 'gofumpt' },
      graphql = { 'graphql-format' },
      groovy = { 'npm_groovy_lint' },
      handlebars = { 'biome' },
      haskell = { 'ormolu', 'fourmolu' },
      hcl = { 'terraform_fmt' },
      helm = { 'helm_format' },
      htmlangular = { 'biome' },
      htmldjango = { 'biome' },
      html = { 'biome' },
      javascript = { 'biome' },
      javascriptreact = { 'biome' },
      json = { 'biome' },
      jsonc = { 'biome' },
      jsonnet = { 'jsonnetfmt' },
      json5 = { 'biome' },
      jsx = { 'biome' },
      julia = { 'julia_format' },
      just = { 'just_fmt' },
      justfile = { 'just_fmt' },
      java = { 'google-java-format' },
      kotlin = { 'ktlint' },
      latex = { 'tex-fmt', 'latexindent' },
      lua = { 'lua-format', 'stylua' },
      luau = { 'lua-format', 'stylua' },
      markdown = { 'biome' },
      ['markdown.mdx'] = { 'biome' },
      mustache = { 'biome' },
      nix = { 'alejandra' },
      nginx = { 'nginx_config_formatter' },
      perl = { 'perltidy' },
      php = { 'php_cs_fixer', 'phpcbf' },
      prisma = { 'prisma_format' },
      proto = { 'buf' },
      protobuf = { 'buf' },
      python = { 'ruff_format', 'ruff_organize_imports', 'black', 'isort' },
      pug = { 'prettier' },
      r = { 'styler' },
      requirements = { 'ruff_format' },
      ruby = { 'rubocop', 'standardrb' },
      rust = { 'rustfmt' },
      scala = { 'scalafmt' },
      scss = { 'biome' },
      sass = { 'biome' },
      sh = { 'shfmt' },
      solidity = { 'prettier_solidity' },
      sql = { 'sqlfluff', 'sql-formatter' },
      sqlite = { 'sqlfluff' },
      svelte = { 'svelte_format' },
      swift = { 'swift_format' },
      tex = { 'latexindent' },
      terraform = { 'terraform_fmt' },
      toml = { 'taplo' },
      tsx = { 'biome' },
      typescript = { 'biome' },
      typescriptreact = { 'biome' },
      vue = { 'biome' },
      xml = { 'xmlformat' },
      yaml = { 'biome' },
      yml = { 'biome' },
      zig = { 'zigfmt', 'zigfmt_ast' },
      zine = { 'zigfmt', 'zigfmt_ast' },
      zon = { 'zigfmt', 'zigfmt_ast' },
      zsh = { 'shfmt', 'shellcheck' }
    }
    M.default_format_opts = {
  lsp_format = "fallback",
}
    M.format_on_save = {
  lsp_fallback = true,
  lsp_format = "fallback",
  timeout_ms = 2000,
  undojoin = true,
  stop_after_first = false,
  exclude = { "spell", "codespell" },
}

M.format_after_save = {
  enabled = true,
  lsp_format = "fallback",
  timeout_ms = 1000,
  async = true,
  undojoin = true,
}
M.log_level = vim.log.levels.ERROR
M.notify_on_error = true
M.notify_no_formatters = true
    M.formatters = {
      alejandra = function()
    return nix_cfg.nix_conform({
      check = false,
      exclude = { "result", "node_modules" },
      experimental_config = "alejandra.toml",
      quiet = 1,
      threads = 4,
    })
  end,
   ansible_lint = {
      command     = "ansible-lint",
      args        = { "-q", "--fix", "$FILENAME" },
      stdin       = false,
      exit_codes  = { 0, 2 },
    },
      asmfmt = { command = 'asmfmt', stdin = true, args = {} },
      autopep8 = {
        command         = 'autopep8',
        stdin           = true,
        args            = { '-' },
        stream          = 'stdout',
        ignore_exitcode = true,
      },
      black = {
        command = 'black',
        stdin = true,
        prepend_args = { '--line-length', '88' }
      },
      biome = biome_cmd,
      buf = { command = 'buf', args = { 'format', '--write' }, stdin = false },
      cargo_leptosfmt = {
        command = 'cargo',
        args = function(ctx)
          local args = { 'leptosfmt' }
          if vim.fn.filereadable(ctx.filename) == 1 then
            table.insert(args,
              ctx.options and ctx.options.tailwind and
              '--experimental-tailwind' or nil)
            if ctx.options and ctx.options.check then
              table.insert(args, '--check')
            end
          end
          table.insert(args, ctx.filename)
          return vim.tbl_filter(function(arg)
            return arg
          end, args)
        end,
        stdin = false,
        condition = function(ctx)
          local cargo_toml = vim.fn.findfile('Cargo.toml',
            ctx.dirname .. ';')
          if cargo_toml == '' then return false end
          local lines = vim.fn.readfile(cargo_toml)
          for _, line in ipairs(lines) do
            if line:match('%f[%w]leptos%f[%W]') then
              return true
            end
          end
          return false
        end,
        cwd = function(ctx)
          return vim.fn.fnamemodify(ctx.dirname, ':h')
        end
      },
      clang_format = {
        command = 'clang-format',
        stdin = true,
        args = { '--assume-filename', '$FILENAME' },
        prepend_args = { '--style=file', '--fallback-style=llvm' }
        -- prepend_args = { '--style=file', '--fallback-style=webkit' },
        -- prepend_args = { '--style=file', '--fallback-style=microsoft' },
      },
      cljfmt = {
        command = 'cljfmt',
        stdin = true,
        args = { 'fix', '--stdin' }
      },
      cmake_format = {
        command = 'cmake-format',
        stdin = true,
        args = { '-' }
      },
      csharpier = {
        command = 'csharpier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME', '--print-width', '160' }
      },
      crystal_format = {
        command = 'crystal',
        args = { 'tool', 'format', '-' },
        stdin = true
      },
      cue_fmt = { command = 'cue', args = { 'fmt', '-' }, stdin = true },
      dart_format = {
        command = 'dart',
        args = { 'format', '--stdin-name', '$FILENAME' },
        stdin = true,
        prepend_args = { '--line-length', '120' }
      },
      dhall_format = { command = 'dhall', stdin = true, args = { 'format' } },
      djlint = {
        command = 'djlint',
        args = { '--reformat', '-' },
        stdin = true,
        prepend_args = { '--max-line-length', '160' }
      },
      dockerfmt = { command = 'dockerfmt', stdin = true },
      erlfmt = {
        command = 'erlfmt',
        stdin = true,
        args = { '--print-width', '160', '-' }
      },
      eslint = {
        command = 'eslint',
        stdin = true,
        args = {
          '--fix-to-stdout', '--stdin', '--stdin-filename',
          '$FILENAME'
        }
      },
      eslint_d = {
        command = 'eslint_d',
        args = {
          '--fix-to-stdout', '--stdin', '--stdin-filename',
          '$FILENAME'
        },
        stdin = true
      },
      fourmolu = {
        command = 'fourmolu',
        args = { '--stdin-input-file', '$FILENAME' },
        stdin = true
      },
      gleam_format = {
        command = 'gleam',
        args = { 'format', '--stdin' },
        stdin = true
      },
      gofumpt = { command = 'gofumpt', stdin = true },
      goimports = { command = 'goimports', stdin = true },
      ['graphql-format'] = {
        command = 'prettier',
        stdin   = true,
        args    = {
          '--parser', 'graphql',
          '--stdin-filepath', '$FILENAME',
        },
      },
      groovy_format = {
        command = 'npm-groovy-lint',
        stdin = false,
        args = { '--format', '$FILENAME' }
      },
      helm_format = { command = 'yamlfmt', args = { '-' }, stdin = true },
      jsonnetfmt = { command = 'jsonnetfmt', stdin = true },
      isort = {
        command = 'isort',
        stdin = true,
        args = { '--profile', 'black', '--line-length', '160', '-' }
      },
      julia_format = {
        command = 'julia',
        stdin = true,
        args = {
          '-e',
          'using JuliaFormatter; print(format_text(read(stdin, String)))'
        }
      },
      jq = { command = 'jq', stdin = true, args = { '--tab', '.' } },
      just_fmt = {
        command = 'just',
        args = { '--fmt', '--unstable' },
        stdin = false
      },
      ktlint = {
        command = 'ktlint',
        stdin = true,
        args = { '--format', '--stdin' }
      },
      latexindent = {
        command = 'latexindent',
        stdin = true,
        args = { '-', '--silent', '--local' },
        ignore_exitcode = true
      },
      ['lua-format'] = {
        command = 'lua-format',
        stdin = true,
        prepend_args = {
          '--indent-width=2', '--tab-width=2', '--use-tab=false',
          '--column-limit=160', '--continuation-indent-width=2',
          '--spaces-before-call=1',
          '--keep-simple-control-block-one-line=false',
          '--keep-simple-function-one-line=false',
          '--break-before-function-call-rp=false',
          '--break-before-function-def-rp=false',
          '--chop-down-table=false'
        }
      },
      mdformat = {
        command = 'mdformat',
        stdin = true,
        args = {
          '--wrap', '160', '--end-of-line', 'lf', '--number',
          '--extensions', 'tables,gfm,admonition,mkdocs',
          '--align-semantic-breaks-in-lists', '-'
        }
      },
      mix_format = { command = 'mix', args = { 'format', '-' }, stdin = true },
      nginx_config_formatter = {
        command = 'nginx-config-formatter',
        args = { '$FILENAME' },
        stdin = false
      },
      nixfmt = { command = 'nixfmt', stdin = true, args = {} },
      nixpkgs_fmt = { command = 'nixpkgs-fmt', stdin = true, args = {} },
      ocamlformat = {
        command = 'ocamlformat',
        args = { '--name', '$FILENAME', '-' },
        stdin = true
      },
      npm_groovy_lint = {
        command = 'npm-groovy-lint',
        stdin = true,
        args = { '--format', '--stdin' }
      },
      perltidy = {
        command = 'perltidy',
        stdin = true,
        args = { '-st', '-i=2', '-l=160' }
      },
      php_cs_fixer = {
        command = 'php-cs-fixer',
        stdin = true,
        args = { 'fix', '--using-cache=no', '$FILENAME' }
      },
      phpcbf = {
        command = 'phpcbf',
        stdin = true,
        args = { '--standard=PSR12' }
      },
      prettier = {
        command = 'prettier',
        args = { '--stdin-filepath', '$FILENAME' },
        stdin = true,
        prepend_args = {
          '--config',
          vim.fn.expand('~/.diver/js/prettier/default.json'),
          '--ignore-path',
          vim.fn.expand('~/.diver/js/prettier/.prettierignore')
        }
      },
      prettier_css = {
        command = 'prettier',
        args = { '--stdin-filepath', '$FILENAME' },
        stdin = true,
        prepend_args = {
          '--parser', 'css', '--print-width', '160', '--tab-width',
          '2', '--single-quote', 'false'
        }
      },
      prettierd = {
        command = 'prettierd',
        args = { '--stdin-filepath', '$FILENAME' },
        stdin = true
      },
      prettier_html = {
        command = 'prettier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME' },
        prepend_args = {
          '--parser', 'html', '--print-width', '160', '--tab-width',
          '2'
        }
      },
      ['prettier-markdown'] = {
        command = 'prettier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME' },
        prepend_args = {
          '--parser', 'markdown', '--print-width', '160',
          '--tab-width', '2'
        }
      },
      prettier_solidity = {
        command = 'prettier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME' },
        prepend_args = {
          '--parser', 'solidity', '--print-width', '160',
          '--tab-width', '2'
        }
      },
      prettier_yaml = {
        command = 'prettier',
        stdin = true,
        args = { '--parser', 'yaml' }
      },
      prisma_format = {
        command = 'prisma',
        stdin = false,
        args = { 'format' }
      },
      ['prisma-fmt'] = {
        command = 'prisma-fmt',
        stdin = true,
        args = { '--stdin' }
      },
      ['qiskit-format'] = {
        cmd = 'python',
        stdin = true,
        args = {
          '-c',
          'import black; import sys; print(black.format_str(sys.stdin.read(), mode=black.FileMode()))'
        },
        stream = 'stdout',
        ignore_exitcode = true
      },
      ruff = {
        command = 'ruff',
        args = { 'format', '--stdin-filename', '$FILENAME' },
        stdin = true
      },
      ruff_format = {
        command = 'ruff',
        stdin = true,
        args = { 'format', '--stdin-filename', '$FILENAME', '-' }
      },
      ruff_organize_imports = {
        command = 'ruff',
        stdin = true,
        args = {
          'check', '--select', 'I', '--fix', '--stdin-filename',
          '$FILENAME', '-'
        }
      },
      rustfmt = {
        prepend_args = {
          '--edition=2024', '--emit=stdout', '--color=always'
        }
      },
      shfmt = {
        command = 'shfmt',
        args = { '-i', '2', '-ci', '-' },
        stdin = true
      },
      ['stylish-haskell'] = {
        cmd = 'stylish-haskell',
        stdin = true,
        args = {},
        stream = 'stdout',
        ignore_exitcode = true
      },
      rubocop = {
        command = 'rubocop',
        stdin = true,
        args = { '--auto-correct', '-f', 'quiet', '--stdin', '$FILENAME' }
      },
      shellcheck = {
        command = 'shellcheck',
        stdin = true,
        args = { '--format=diff', '-' }
      },
      scalafmt = { command = 'scalafmt', stdin = true, args = { '--stdin' } },
      stylelint = {
        command = 'stylelint',
        args = { '--fix', '--stdin', '--stdin-filename', '$FILENAME' },
        stdin = true
      },
      standardrb = {
        command = 'standardrb',
        stdin = true,
        args = { '--fix', '--stdin', '$FILENAME' }
      },
     {
  command = 'stylua',
  stdin = true,
  prepend_args = function()
    return {
      '--indent-type', 'Spaces',
      '--indent-width', '2',
      '--column-width', '160',
      '--quote-style', 'AutoPreferSingle',
      '--call-parentheses', 'None',
      '--collapse-simple-statement', 'Always',
    }
  end
    },
    styler = {
      command = 'Rscript',
      stdin = true,
      args = { '-e', [[styler::style_text(readLines("stdin"))]] }
    },
    sqlfluff = {
      command = 'sqlfluff',
      stdin = true,
      args = { 'format', '--dialect', 'postgres', '-' },
      cwd = function() return vim.fn.getcwd() end
    },
    ['sql-formatter'] = {
      command = 'sql-formatter',
      stdin = true,
      args = { '--language', 'postgresql' }
    },
    svelte_format = {
      command = 'prettier',
      args = { '--plugin-search-dir=.', '--parser', 'svelte' },
      stdin = true
    },
    swift_format = {
      command = 'swiftformat',
      stdin = true,
      args = { '--stdinpath', '$FILENAME' },
      prepend_args = { '--indent', '2', '--allman', 'false' }
    },
    swiftui = { 'swift_format' },
    terraform_fmt = {
      command = 'terraform',
      args = { 'fmt', '-' },
      stdin = true
    },
    taplo = { command = 'taplo', stdin = true, args = { 'format', '-' } },
    ['tex-fmt'] = { command = 'tex-fmt', stdin = true, args = { '--stdin' } },
    ['toml-sort'] = { command = 'toml-sort', stdin = true, args = {} },
  xmlformat = {
  {
    command = "xmlformat",
    args = { "--indent", "2", "--selfclose", "yes", "--collapse-emptyelement", "yes" },
    stdin = true,
  },
},
  yamlfmt = { command = 'yamlfmt', stdin = true, args = { '-' } },
    yq = { command = 'yq', stdin = true, args = { '.' } },
    zigfmt = {
      command = 'zig',
      args = { 'fmt', '--stdin' },
      stdin = true,
      exit_codes = { 0, 1 }
    },
    zigfmt_check = {
      command = 'zig',
      args = { 'fmt', '--check', '--stdin' },
      stdin = true,
      exit_codes = { 0, 1 }
    },
    zigfmt_ast = {
      command = 'zig',
      args = { 'fmt', '--ast-check', '--stdin' },
      stdin = true,
      exit_codes = { 0, 1 }
    }
  }
function M.conform_cfg(opts)
  opts = opts or {}
  return {
    formatters_by_ft = opts.formatters_by_ft or M.formatters_by_ft,
    default_format_opts = opts.default_format_opts or M.default_format_opts,
    format_on_save = opts.format_on_save or M.format_on_save,
    format_after_save = opts.format_after_save or M.format_after_save,
    log_level = opts.log_level or M.log_level,
    notify_on_error = opts.notify_on_error ~= false,
    notify_no_formatters = opts.notify_no_formatters ~= false,
    formatters = opts.formatters or M.formatters,
  }
end

return M
