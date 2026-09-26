-- #################################################################
-- ~/.config/nvim/lua/formatters/buildifier.lua
-- Native Buildifier Formatter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/bazelbuild/buildtools/blob/main/buildifier/README.md
---
--- Buildifier is the code tidier for Bazel's build files (BUILD, .bzl): it
--- keeps the build recipes neatly and consistently formatted.
---
--- With no file arguments it reads from stdin and prints the tidied result
--- to stdout, as the README documents. No `--type` flag is needed: without
--- one, piped input is treated as a default build file.

---@type FormatterSpec
return {
    cmd = 'buildifier',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    env = {
        NO_COLOR = '1',
    },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'bzl',
}
