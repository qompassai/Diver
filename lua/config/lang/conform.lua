---~/.config/nvim/lua/config/lang/conform.lua
---------------------------------------------
---@module 'config.lang.conform'
local M = {}

---@class ConformConfig
---@field default_format_opts? table
---@field formatters? table<string, table>
---@field formatters_by_ft? table<string, string[]>
---@field format_on_save? boolean|table
---@field format_after_save? boolean|table
---@field notify_on_error? boolean
---@field notify_no_formatters? boolean
---@field log_level? integer

---@param opts? ConformConfig
---@return ConformConfig
function M.conform_setup(opts)
  opts = opts or {}
  return {
    formatters_by_ft = opts.formatters_by_ft or {
      ['_'] = { 'trim_whitespace' },
      asm = { 'asmfmt' },
      ansible = { 'prettier', 'yamlfmt' },
      astro = { 'prettier', 'biome' },
      bash = { 'shfmt', 'shellcheck' },
      c = { 'clang_format', 'uncrustify' },
      clojure = { 'cljfmt' },
      cmake = { 'cmake_format' },
      conf = { 'trim_whitespace' },
      cpp = { 'clang_format' },
      csharp = { 'csharpier' },
      css = { 'biome_css', 'stylelint' },
      cue = { 'cue_fmt' },
      dart = { 'dart_format' },
      dhall = { 'dhall_format' },
      dockerfile = { 'dockerfmt' },
      elixir = { 'mix_format' },
      elm = { 'elm_format' },
      erlang = { 'erlfmt' },
      fish = { 'fish_indent' },
      gleam = { 'gleam_format' },
      go = { 'goimports', 'gofumpt' },
      groovy = { 'npm_groovy_lint' },
      html = { 'biome_html', 'djlint', 'prettier_html' },
      javascript = { 'biome', 'eslint_d', 'prettierd' },
      javascriptreact = { 'biome', 'eslint_d', 'prettierd' },
      json = { 'biome', 'jq', 'prettierd' },
      jsonc = { 'biome', 'prettierd' },
      jsonnet = { 'jsonnetfmt' },
      json5 = { 'prettierd' },
      julia = { 'julia_format' },
      just = { 'just_fmt' },
      justfile = { 'just_fmt' },
      handlebars = { 'prettier' },
      haskell = { 'ormolu', 'fourmolu' },
      hcl = { 'terraform_fmt' },
      helm = { 'helm_format' },
      htmlangular = { 'prettier_html' },
      htmldjango = { 'djlint' },
      java = { 'google-java-format' },
      kotlin = { 'ktlint' },
      latex = { 'tex-fmt', 'latexindent' },
      lua = { 'stylua', 'lua-format' },
      luau = { 'stylua' },
      markdown = { 'prettier-markdown', 'mdformat' },
      ['markdown.mdx'] = { 'prettier-markdown' },
      nix = { 'alejandra', 'nixfmt', 'nixpkgs-fmt' },
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
      scss = { 'stylelint', 'prettier_css' },
      sass = { 'stylelint', 'prettier_css' },
      sh = { 'shfmt' },
      solidity = { 'prettier_solidity' },
      sql = { 'sqlfluff', 'sql-formatter' },
      sqlite = { 'sqlfluff' },
      svelte = { 'prettier', 'svelte_format' },
      swift = { 'swift_format' },
      tex = { 'latexindent' },
      terraform = { 'terraform_fmt' },
      toml = { 'toml-sort', 'taplo' },
      tsx = { 'biome', 'eslint_d', 'prettierd' },
      typescript = { 'biome', 'eslint_d', 'prettierd' },
      typescriptreact = { 'biome', 'eslint_d', 'prettierd' },
      vue = { 'prettierd' },
      xml = { 'xmllint' },
      yaml = { 'yamlfmt', 'yq', 'prettier_yaml', 'prettierd' },
      yml = { 'yamlfmt', 'yq', 'prettier_yaml', 'prettierd' },
      zig = { 'zigfmt', 'zigfmt_ast' },
      zsh = { 'shfmt', 'shellcheck' },
    },
     default_format_opts = opts.default_format_opts or { lsp_format = 'fallback' },
  format_on_save = {
    lsp_fallback = true,
    lsp_format = 'fallback',
    timeout_ms = 2000,
    undojoin = true,
    stop_after_first = false,
    exclude = { 'spell', 'codespell' },
  },
  format_after_save = opts.format_after_save or {
    enabled = true,
    lsp_format = 'fallback',
    timeout_ms = 1000,
    undojoin = true,
  },
  log_level = opts.log_level or vim.log.levels.ERROR,
  notify_on_error = opts.notify_on_error ~= false,
  notify_no_formatters = opts.notify_no_formatters ~= false,
  formatters = opts.formatters or {
      alejandra = {
        command = 'alejandra',
        stdin = true,
        args = {},
      },
      asmfmt = {
        command = 'asmfmt',
        stdin = true,
        args = {},
      },
      black = {
        command = 'black',
        stdin = true,
        prepend_args = { '--line-length', '88' },
      },
      biome = {
        command = 'biome',
        args = { 'format', '--stdin-file-path', '$FILENAME' },
        stdin = true,
        prepend_args = { '--line-width', '160' },
      },
      biome_css = {
        command = 'biome',
        args = { 'format', '--stdin-file-path', '$FILENAME' },
        stdin = true,
        prepend_args = { '--line-width', '160' },
      },
      biome_html = {
        command = 'biome',
        args = { 'format', '--stdin-file-path', '$FILENAME' },
        stdin = true,
      },
      buf = {
        command = 'buf',
        args = { 'format', '--write' },
        stdin = false,
      },
      cargo_leptos_fmt = {
        command = 'cargo',
        args = { 'leptosfmt' },
        stdin = false,
        condition = function(ctx)
          local cargo_toml = vim.fn.findfile('Cargo.toml', ctx.dirname .. ';')
          if cargo_toml == '' then
            return false
          end
          local lines = vim.fn.readfile(cargo_toml)
          for _, line in ipairs(lines) do
            if line:match('%f[%w]leptos%f[%W]') then
              return true
            end
          end
          return false
        end,
      },
      clang_format = {
        command = 'clang-format',
        stdin = true,
        args = { '--assume-filename', '$FILENAME' },
        prepend_args = { '--style=file', '--fallback-style=llvm' },
        -- prepend_args = { '--style=file', '--fallback-style=webkit' },
        -- prepend_args = { '--style=file', '--fallback-style=microsoft' },
      },
      cljfmt = {
        command = 'cljfmt',
        stdin = true,
        args = { 'fix', '--stdin' },
      },
      cmake_format = {
        command = 'cmake-format',
        stdin = true,
        args = { '-' },
      },
      csharpier = {
        command = 'csharpier',
        stdin = true,
        args = {
          '--stdin-filepath',
          '$FILENAME',
          '--print-width',
          '160',
        },
      },
      crystal_format = {
        command = 'crystal',
        args = { 'tool', 'format', '-' },
        stdin = true,
      },
      cue_fmt = {
        command = 'cue',
        args = { 'fmt', '-' },
        stdin = true,
      },
      dart_format = {
        command = 'dart',
        args = { 'format', '--stdin-name', '$FILENAME' },
        stdin = true,
        prepend_args = { '--line-length', '120' },
      },
      dhall_format = {
        command = 'dhall',
        stdin = true,
        args = { 'format' },
      },
      djlint = {
        command = 'djlint',
        args = { '--reformat', '-' },
        stdin = true,
        prepend_args = { '--max-line-length', '160' },
      },
      dockerfmt = {
        command = 'dockerfmt',
        stdin = true,
      },
      erlfmt = {
        command = 'erlfmt',
        stdin = true,
        args = { '--print-width', '160', '-' },
      },
      eslint = {
        command = 'eslint',
        stdin = true,
        args = { '--fix-to-stdout', '--stdin', '--stdin-filename', '$FILENAME' },
      },
      eslint_d = {
        command = 'eslint_d',
        args = { '--fix-to-stdout', '--stdin', '--stdin-filename', '$FILENAME' },
        stdin = true,
      },
      fourmolu = {
        command = 'fourmolu',
        args = { '--stdin-input-file', '$FILENAME' },
        stdin = true,
      },
      gleam_format = {
        command = 'gleam',
        args = { 'format', '--stdin' },
        stdin = true,
      },
      gofumpt = {
        command = 'gofumpt',
        stdin = true,
      },
      goimports = {
        command = 'goimports',
        stdin = true,
      },
      groovy_format = {
        command = 'npm-groovy-lint',
        stdin = false,
        args = { '--format', '$FILENAME' },
      },
      helm_format = {
        command = 'yamlfmt',
        args = { '-' },
        stdin = true,
      },
      jsonnetfmt = {
        command = 'jsonnetfmt',
        stdin = true,
      },
      isort = {
        command = 'isort',
        stdin = true,
        args = { '--profile', 'black', '--line-length', '160', '-' },
      },
      julia_format = {
        command = 'julia',
        stdin = true,
        args = {
          '-e',
          'using JuliaFormatter; print(format_text(read(stdin, String)))',
        },
      },
      juliaformatter = {
        command = 'julia',
        stdin = false,
        args = {
          '-e',
          'using JuliaFormatter; format("$FILENAME")',
        },
      },
      jq = {
        command = 'jq',
        stdin = true,
        args = { '--tab', '.' },
      },
      just_fmt = {
        command = 'just',
        args = { '--fmt', '--unstable' },
        stdin = false,
      },
      ktlint = {
        command = 'ktlint',
        stdin = true,
        args = { '--format', '--stdin' },
      },
      latexindent = {
        command = 'latexindent',
        stdin = true,
        args = {
          '-',
          '--silent',
          '--local',
        },
      },
        ['lua-format'] = {
        command = 'lua-format',
        stdin = true,
        prepend_args = {
          '--indent-width=2',
          '--tab-width=2',
          '--use-tab=false',
          '--column-limit=160',
          '--continuation-indent-width=2',
          '--spaces-before-call=1',
          '--keep-simple-control-block-one-line=false',
          '--keep-simple-function-one-line=false',
          '--break-before-function-call-rp=false',
          '--break-before-function-def-rp=false',
          '--chop-down-table=false',
        },
      },
      mdformat = {
        command = 'mdformat',
        stdin = true,
        args = {
          '--wrap',
          '160',
          '--end-of-line',
          'lf',
          '--number',
          '--extensions',
          'tables,gfm,admonition,mkdocs',
          '--align-semantic-breaks-in-lists',
          '-',
        },
      },
      mix_format = {
        command = 'mix',
        args = { 'format', '-' },
        stdin = true,
      },
      nginx_config_formatter = {
        command = 'nginx-config-formatter',
        args = { '$FILENAME' },
        stdin = false,
      },
      nixfmt = {
        command = 'nixfmt',
        stdin = true,
        args = {},
      },
      nixpkgs_fmt = {
        command = 'nixpkgs-fmt',
        stdin = true,
        args = {},
      },
      ocamlformat = {
        command = 'ocamlformat',
        args = { '--name', '$FILENAME', '-' },
        stdin = true,
      },
      npm_groovy_lint = {
        command = 'npm-groovy-lint',
        stdin = true,
        args = { '--format', '--stdin' },
      },
      perltidy = {
        command = 'perltidy',
        stdin = true,
        args = {
          '-st',
          '-i=2',
          '-l=160',
        },
      },
      php_cs_fixer = {
        command = 'php-cs-fixer',
        stdin = true,
        args = { 'fix', '--using-cache=no', '$FILENAME' },
      },
      phpcbf = {
        command = 'phpcbf',
        stdin = true,
        args = { '--standard=PSR12' },
      },
      prettier = {
  command = 'prettier',
  args = { '--stdin-filepath', '$FILENAME' },
  stdin = true,
  prepend_args = {
    '--config', vim.fn.expand('~/.diver/js/prettier/default.json'),
    '--ignore-path', vim.fn.expand('~/.diver/js/prettier/.prettierignore')
  }
},
      prettier_css = {
        command = 'prettier',
        args = { '--stdin-filepath', '$FILENAME' },
        stdin = true,
        prepend_args = {
          '--parser',
          'css',
          '--print-width',
          '160',
          '--tab-width',
          '2',
          '--single-quote',
          'false',
        },
      },
      prettierd = {
        command = 'prettierd',
        args = { '--stdin-filepath', '$FILENAME' },
        stdin = true,
      },
      prettier_html = {
        command = 'prettier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME' },
        prepend_args = { '--parser', 'html', '--print-width', '160', '--tab-width', '2' },
      },
      ['prettier-markdown'] = {
        command = 'prettier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME' },
        prepend_args = { '--parser', 'markdown', '--print-width', '160', '--tab-width', '2' },
      },
      prettier_solidity = {
        command = 'prettier',
        stdin = true,
        args = { '--stdin-filepath', '$FILENAME' },
        prepend_args = {
          '--parser',
          'solidity',
          '--print-width',
          '160',
          '--tab-width',
          '2',
        },
      },
      prettier_yaml = {
        command = 'prettier',
        stdin = true,
        args = { '--parser', 'yaml' },
      },
      prisma_format = {
        command = 'prisma',
        stdin = false,
        args = { 'format' },
      },
      ['prisma-fmt'] = {
        command = 'prisma-fmt',
        stdin = true,
        args = { '--stdin' },
      },
      ruff = {
        command = 'ruff',
        args = { 'format', '--stdin-filename', '$FILENAME' },
        stdin = true,
      },
      ruff_format = {
        command = 'ruff',
        stdin = true,
        args = { 'format', '--stdin-filename', '$FILENAME', '-' },
      },
      ruff_organize_imports = {
        command = 'ruff',
        stdin = true,
        args = { 'check', '--select', 'I', '--fix', '--stdin-filename', '$FILENAME', '-' },
      },
      rustfmt = {
        prepend_args = {
          '--edition=2024',
          '--emit=stdout',
          '--color=never',
        },
      },
      shfmt = {
        command = 'shfmt',
        args = { '-i', '2', '-ci', '-' },
        stdin = true,
      },
      rubocop = {
        command = 'rubocop',
        stdin = true,
        args = { '--auto-correct', '-f', 'quiet', '--stdin', '$FILENAME' },
      },
      shellcheck = {
        command = 'shellcheck',
        stdin = true,
        args = { '--format=diff', '-' },
      },
      scalafmt = {
        command = 'scalafmt',
        stdin = true,
        args = { '--stdin' },
      },
      stylelint = {
        command = 'stylelint',
        args = { '--fix', '--stdin', '--stdin-filename', '$FILENAME' },
        stdin = true,
      },
      standardrb = {
        command = 'standardrb',
        stdin = true,
        args = { '--fix', '--stdin', '$FILENAME' },
      },
      stylua = {
        command = 'stylua',
        stdin = true,
        prepend_args = function(_, ctx)
          local filename = ctx and ctx.filename or ''
          local is_openresty = filename:match('/nginx/') or filename:match('/openresty/')
          local lua_version = is_openresty and 'LuaJIT' or 'Lua51'
          return {
            '--indent-type',
            'Spaces',
            '--indent-width',
            '2',
            '--column-width',
            '160',
          }
        end,
      },
      styler = {
        command = 'Rscript',
        stdin = true,
        args = { '-e', [[styler::style_text(readLines("stdin"))]] },
      },
      sqlfluff = {
        command = 'sqlfluff',
        stdin = true,
        args = { 'format', '--dialect', 'postgres', '-' },
        cwd = function()
          return vim.fn.getcwd()
        end,
      },
      ['sql-formatter'] = {
        command = 'sql-formatter',
        stdin = true,
        args = { '--language', 'postgresql' },
      },
      svelte_format = {
        command = 'prettier',
        args = { '--plugin-search-dir=.', '--parser', 'svelte' },
        stdin = true,
      },
      swift_format = {
        command = 'swiftformat',
        stdin = true,
        args = { '--stdinpath', '$FILENAME' },
        prepend_args = { '--indent', '2', '--allman', 'false' },
      },
      swiftui = { 'swift_format' },
      terraform_fmt = {
        command = 'terraform',
        args = { 'fmt', '-' },
        stdin = true,
      },
      taplo = {
        command = 'taplo',
        stdin = true,
        args = { 'format', '-' },
      },
      ['tex-fmt'] = {
        command = 'tex-fmt',
        stdin = true,
        args = { '--stdin' },
      },
      ['toml-sort'] = {
        command = 'toml-sort',
        stdin = true,
        args = {},
      },
      xmllint = {
        command = 'xmllint',
        args = { '--format', '-' },
        stdin = true,
      },
      yamlfmt = {
        command = 'yamlfmt',
        stdin = true,
        args = { '-' },
      },
      yq = {
        command = 'yq',
        stdin = true,
        args = { '.' },
      },
      zigfmt = {
        command = 'zig',
        args = { 'fmt', '--stdin' },
        stdin = true,
        exit_codes = { 0, 1 },
      },
      zigfmt_check = {
        command = 'zig',
        args = { 'fmt', '--check', '--stdin' },
        stdin = true,
        exit_codes = { 0, 1 },
      },
      zigfmt_ast = {
        command = 'zig',
        args = { 'fmt', '--ast-check', '--stdin' },
        stdin = true,
        exit_codes = { 0, 1 },
      },
    },
  }
end
---@return ConformConfig
return M
