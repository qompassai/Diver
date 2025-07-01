-- qompassai/Diver/lua/config/cicd/build.lua
-- Qompass AI Diver CICD Build Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
M.setup = function(opts)
    opts = opts or {}
    local null_ls = require('null-ls')
    local sources = {}
    table.insert(sources, null_ls.builtins.diagnostics.clang_tidy.with({
        extra_args = {
            '--checks=clang-diagnostic-*,clang-analyzer-*',
            '--extra-arg=-I/usr/include/c++/13.2.1', '--extra-arg=-std=c++20'
        }
    }))
    table.insert(sources, null_ls.builtins.diagnostics.cppcheck.with({
        extra_args = {
            '--enable=warning,style,performance,information,missingInclude',
            '--inline-suppr', '--std=c++20', '--suppress=missingIncludeSystem'
        }
    }))
    if opts.bazel ~= false then
        table.insert(sources, null_ls.builtins.diagnostics.buildifier.with({
            cmd = {'buildifier'},
            extra_args = {
                '-mode=check', '-lint=warn', '-format=json', '-path=$FILENAME'
            },
            ft = {'bzl'}
        }))
        table.insert(sources, null_ls.builtins.formatting.buildifier.with({
            cmd = {'buildifier'},
            extra_args = {'-path=$FILENAME'},
            ft = {'bzl'}
        }))
    end
    if opts.cmake ~= false then
        table.insert(sources, null_ls.builtins.diagnostics.cmake_lint.with({
            cmd = {'cmake-lint'},
            extra_args = {'$FILENAME'},
            ft = {'cmake'}
        }))
        table.insert(sources, null_ls.builtins.formatting.cmake_format.with({
            cmd = {'cmake-format'},
            extra_args = {'-'},
            ft = {'cmake'}
        }))
        table.insert(sources, null_ls.builtins.formatting.gersemi.with({
            cmd = {'gersemi'},
            extra_args = {'-'},
            ft = {'cmake'}
        }))
    end
    if opts.make ~= false then
        table.insert(sources, null_ls.builtins.diagnostics.checkmake.with({
            cmd = {'checkmake'},
            extra_args = {
                "--format='{{.LineNumber}}:{{.Rule}}:{{.Violation}}\n'",
                '$FILENAME'
            },
            ft = {'make'}
        }))
    end
    if opts.meson ~= false and vim.fn.executable('meson') == 1 then
        table.insert(sources, {
            name = 'meson_check',
            method = null_ls.methods.DIAGNOSTICS,
            filetypes = {'meson'},
            generator = require('null-ls.helpers').make_diagnostic_generator({
                args = {'introspect', '--ast', '$FILENAME'},
                check_exit_code = function(code) return code <= 1 end,
                command = 'meson',
                format = 'json',
                on_output = function(output)
                    return type(output) ~= 'table' and
                               {
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
            method = null_ls.methods.DIAGNOSTICS,
            filetypes = {'ninja'},
            generator = require('null-ls.helpers').make_diagnostic_generator({
                args = {'300', 'ninja', '-n', '-C', vim.fn.expand('%:p:h')},
                check_exit_code = function(code)
                    return code == 0 or code == 124
                end,
                command = 'timeout',
                format = 'line',
                on_output = function(line)
                    local severity = line:match('error:') and
                                         vim.diagnostic.severity.ERROR or
                                         line:match('warn:') and
                                         vim.diagnostic.severity.WARN
                    return severity and
                               {
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
            method = null_ls.methods.DIAGNOSTICS,
            filetypes = {'PKGBUILD'},
            generator = require('null-ls.helpers').make_diagnostic_generator({
                args = {'$FILENAME'},
                check_exit_code = function(code) return code <= 1 end,
                command = 'namcap',
                format = 'line',
                on_output = function(line)
                    local message = line:match('([^:]+): (.+)')
                    return message and
                               {
                            col = 1,
                            message = message,
                            row = 1,
                            severity = 2
                        } or nil
                end
            })
        })
    end
    null_ls.setup({sources = sources})
    vim.filetype.add({
        extension = {cmake = 'cmake', meson = 'meson', ninja = 'ninja'},
        filename = {
            ['CMakeLists.txt'] = 'cmake',
            ['GNUmakefile'] = 'make',
            ['Makefile'] = 'make',
            ['PKGBUILD'] = 'PKGBUILD',
            ['build.ninja'] = 'ninja',
            ['meson.build'] = 'meson',
            ['meson_options.txt'] = 'meson'
        },
        pattern = {['.*%.ninja'] = 'ninja'}
    })
end
return M
