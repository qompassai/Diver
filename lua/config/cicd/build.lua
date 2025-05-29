-- build.lua
local M = {}

M.setup = function(opts)
    opts = opts or {}
    local null_ls = require("null-ls")
    local sources = {}

    if opts.cmake ~= false then
        table.insert(sources, null_ls.builtins.formatting.cmake_format.with({
            ft = { "cmake" },
            cmd = { "cmake-format" },
            extra_args = { "-" },
        }))

        table.insert(sources, null_ls.builtins.diagnostics.cmake_lint.with({
            ft = { "cmake" },
            cmd = { "cmake-lint" },
            extra_args = { "$FILENAME" },
        }))

        table.insert(sources, null_ls.builtins.formatting.gersemi.with({
            ft = { "cmake" },
            cmd = { "gersemi" },
            extra_args = { "-" },
        }))
    end

    if opts.make ~= false then
        table.insert(sources, null_ls.builtins.diagnostics.checkmake.with({
            ft = { "make" },
            cmd = { "checkmake" },
            extra_args = { "--format='{{.LineNumber}}:{{.Rule}}:{{.Violation}}\n'", "$FILENAME" },
        }))
    end

    if opts.bazel ~= false then
        table.insert(sources, null_ls.builtins.diagnostics.buildifier.with({
            ft = { "bzl" },
            cmd = { "buildifier" },
            extra_args = { "-mode=check", "-lint=warn", "-format=json", "-path=$FILENAME" },
        }))

        table.insert(sources, null_ls.builtins.formatting.buildifier.with({
            ft = { "bzl" },
            cmd = { "buildifier" },
            extra_args = { "-path=$FILENAME" },
        }))
    end

    if opts.ninja ~= false and vim.fn.executable("ninja") == 1 then
        table.insert(sources, {
            name = "ninja_validator",
            method = null_ls.methods.DIAGNOSTICS,
            filetypes = { "ninja" },
            generator = require("null-ls.helpers").make_diagnostic_generator({
                command = "ninja",
                args = { "-n", "-C", vim.fn.expand("%:p:h") },
                format = "line",
                check_exit_code = function(code)
                    return code <= 1
                end,
                on_output = function(line, params)
                    if line:match("error:") then
                        return {
                            row = 1,
                            col = 1,
                            message = line,
                            severity = 1, -- Error
                        }
                    end
                    return nil
                end,
            }),
        })
    end

    if opts.meson ~= false then
        if vim.fn.executable("meson") == 1 then
            table.insert(sources, {
                name = "meson_fmt",
                method = null_ls.methods.FORMATTING,
                filetypes = { "meson" },
                generator = require("null-ls.helpers").formatter_factory({
                    command = "meson",
                    args = { "format", "$FILENAME" },
                    to_temp_file = true,
                    from_temp_file = true,
                }),
            })

            table.insert(sources, {
                name = "meson_check",
                method = null_ls.methods.DIAGNOSTICS,
                filetypes = { "meson" },
                generator = require("null-ls.helpers").make_diagnostic_generator({
                    command = "meson",
                    args = { "introspect", "--ast", "$FILENAME" },
                    format = "json",
                    check_exit_code = function(code)
                        return code <= 1
                    end,
                    on_output = function(output, params)
                        if type(output) ~= "table" then
                            return {
                                {
                                    row = 1,
                                    col = 1,
                                    message = "Invalid meson file syntax",
                                    severity = 1,
                                }
                            }
                        end
                        return {}
                    end,
                }),
            })
        end
    end

    if opts.pkgbuild ~= false and vim.fn.executable("shellcheck") == 1 then
        table.insert(sources, null_ls.builtins.diagnostics.shellcheck.with({
            filetypes = { "PKGBUILD" },
            extra_args = { "--shell=bash" },
        }))

        if vim.fn.executable("namcap") == 1 then
            table.insert(sources, {
                name = "namcap",
                method = null_ls.methods.DIAGNOSTICS,
                filetypes = { "PKGBUILD" },
                generator = require("null-ls.helpers").make_diagnostic_generator({
                    command = "namcap",
                    args = { "$FILENAME" },
                    format = "line",
                    check_exit_code = function(code)
                        return code <= 1
                    end,
                    on_output = function(line, params)
                        local message = line:match("([^:]+): (.+)")
                        if message then
                            return {
                                row = 1,
                                col = 1,
                                message = message,
                                severity = 2,
                            }
                        end
                        return nil
                    end,
                }),
            })
        end
    end
    null_ls.setup({ sources = sources })
    vim.filetype.add({
        extension = {
            cmake = "cmake",
            meson = "meson",
            ninja = "ninja",
        },
        filename = {
            ["CMakeLists.txt"] = "cmake",
            ["meson.build"] = "meson",
            ["meson_options.txt"] = "meson",
            ["PKGBUILD"] = "PKGBUILD",
            ["Makefile"] = "make",
            ["GNUmakefile"] = "make",
            ["makefile"] = "make",
            ["build.ninja"] = "ninja",
        },
        pattern = {
            [".*%.ninja"] = "ninja",
        },
    })
end


return M

