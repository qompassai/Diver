-- qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lint Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.setup_linters(lint)
  lint.linters_by_ft = {
    ['*'] = { 'codespell' },
    ansible = { 'ansible-lint', 'yamllint' },
    avro = { 'avro-tools' },
    asciidoc = { 'asciidoctor' },
    arduino = { 'arduino-cli' },
    asm = { 'nasm' },
    astro = { 'eslint_d' },
    bash = { 'shellcheck', 'bashate' },
    bicep = { 'bicep' },
    c = { 'cppcheck', 'clang-tidy' },
    clojure = { 'clj-kondo' },
    cmake = { 'cmake-lint' },
    compute = { 'glslang' },
    conf = { 'editorconfig-checker' },
    cpp = { 'cppcheck', 'clang-tidy' },
    css = { 'csslint', 'stylint' },
    cuda = { 'nvcc', 'nvc', 'clang-tidy' },
    cue = { 'cue' },
    dhall = { 'dhall' },
    dockerfile = { 'hadolint', 'dockerfilelint' },
    editorconfig = { 'editorconfig-checker' },
    elixir = { 'credo' },
    fish = { 'fish-syntax' },
    fix = { 'fix-validator' },
    github_actions = { 'actionlint' },
    glsl = { 'glslang' },
    go = { 'golangci-lint', 'gosec' },
    graphql = { 'graphql-eslint' },
    haskell = { 'hlint' },
    hlsl = { 'hlsl' },
    html = { 'htmlhint', 'tidy' },
    hocon = { 'hocon-check' },
    ini = { 'editorconfig-checker' },
    java = { 'checkstyle', 'pmd' },
    javascript = { 'eslint_d', 'biomejs' },
    javascriptreact = { 'eslint_d', 'biomejs' },
    json = { 'jsonlint', 'jq' },
    jsonc = { 'jsonlint' },
    julia = { 'julia' },
    kotlin = { 'ktlint' },
    latex = { 'chktex', 'lacheck' },
    less = { 'stylelint' },
    lua = { 'luacheck', 'selene' },
    mlir = { 'mlir-opt' },
    mojo = { 'mojo-check' },
    markdown = { 'markdownlint', 'vale', 'textlint' },
    mdx = { 'markdownlint', 'eslint_d' },
    meson = { 'meson' },
    mql4 = { 'mql-check' },
    mql5 = { 'mql-check' },
    nix = { 'deadnix', 'statix' },
    opencl = { 'clang' },
    openqasm = { 'qiskit-terra' },
    parquet = { 'parquet-tools' },
    perl = { 'perlcritic' },
    pine = { 'pine-lint' },
    plsql = { 'sqlfluff' },
    phpcs = { 'phpstan', 'php-cs-fixer-lint' },
    powershell = { 'PSScriptAnalyzer' },
    proto = { 'protoc' },
    protobuf = { 'protoc' },
    python = { 'ruff', 'mypy', 'bandit', 'vulture' },
    qsharp = { 'qsharp-analyzer' },
    quil = { 'pyquil-check' },
    r = { 'lintr' },
    renderdoc = { 'renderdoc-check' },
    ruby = { 'rubocop', 'reek' },
    rust = { 'clippy' },
    rst = { 'doc8' },
    sass = { 'stylelint' },
    scala = { 'scalastyle' },
    scss = { 'stylelint' },
    sh = { 'shellcheck', 'bashate' },
    sql = { 'sqlfluff' },
    svelte = { 'eslint_d' },
    swift = { 'swiftlint' },
    systemverilog = { 'verilator' },
    terraform = { 'tflint', 'tfsec' },
    tex = { 'chktex', 'lacheck' },
    toml = { 'taplo' },
    typescript = { 'eslint_d', 'biomejs' },
    typescriptreact = { 'eslint_d', 'biomejs' },
    unity = { 'unity-analyzer' },
    verilog = { 'verilator' },
    vhdl = { 'ghdl' },
    vim = { 'vint' },
    vue = { 'eslint_d' },
    wasm = { 'wasm-validate' },
    wat = { 'wat2wasm' },
    x86asm = { 'nasm', 'yasm' },
    xml = { 'xmllint' },
    yml = { 'yamllint' },
    yaml = { 'yamllint' },
    zig = { 'zigfmt_check', 'zlint' },
    zsh = { 'shellcheck' }
  }
  lint.linters.actionlint = {
    cmd = 'actionlint',
    stdin = true,
    args = { '-format', '{{json .}}', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for line in output:gmatch('[^\r\n]+') do
        local ok, decoded = pcall(vim.json.decode, line)
        if ok and decoded then
          table.insert(diagnostics, {
            lnum = (decoded.line or 1) - 1,
            col = (decoded.column or 1) - 1,
            message = decoded.message,
            severity = decoded.kind == 'error' and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'actionlint'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['ansible-lint'] = {
    cmd = 'ansible-lint',
    stdin = false,
    args = { '--parseable-severity', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, severity, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = severity == 'error' and
                vim.diagnostic.severity.ERROR or severity ==
                'warning' and vim.diagnostic.severity.WARN or
                vim.diagnostic.severity.INFO,
            source = 'ansible-lint'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['arduino-cli'] = {
    cmd = 'arduino-cli',
    stdin = false,
    args = { 'compile', '--verify', '--format', 'json' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for line in output:gmatch('[^\r\n]+') do
        local ok, decoded = pcall(vim.json.decode, line)
        if ok and decoded.error then
          table.insert(diagnostics, {
            lnum = 0,
            col = 0,
            message = decoded.error,
            severity = vim.diagnostic.severity.ERROR,
            source = 'arduino-cli'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.asciidoctor = {
    cmd = 'asciidoctor',
    stdin = true,
    args = { '--safe-mode', 'safe', '--trace', '-o', '/dev/null', '-' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[asciidoctor: (%w+): ([^:]+): line (%d+): (.+)]],
    groups = { 'severity', 'file', 'lnum', 'message' }
  }
  lint.linters['avro-tools'] = {
    cmd = 'avro-tools',
    stdin = false,
    args = { 'compile', 'schema' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'message' }
  }
  lint.linters.bandit = {
    cmd = 'bandit',
    stdin = true,
    args = {
      '-f', 'custom', '--msg-template',
      '{abspath}:{line}: {severity}: {msg}', '-'
    },
    stream = 'stdout',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters.bashate = {
    cmd = 'bashate',
    stdin = true,
    args = {},
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        -- Example bashate output: "filename:line:col: [E001] message"
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+):%s*%[[^%]]+%]%s*(.+)')
        if fname and lnum and msg then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'bashate'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.bicep = {
    cmd = 'bicep',
    stdin = false,
    args = { 'build', '--outdir', '/tmp' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+)\((%d+),(%d+)\): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.biomejs = {
    cmd = 'biome',
    stdin = true,
    args = {
      'check', '--stdin-file-path',
      function() return vim.api.nvim_buf_get_name(0) end
    },
    stream = 'stdout',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.checkstyle = {
    cmd = 'checkstyle',
    stdin = false,
    args = { '-c', '/path/to/checkstyle.xml', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('error') and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'checkstyle'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.clippy = {
    cmd = 'cargo',
    stdin = false,
    args = {
      'clippy', '--message-format=json', '--all-targets',
      '--all-features', '--', '--force-clippy-unstable', '-W',
      'clippy::pedantic', '-W', 'clippy::nursery'
    },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for line in output:gmatch('[^\r\n]+') do
        local ok, decoded = pcall(vim.json.decode, line)
        if ok and decoded and decoded.message and decoded.message.spans then
          local msg = decoded.message.message
          for _, span in ipairs(decoded.message.spans) do
            table.insert(diagnostics, {
              lnum = span.line_start - 1,
              col = span.column_start - 1,
              end_lnum = span.line_end - 1,
              end_col = span.column_end - 1,
              message = msg,
              severity = decoded.message.level == 'error' and
                  vim.diagnostic.severity.ERROR or
                  vim.diagnostic.severity.WARN,
              source = 'clippy::' ..
                  (decoded.message.code and
                    decoded.message.code.code or 'unknown')
            })
          end
        end
      end
      return diagnostics
    end
  }
  lint.linters.clang = {
    cmd = 'clang',
    stdin = false,
    args = { '-fsyntax-only', '-Wall', '-Wextra', '-Werror', '$FILENAME' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('error') and
                vim.diagnostic.severity.ERROR or
                line:match('warning') and
                vim.diagnostic.severity.WARN or
                vim.diagnostic.severity.INFO,
            source = 'clang'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.clang_tidy = {
    cmd = 'clang-tidy',
    stdin = false,
    args = { '--quiet', '--extra-arg=-std=c++20', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('error') and
                vim.diagnostic.severity.ERROR or
                line:match('warning') and
                vim.diagnostic.severity.WARN or
                vim.diagnostic.severity.INFO,
            source = 'clang-tidy'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['cmake-lint'] = {
    cmd = 'cmake-lint',
    stdin = true,
    args = { '--format', 'json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, issue in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (issue.line or 1) - 1,
          col = (issue.column or 1) - 1,
          message = issue.message,
          severity = issue.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'cmake-lint',
          code = issue.rule
        })
      end
      return diagnostics
    end
  }
  lint.linters.codespell = {
    cmd = 'codespell',
    stdin = true,
    args = { '--stdin-single-line', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output, bufnr, cwd)
      local pattern = '(%d+): (.*)'
      local groups = { 'lnum', 'message' }
      local parser = require('lint.parser').from_pattern(pattern, groups,
        nil, {
          source = 'codespell',
          severity = vim.diagnostic.severity.INFO
        })
      local result = parser(output, bufnr, cwd)
      for _, d in ipairs(result) do
        local start, _, capture = d.message:find('(.*) ==>')
        if start then
          local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr,
            d.lnum, d.lnum + 1, true)
          if ok then
            local line = lines[1] or ''
            local start_col, end_col = line:find(vim.pesc(capture))
            if start_col then
              d.col = start_col - 1
              d.end_col = end_col
            end
          end
        end
      end
      return result
    end
  }
  lint.linters.cppcheck = {
    cmd = 'cppcheck',
    stdin = false,
    args = {
      '--enable=warning,style,performance,information,missingInclude',
      '--suppress=missingIncludeSystem', '--inline-suppr', '--std=c++20',
      '$FILENAME'
    },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('error') and
                vim.diagnostic.severity.ERROR or
                line:match('warning') and
                vim.diagnostic.severity.WARN or
                vim.diagnostic.severity.INFO,
            source = 'cppcheck'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.credo = {
    cmd = 'mix',
    stdin = false,
    args = { 'credo', '--format', 'json', '--read-from-stdin' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.issues then
        return diagnostics
      end
      for _, issue in ipairs(decoded.issues) do
        table.insert(diagnostics, {
          lnum = (issue.line_no or 1) - 1,
          col = (issue.column or 1) - 1,
          message = issue.message,
          severity = issue.priority >= 10 and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'credo',
          code = issue.check
        })
      end
      return diagnostics
    end
  }
  lint.linters.csslint = {
    cmd = 'csslint',
    stdin = false,
    args = { '--format=compact', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+): line (%d+), col (%d+), ([^:]+) - (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('Error') and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'csslint'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.cue = {
    cmd = 'cue',
    stdin = false,
    args = { 'vet', '.' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'message' }
  }
  lint.linters.deadnix = {
    cmd = 'deadnix',
    stdin = false,
    args = { '--output-format=json', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if ok and decoded then
        for _, result in ipairs(decoded.results) do
          table.insert(diagnostics, {
            lnum = (result.line or 1) - 1,
            col = 0,
            message = result.message,
            severity = vim.diagnostic.severity.WARN,
            source = 'deadnix'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.dhall = {
    cmd = 'dhall',
    stdin = true,
    args = { '--explain', '--quiet' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'message' }
  }
  lint.linters.dockerfilelint = {
    cmd = 'dockerfilelint',
    stdin = false,
    args = { '-j' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, item in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (item.line or 1) - 1,
          col = 0,
          message = item.message,
          severity = item.category == 'Error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'dockerfilelint'
        })
      end
      return diagnostics
    end
  }
  lint.linters.doc8 = {
    cmd = 'doc8',
    stdin = false,
    args = { '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg = line:match(
          '([^:]+):(%d+):%s*(D%w+)%s*(.+)')
        if fname and lnum then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'doc8'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['editorconfig-checker'] = {
    cmd = 'editorconfig-checker',
    stdin = false,
    args = { '-no-color', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg = line:match('(.+):(%d+): (.+)')
        if fname and lnum and msg then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'editorconfig-checker'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.eslint_d = lint.linters.eslint_d or {}
  lint.linters.eslint_d.args = {
    '--no-warn-ignored', '--format', 'json', '--stdin', '--stdin-filename',
    function() return vim.api.nvim_buf_get_name(0) end
  }
  lint.linters['fish-syntax'] = {
    cmd = 'fish',
    stdin = true,
    args = { '-n' },
    stream = 'stderr',
    ignore_exitcode = false,
    parser = function(output)
      local diagnostics = {}
      local lnum, msg = output:match('Standard input:(%d+): (.+)')
      if lnum then
        table.insert(diagnostics, {
          lnum = tonumber(lnum) - 1,
          col = 0,
          message = msg,
          severity = vim.diagnostic.severity.ERROR,
          source = 'fish'
        })
      end
      return diagnostics
    end
  }
  lint.linters['fix-validator'] = {
    cmd = 'fix-validator',
    stdin = true,
    args = { '--json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, violation in ipairs(decoded.violations or {}) do
        table.insert(diagnostics, {
          lnum = (violation.line or 1) - 1,
          col = (violation.column or 1) - 1,
          message = violation.description,
          severity = violation.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'fix-validator',
          code = violation.rule
        })
      end
      return diagnostics
    end
  }
  lint.linters.ghdl = {
    cmd = 'ghdl',
    stdin = false,
    args = { '-s', '--std=08' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.glslang = {
    cmd = 'glslangValidator',
    stdin = false,
    args = { '-q', '$FILENAME' },
    stream = 'stderr',
    ignore_exitcode = false,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg =
            line:match('ERROR: ([^:]+):(%d+): (.+)')
        if not fname then
          fname, lnum, msg =
              line:match('WARNING: ([^:]+):(%d+): (.+)')
        end
        if fname and lnum then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = line:match('ERROR') and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'glslang'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['golangci-lint'] = {
    cmd = 'golangci-lint',
    stdin = false,
    args = { 'run', '--out-format', 'json', '--path-prefix', vim.fn.getcwd() },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.Issues then
        return diagnostics
      end
      for _, issue in ipairs(decoded.Issues) do
        table.insert(diagnostics, {
          lnum = (issue.Pos.Line or 1) - 1,
          col = (issue.Pos.Column or 1) - 1,
          message = issue.Text,
          severity = vim.diagnostic.severity.WARN,
          source = issue.FromLinter,
          code = issue.RuleId
        })
      end
      return diagnostics
    end
  }
  lint.linters.gosec = {
    cmd = 'gosec',
    stdin = false,
    args = { '-fmt', 'json', '-stdout', '-verbose', 'json', './...' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.Issues then
        return diagnostics
      end
      for _, issue in ipairs(decoded.Issues) do
        table.insert(diagnostics, {
          lnum = (tonumber(issue.line) or 1) - 1,
          col = (tonumber(issue.column) or 1) - 1,
          message = issue.details,
          severity = issue.severity == 'HIGH' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'gosec',
          code = issue.rule_id
        })
      end
      return diagnostics
    end
  }
  lint.linters.hadolint = {
    cmd = 'hadolint',
    stdin = true,
    args = { '--format', 'json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, item in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (item.line or 1) - 1,
          col = (item.column or 1) - 1,
          message = item.message,
          severity = item.level == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'hadolint',
          code = item.code
        })
      end
      return diagnostics
    end
  }
  lint.linters.hlint = {
    cmd = 'hlint',
    stdin = true,
    args = { '--json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, item in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (item.startLine or 1) - 1,
          col = (item.startColumn or 1) - 1,
          message = item.hint,
          severity = item.severity == 'Error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.INFO,
          source = 'hlint'
        })
      end
      return diagnostics
    end
  }
  lint.linters.hlsl = {
    cmd             = "dxc",
    args            = {
      "-T", "ps_6_0",
      "-E", "main",
      "%filepath",
    },
    stdin           = false,
    stream          = "stderr",
    ignore_exitcode = true,
  }
  lint.linters['hocon-check'] = {
    cmd = 'hocon-check',
    stdin = true,
    args = { '--json' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, error in ipairs(decoded.errors or {}) do
        table.insert(diagnostics, {
          lnum = (error.line or 1) - 1,
          col = (error.column or 1) - 1,
          message = error.message,
          severity = vim.diagnostic.severity.ERROR,
          source = 'hocon-check'
        })
      end
      return diagnostics
    end
  }
  lint.linters.htmlhint = {
    cmd = 'htmlhint',
    stdin = true,
    args = { '--format', 'json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, file_result in ipairs(decoded) do
        if file_result.messages then
          for _, message in ipairs(file_result.messages) do
            table.insert(diagnostics, {
              lnum = (message.line or 1) - 1,
              col = (message.col or 1) - 1,
              message = message.message,
              severity = message.type == 'error' and
                  vim.diagnostic.severity.ERROR or
                  vim.diagnostic.severity.WARN,
              source = 'htmlhint',
              code = message.rule.id
            })
          end
        end
      end
      return diagnostics
    end
  }
  lint.linters.jsonlint = {
    cmd = 'jsonlint',
    stdin = false,
    args = { '-c', '$FILENAME' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local lnum, msg = output:match(
        'Error: Parse error on line (%d+): (.+)')
      if lnum then
        table.insert(diagnostics, {
          lnum = tonumber(lnum) - 1,
          col = 0,
          message = msg,
          severity = vim.diagnostic.severity.ERROR,
          source = 'jsonlint'
        })
      end
      return diagnostics
    end
  }
  lint.linters.julia = {
    cmd = 'julia',
    stdin = true,
    args = { '--check-bounds=yes', '-e', 'include(ARGS[1])' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters.ktlint = {
    cmd = 'ktlint',
    stdin = false,
    args = { '--reporter=plain', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'ktlint'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.lacheck = {
    cmd = 'lacheck',
    stdin = true,
    args = { '-v' },
    stream = 'stderr',
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg = line:match('(.+):(%d+): (.+)')
        if fname and lnum then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'lacheck'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.lintr = {
    cmd = 'Rscript',
    stdin = false,
    args = {
      '--vanilla', '--slave', '-e',
      'capture.output(lintr::lint(commandArgs(trailingOnly=TRUE)[1]), type="message")',
      '$FILENAME'
    },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+):%s*([^:]+):%s*(.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'lintr'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.luacheck = lint.linters.luacheck or {}
  lint.linters.luacheck.args = {
    '--formatter', 'plain', '--codes', '--ranges', '-'
  }
  lint.linters['markdownlint-fix'] = {
    cmd = 'markdownlint',
    stdin = true,
    args = { '--fix', '--stdin' },
    stream = 'stdout',
    ignore_exitcode = true
  }
  lint.linters.meson = {
    cmd = 'meson',
    stdin = false,
    args = { 'compile', '--dry-run' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters['mlir-opt'] = {
    cmd = 'mlir-opt',
    stdin = true,
    args = { '--verify-diagnostics', '-' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters['mojo-check'] = {
    cmd = 'mojo',
    stdin = false,
    args = { 'check' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.mypy = lint.linters.mypy or {}
  lint.linters.mypy.args = {
    '--ignore-missing-imports', '--no-color-output', '--no-error-summary',
    '--show-column-numbers', '--show-error-codes'
  }
  lint.linters['mql-check'] = {
    cmd = 'mql-check',
    stdin = false,
    args = { '--json' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, issue in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (issue.line or 1) - 1,
          col = (issue.column or 1) - 1,
          message = issue.message,
          severity = issue.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'mql-check'
        })
      end
      return diagnostics
    end
  }
  lint.linters.nasm = {
    cmd = 'nasm',
    stdin = false,
    args = {
      '-X', 'gnu', '-I', vim.fn.expand('%:p:h') .. '/', '$FILENAME', '-o',
      '/dev/null'
    },
    stream = 'stderr',
    ignore_exitcode = false,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg = line:match(
          '([^:]+):(%d+):%s*([^:]+):%s*(.+)')
        if fname and lnum then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = line:match('error') and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'nasm'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.nvc = {
    cmd = 'nvc',
    stdin = false,
    args = {
      '-c', '-Wall', '-Wextra', '-Minform=inform', '-Minfo=all',
      '-Mneginfo=all', '$FILENAME'
    },
    stream = 'stderr',
    parser = function(output)
      local diagnostics = {}
      local pattern = '([^:]+):(%d+):%s*([%a]+):%s*(.+)'
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, type, msg = line:match(pattern)
        if fname and lnum then
          local severity = vim.diagnostic.severity.INFO
          if type == 'error' then
            severity = vim.diagnostic.severity.ERROR
          elseif type == 'warning' then
            severity = vim.diagnostic.severity.WARN
          end
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = severity,
            source = 'nvc'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.nvcc = {
    cmd = 'nvcc',
    stdin = false,
    args = {
      '--Werror', 'all-warnings', '--expt-relaxed-constexpr',
      '-Xcompiler', '-Wall,-Wextra', '--dryrun', '$FILENAME'
    },
    stream = 'stderr',
    ignore_exitcode = false,
    parser = function(output)
      local diagnostics = {}
      local pattern = '([^:]+):(%d+):%s*([%a]+):%s*(.+)'

      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, type, msg = line:match(pattern)
        if fname and lnum then
          local severity = vim.diagnostic.severity.INFO
          if type == 'error' then
            severity = vim.diagnostic.severity.ERROR
          elseif type:match('warning') then
            severity = vim.diagnostic.severity.WARN
          end

          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = severity,
            source = 'nvcc'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['parquet-tools'] = {
    cmd = 'parquet-tools',
    stdin = false,
    args = { 'schema' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'message' }
  }
  lint.linters.perlcritic = {
    cmd = 'perlcritic',
    stdin = false,
    args = { '--verbose', '%f:%l:%m', '$FILENAME' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(.+)]],
    groups = { 'file', 'lnum', 'message' }
  }
  lint.linters.phpcs = {
    cmd = 'phpcs',
    stdin = false,
    args = { '--report=emacs', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, severity, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+) - (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = severity == 'error' and
                vim.diagnostic.severity.ERROR or severity ==
                'warning' and vim.diagnostic.severity.WARN or
                vim.diagnostic.severity.INFO,
            source = 'phpcs'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['php-cs-fixer-lint'] = {
    cmd = 'php-cs-fixer',
    stdin = false,
    args = { 'fix', '--dry-run', '--diff', '--using-cache=no', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        if line:match('^   1) ') then
          table.insert(diagnostics, {
            lnum = 0,
            col = 0,
            message = 'Code style issues detected (run formatter)',
            severity = vim.diagnostic.severity.WARN,
            source = 'php-cs-fixer'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.phpstan = {
    cmd = 'phpstan',
    stdin = false,
    args = { 'analyse', '--error-format=json', '--no-progress' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.files then
        return diagnostics
      end
      for _, file_data in pairs(decoded.files) do
        for _, message in ipairs(file_data.messages) do
          table.insert(diagnostics, {
            lnum = (message.line or 1) - 1,
            col = 0,
            message = message.message,
            severity = vim.diagnostic.severity.ERROR,
            source = 'phpstan'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.phpstan = {
    cmd = 'phpstan',
    stdin = false,
    args = { 'analyse', '--error-format=json', '--no-progress' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.files then
        return diagnostics
      end
      for _, file_data in pairs(decoded.files) do
        for _, message in ipairs(file_data.messages) do
          table.insert(diagnostics, {
            lnum = (message.line or 1) - 1,
            col = 0,
            message = message.message,
            severity = vim.diagnostic.severity.ERROR,
            source = 'phpstan'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.pmd = {
    cmd = 'pmd',
    stdin = false,
    args = {
      'check', '-d', '$FILENAME', '-R', 'category/java/bestpractices.xml',
      '-f', 'text'
    },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg = line:match('([^:]+):(%d+):%s+(.+)')
        if fname and lnum then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'pmd'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.protoc = {
    cmd = 'protoc',
    stdin = false,
    args = { '--proto_path=.', '$FILENAME' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = vim.diagnostic.severity.ERROR,
            source = 'protoc'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.PSScriptAnalyzer = {
    cmd = 'pwsh',
    stdin = false,
    args = {
      '-Command',
      'Invoke-ScriptAnalyzer -Path $FILENAME -ReportFormat Json'
    },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if ok and decoded then
        for _, issue in ipairs(decoded) do
          table.insert(diagnostics, {
            lnum = (issue.ScriptLine or 1) - 1,
            col = 0,
            message = issue.Message,
            severity = issue.Severity == 'Error' and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'PSScriptAnalyzer'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['pyquil-check'] = {
    cmd = 'python',
    stdin = true,
    args = {
      '-c', "from pyquil import Program; exec(open('/dev/stdin').read())"
    },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'message' }
  }
  lint.linters.qiskit_check = {
    cmd = 'python',
    stdin = true,
    args = { '-m', 'qiskit.tools.check' },
    stream = 'stdout',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters['qiskit-terra'] = {
    cmd = 'python',
    stdin = true,
    args = { '-c', 'import qiskit; qiskit.transpile', '-' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'message' }
  }
  lint.linters['qsharp-analyzer'] = {
    cmd = 'qsharp-analyzer',
    stdin = false,
    args = { '--json' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, diagnostic in ipairs(decoded.diagnostics or {}) do
        table.insert(diagnostics, {
          lnum = (diagnostic.range.start.line or 1) - 1,
          col = (diagnostic.range.start.character or 1) - 1,
          message = diagnostic.message,
          severity = diagnostic.severity == 1 and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'qsharp-analyzer',
          code = diagnostic.code
        })
      end
      return diagnostics
    end
  }
  lint.linters.reek = {
    cmd = 'reek',
    stdin = false,
    args = { '--format', 'json', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if ok and decoded then
        for _, issue in ipairs(decoded) do
          table.insert(diagnostics, {
            lnum = (issue.lines[1] or 1) - 1,
            col = 0,
            message = issue.message,
            severity = vim.diagnostic.severity.WARN,
            source = 'reek'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['renderdoc-check'] = {
    cmd = 'renderdoc-check',
    stdin = false,
    args = { '--validate' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters.ruff = lint.linters.ruff or {}
  lint.linters.ruff.args = {
    'check', '--output-format=json', '--stdin-filename',
    function() return vim.api.nvim_buf_get_name(0) end, '--quiet', '-'
  }
  lint.linters.scalastyle = {
    cmd = 'scalastyle',
    stdin = false,
    args = { '-c', 'scalastyle-config.xml' },
    stream = 'stdout',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters.selene = {
    cmd = 'selene',
    stdin = true,
    args = { '--display-style=json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, diagnostic in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (diagnostic.primary_label.span.start or 1) - 1,
          col = 0,
          message = diagnostic.message,
          severity = diagnostic.severity == 'Error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'selene'
        })
      end
      return diagnostics
    end
  }
  lint.linters.shellcheck = lint.linters.shellcheck or {}
  lint.linters.shellcheck = {
    cmd = 'shellcheck',
    stdin = true,
    args = { '--shell=bash', '-' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, msg = line:match(
          'In ([^ ]+) line (%d+): (SC%d+: .+)')
        if fname and lnum then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = 0,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
            source = 'shellcheck'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.sqlfluff = {
    cmd = 'sqlfluff',
    stdin = false,
    args = { 'lint', '--format', 'json', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if ok and decoded and decoded[1] then
        for _, violation in ipairs(decoded[1].violations) do
          table.insert(diagnostics, {
            lnum = (violation.line_no or 1) - 1,
            col = (violation.line_pos or 1) - 1,
            message = violation.description,
            severity = violation.code == 'L000' and
                vim.diagnostic.severity.INFO or
                violation.code:match('^L0') and
                vim.diagnostic.severity.WARN or
                vim.diagnostic.severity.ERROR,
            source = 'sqlfluff'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters['stylelint-fix'] = {
    cmd = 'stylelint',
    stdin = true,
    args = { '--fix', '--stdin' },
    stream = 'stdout',
    ignore_exitcode = true
  }
  lint.linters.statix = {
    cmd = 'statix',
    stdin = false,
    args = { 'check', '--format=json', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if ok and decoded then
        for _, diagnostic in ipairs(decoded) do
          if diagnostic.locations and #diagnostic.locations > 0 then
            table.insert(diagnostics, {
              lnum = (diagnostic.locations[1].line or 1) - 1,
              col = (diagnostic.locations[1].column or 1) - 1,
              message = diagnostic.message,
              severity = diagnostic.severity == 'error' and
                  vim.diagnostic.severity.ERROR or
                  vim.diagnostic.severity.WARN,
              source = 'statix'
            })
          end
        end
      end
      return diagnostics
    end
  }
  lint.linters.swiftlint = {
    cmd = 'swiftlint',
    stdin = true,
    args = { 'lint', '--use-stdin', '--reporter', 'json' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, violation in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (violation.line or 1) - 1,
          col = (violation.character or 1) - 1,
          message = violation.reason,
          severity = violation.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'swiftlint',
          code = violation.rule_id
        })
      end
      return diagnostics
    end
  }
  lint.linters.textlint = {
    cmd = 'textlint',
    stdin = false,
    args = { '--format', 'unix', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+):%s*([^:]+):%s*(.+)')
        if fname and lnum and col and msg then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('error:') and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'textlint'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.tflint = {
    cmd = 'tflint',
    stdin = false,
    args = { '--format', 'json' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.issues then
        return diagnostics
      end
      for _, issue in ipairs(decoded.issues) do
        table.insert(diagnostics, {
          lnum = (issue.range.start.line or 1) - 1,
          col = (issue.range.start.column or 1) - 1,
          message = issue.message,
          severity = issue.rule.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'tflint',
          code = issue.rule.name
        })
      end
      return diagnostics
    end
  }
  lint.linters.tfsec = {
    cmd = 'tfsec',
    stdin = false,
    args = { '--format', 'json', '.' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded or not decoded.results then
        return diagnostics
      end
      for _, result in ipairs(decoded.results) do
        table.insert(diagnostics, {
          lnum = (result.location.start_line or 1) - 1,
          col = 0,
          message = result.description,
          severity = result.severity == 'HIGH' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'tfsec',
          code = result.rule_id
        })
      end
      return diagnostics
    end
  }
  lint.linters.taplo = {
    cmd = 'taplo',
    stdin = true,
    args = {
      'check', '--stdin-filepath',
      function() return vim.api.nvim_buf_get_name(0) end
    },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.tidy = {
    cmd = 'tidy',
    stdin = true,
    args = { '-errors', '-quiet', '-utf8' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[line (%d+) column (%d+) %- (%w+): (.+)]],
    groups = { 'lnum', 'col', 'severity', 'message' },
    severity_map = {
      Error = vim.diagnostic.severity.ERROR,
      Warning = vim.diagnostic.severity.WARN
    }
  }
  lint.linters['unity-analyzer'] = {
    cmd = 'unity-analyzer',
    stdin = false,
    args = { '--json' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, issue in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (issue.line or 1) - 1,
          col = (issue.column or 1) - 1,
          message = issue.message,
          severity = issue.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'unity-analyzer'
        })
      end
      return diagnostics
    end
  }
  lint.linters.vale = {
    cmd = 'vale',
    stdin = false,
    args = { '--output=JSON', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if ok and decoded then
        for _, alerts in pairs(decoded) do
          for _, alert in ipairs(alerts) do
            table.insert(diagnostics, {
              lnum = (alert.Line or 1) - 1,
              col = (alert.Span[1] or 1) - 1,
              message = alert.Message,
              severity = alert.Severity == 'error' and
                  vim.diagnostic.severity.ERROR or
                  vim.diagnostic.severity.WARN,
              source = 'vale'
            })
          end
        end
      end
      return diagnostics
    end
  }
  lint.linters.verilator = {
    cmd = 'verilator',
    stdin = false,
    args = { '--lint-only', '--Wall' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[%s*([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters.vint = {
    cmd = 'vint',
    stdin = true,
    args = { '--json', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)
      if not ok or not decoded then return diagnostics end
      for _, violation in ipairs(decoded) do
        table.insert(diagnostics, {
          lnum = (violation.line_number or 1) - 1,
          col = (violation.column_number or 1) - 1,
          message = violation.description,
          severity = violation.severity == 'error' and
              vim.diagnostic.severity.ERROR or
              vim.diagnostic.severity.WARN,
          source = 'vint',
          code = violation.policy_name
        })
      end
      return diagnostics
    end
  }
  lint.linters.vulture = {
    cmd = 'vulture',
    stdin = true,
    args = { '--min-confidence', '80', '-' },
    stream = 'stdout',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (.+)]],
    groups = { 'file', 'lnum', 'message' }
  }
  lint.linters['wasm-validate'] = {
    cmd = 'wasm-validate',
    stdin = true,
    args = { '/dev/stdin' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.wat2wasm = {
    cmd = 'wat2wasm',
    stdin = true,
    args = { '--no-check', '-' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters.xmllint = {
    cmd = 'xmllint',
    stdin = false,
    args = { '--noout', '$FILENAME' },
    stream = 'stderr',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+): ([^:]+): (.+)')
        if fname and lnum and col then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = vim.diagnostic.severity.ERROR,
            source = 'xmllint'
          })
        else
          fname, lnum, msg =
              line:match('([^:]+):(%d+): ([^:]+): (.+)')
          if fname and lnum then
            table.insert(diagnostics, {
              lnum = tonumber(lnum) - 1,
              col = 0,
              message = msg,
              severity = vim.diagnostic.severity.ERROR,
              source = 'xmllint'
            })
          end
        end
      end
      return diagnostics
    end
  }
  lint.linters.yamllint = {
    cmd = 'yamllint',
    stdin = false,
    args = { '--format', 'parsable', '$FILENAME' },
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output)
      local diagnostics = {}
      for _, line in ipairs(vim.split(output, '\n')) do
        local fname, lnum, col, msg = line:match(
          '([^:]+):(%d+):(%d+)%s*%[(%w+)%]%s*(.+)')
        if fname and lnum and col and msg then
          table.insert(diagnostics, {
            lnum = tonumber(lnum) - 1,
            col = tonumber(col) - 1,
            message = msg,
            severity = line:match('error') and
                vim.diagnostic.severity.ERROR or
                vim.diagnostic.severity.WARN,
            source = 'yamllint'
          })
        end
      end
      return diagnostics
    end
  }
  lint.linters.yasm = {
    cmd = 'yasm',
    stdin = false,
    args = { '-f', 'elf64', '-o', '/dev/null' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'severity', 'message' }
  }
  lint.linters.zig_check = {
    cmd = 'zig',
    stdin = false,
    args = { 'check', '--' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
  lint.linters['zlint'] = {
    cmd = 'zlint',
    stdin = true,
    args = { 'fmt', '--stdin' },
    stream = 'stdout',
    ignore_exitcode = true
  }
  lint.linters.zigfmt_check = {
    cmd = 'zig',
    stdin = false,
    args = { 'fmt', '--check', '--' },
    stream = 'stderr',
    ignore_exitcode = true,
    pattern = [[([^:]+):(%d+):(%d+): (%w+): (.+)]],
    groups = { 'file', 'lnum', 'col', 'severity', 'message' }
  }
end

return M
