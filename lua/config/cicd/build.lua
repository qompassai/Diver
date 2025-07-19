-- qompassai/Diver/lua/config/cicd/build.lua
-- Qompass AI Diver CICD Build Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.nls(opts)
  opts = opts or {}
  local nlsb = require('null-ls').builtins
  local sources = {
    nlsb.diagnostics.clang_tidy.with({
      extra_args = {
        '--checks=clang-diagnostic-*,clang-analyzer-*',
        '--extra-arg=-I/usr/include/c++/13.2.1',
        '--extra-arg=-std=c++20'
      },
      filetypes = { 'c', 'cpp', 'objc', 'objcpp' }
    }),
    nlsb.diagnostics.cppcheck.with({
      extra_args = {
        '--enable=warning,style,performance,information,missingInclude',
        '--inline-suppr', '--std=c++20', '--suppress=missingIncludeSystem'
      },
      filetypes = { 'c', 'cpp', 'objc', 'objcpp' }
    }),

    nlsb.diagnostics.buildifier.with({
      cmd = { 'buildifier' },
      extra_args = { '-mode=check', '-lint=warn', '-format=json', '-path=$FILENAME' },
      filetypes = { 'bzl' }
    }),
    nlsb.formatting.buildifier.with({
      cmd = { 'buildifier' },
      extra_args = { '-path=$FILENAME' },
      filetypes = { 'bzl' }
    }),
    nlsb.diagnostics.cmake_lint.with({
      cmd = { 'cmake-lint' },
      extra_args = { '$FILENAME' },
      filetypes = { 'cmake' }
    }),
    nlsb.formatting.cmake_format.with({
      cmd = { 'cmake-format' },
      extra_args = { '-' },
      filetypes = { 'cmake' }
    }),
    nlsb.formatting.gersemi.with({
      cmd = { 'gersemi' },
      extra_args = { '-' },
      filetypes = { 'cmake' }
    }),

    nlsb.diagnostics.checkmake.with({
      cmd = { 'checkmake' },
      extra_args = {
        "--format='{{.LineNumber}}:{{.Rule}}:{{.Violation}}\\n'",
        '$FILENAME'
      },
      filetypes = { 'make' }
    }),
  }

  if opts.meson ~= false and vim.fn.executable('meson') == 1 then
    table.insert(sources, {
      name = 'meson_check',
      method = require('null-ls').methods.DIAGNOSTICS,
      filetypes = { 'meson' },
      generator = require('null-ls.helpers').make_diagnostic_generator({
        args = { 'introspect', '--ast', '$FILENAME' },
        check_exit_code = function(code) return code <= 1 end,
        command = 'meson',
        format = 'json',
        on_output = function(output)
          return type(output) ~= 'table' and {
            {
              col = 1,
              message = 'Invalid meson file syntax',
              row = 1,
              severity = 1
            }
          } or {}
        end
      })
    })
  end

  if opts.ninja ~= false and vim.fn.executable('ninja') == 1 then
    table.insert(sources, {
      name = 'ninja_validator',
      method = require('null-ls').methods.DIAGNOSTICS,
      filetypes = { 'ninja' },
      generator = require('null-ls.helpers').make_diagnostic_generator({
        args = { '300', 'ninja', '-n', '-C', vim.fn.expand('%:p:h') },
        check_exit_code = function(code)
          return code == 0 or code == 124
        end,
        command = 'timeout',
        format = 'line',
        on_output = function(line)
          local severity = line:match('error:') and vim.diagnostic.severity.ERROR
            or line:match('warn:') and vim.diagnostic.severity.WARN
          return severity and {
            col = 1,
            message = line,
            row = 1,
            severity = severity
          } or nil
        end
      })
    })
  end

  if opts.pkgbuild ~= false and vim.fn.executable('namcap') == 1 then
    table.insert(sources, {
      name = 'namcap',
      method = require('null-ls').methods.DIAGNOSTICS,
      filetypes = { 'PKGBUILD' },
      generator = require('null-ls.helpers').make_diagnostic_generator({
        args = { '$FILENAME' },
        check_exit_code = function(code) return code <= 1 end,
        command = 'namcap',
        format = 'line',
        on_output = function(line)
          local message = line:match('([^:]+): (.+)')
          return message and {
            col = 1,
            message = message,
            row = 1,
            severity = 2
          } or nil
        end
      })
    })
  end

  return sources
end
return M
