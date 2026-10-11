-- #################################################################
-- /qompassai/diver/lsp/ron_ls.lua
-- Qompass AI Diver Ron Ls
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
---@source https://github.com/jasonjmcghee/ron-lsp
--
-- Requires the `ron-lsp` binary on PATH (`cargo install ron-lsp`).
-- Validated 2026-10-04 against ron-lsp 0.1.4 (all features).

return ---@type vim.lsp.Config
{
    cmd = { 'ron-lsp' },
    filetypes = { 'ron' },
    root_markers = { 'Cargo.toml', '.git' },
}
