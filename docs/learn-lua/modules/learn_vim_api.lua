-- /qompassai/Diver/docs/learn-lua/modules/learn_vim_api.lua
-- Qompass AI Diver :: Learn Lua — the Neovim API surface
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------------------------------------------

--- The Neovim API, taught from the Diver config.
--
-- Once you can read Lua, the next wall is the `vim.*` API. This module maps the
-- exact pieces `diver` leans on, with the Neovim 0.13 native model front and
-- centre: `vim.opt` / `vim.o`, `vim.keymap.set`, `vim.api.nvim_create_autocmd`,
-- `vim.lsp`, `vim.pack`, and `vim.treesitter`. No plugins are required for any
-- of this — it is all built in.
--
-- These functions are illustrative wrappers: they show the *shape* of each API
-- call as used in `diver`, with annotations, so the docs read like a che-sheet
-- you can click through.
--
-- @module learn_vim_api
-- @author Qompass AI
-- @license Apache-2.0

local M = {}

-- ---------------------------------------------------------------------------
-- 1. Options: vim.o / vim.bo / vim.wo / vim.opt
-- ---------------------------------------------------------------------------

--- Set an editor option four different ways (and explain when to use each).
--
-- `init.lua` aliases all of these at the top: `local o = vim.o`,
-- `local bo = vim.bo`, `local wo = vim.wo`, `local opt = vim.opt`.
--
-- * `vim.o.x = v`   — global/simple scalar option (e.g. `o.termguicolors`).
-- * `vim.bo.x = v`  — buffer-local option (e.g. `bo.shiftwidth = 4`).
-- * `vim.wo.x = v`  — window-local option (e.g. `wo.number = true`).
-- * `vim.opt.x`     — a rich wrapper supporting `:append`, `:remove`, `:prepend`
--   for list/flag options (e.g. `opt.runtimepath:prepend(...)`).
--
---@return string
function M.options_cheatsheet()
    return 'o=global, bo=buffer, wo=window, opt=list-aware (append/remove/prepend)'
end

-- ---------------------------------------------------------------------------
-- 2. Keymaps: vim.keymap.set
-- ---------------------------------------------------------------------------

--- Define a keymap the modern way.
--
-- `vim.keymap.set(mode, lhs, rhs, opts)` is the one true keymap function in
-- modern Neovim — no more `nvim_set_keymap` boilerplate. `rhs` may be a string
-- (`:RoseChatNew<CR>`) **or a Lua function** (like `toggle_netrw`). `diver`
-- aliases it as `local map = vim.keymap.set` in every `lua/mappings/*` file.
--
-- @usage
--   learn_vim_api.map("n", "<leader>e", function() vim.cmd("Lexplore") end,
--                     { desc = "Toggle Explorer" })
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
function M.map(mode, lhs, rhs, opts)
    vim.keymap.set(mode, lhs, rhs, opts or {})
end

-- ---------------------------------------------------------------------------
-- 3. Autocommands: vim.api.nvim_create_autocmd
-- ---------------------------------------------------------------------------

--- Register an autocommand with a Lua callback.
--
-- Autocommands run your code on editor events. `diver` uses them heavily —
-- `LspAttach` to wire buffer-local keymaps (`lua/mappings/aimap.lua`),
-- `BufWritePost` to render Markdown to PDF (`lua/utils/docs/docs.lua`). The
-- callback receives one `args` table; `args.buf` is the buffer, `args.file`
-- the filename.
--
-- @usage
--   learn_vim_api.on("BufWritePost", function(a) print("saved", a.file) end,
--                    { pattern = "*.md" })
---@param event string|string[]
---@param callback fun(args: table)
---@param extra? table
---@return integer autocmd_id
function M.on(event, callback, extra)
    local spec = extra or {}
    spec.callback = callback
    return vim.api.nvim_create_autocmd(event, spec)
end

-- ---------------------------------------------------------------------------
-- 4. Buffer lines: nvim_buf_get_lines / nvim_buf_set_lines (0-based!)
-- ---------------------------------------------------------------------------

--- Read lines from a buffer (remembering the 0-based, end-exclusive rule).
--
-- `nvim_buf_get_lines(buf, start, end_, strict)` uses **0-based** indices and an
-- **exclusive** end. To read the single current line `v.lnum` (which is
-- 1-based) you pass `v.lnum - 1, v.lnum` — exactly what `M.foldtext` does in
-- `lua/utils/docs/docs.lua`.
--
-- @usage local lines = learn_vim_api.get_lines(0, 0, -1) -- whole buffer
---@param bufnr integer
---@param first_zero_based integer
---@param last_exclusive integer
---@return string[]
function M.get_lines(bufnr, first_zero_based, last_exclusive)
    return vim.api.nvim_buf_get_lines(bufnr, first_zero_based, last_exclusive, false)
end

-- ---------------------------------------------------------------------------
-- 5. User commands: nvim_create_user_command
-- ---------------------------------------------------------------------------

--- Create a `:MyCommand` that runs Lua.
--
-- `diver` defines `:Align`, `:Json2Lua`, `:JsonC2Lua` this way in
-- `lua/utils/docs/docs.lua`. The callback gets an `opts` table with the range
-- (`opts.line1`, `opts.line2`) and any args.
--
-- @usage
--   learn_vim_api.command("HelloDiver", function() print("hi") end)
---@param name string
---@param callback fun(opts: table)
---@param attrs? table
function M.command(name, callback, attrs)
    vim.api.nvim_create_user_command(name, callback, attrs or {})
end

-- ---------------------------------------------------------------------------
-- 6. Native LSP (Neovim 0.13): the on_attach capability check
-- ---------------------------------------------------------------------------

--- Enable native LSP completion when the server supports it.
--
-- This is the heart of `M.on_attach` in `lua/config/core/lsp.lua`, and the
-- reason `diver` needs **no completion plugin**. Inside an `LspAttach`
-- callback you receive the `client`; if it advertises a completion provider
-- you switch on the *built-in* `vim.lsp.completion.enable`. Neovim 0.13 also
-- adds `vim.lsp.inline_completion.enable` for ghost-text suggestions.
--
-- @usage
--   vim.api.nvim_create_autocmd("LspAttach", {
--     callback = function(ev)
--       local c = vim.lsp.get_client_by_id(ev.data.client_id)
--       learn_vim_api.enable_completion(c, ev.buf)
--     end,
--   })
---@param client vim.lsp.Client
---@param bufnr integer
---@return boolean enabled
function M.enable_completion(client, bufnr)
    -- The guard is pure Lua truthiness on a (possibly nil) nested field.
    if client and client.server_capabilities and client.server_capabilities.completionProvider then
        vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- 7. Native plugin manager (Neovim 0.13): vim.pack
-- ---------------------------------------------------------------------------

--- Add plugins with the built-in `vim.pack` (no plugin manager required).
--
-- Neovim 0.13 ships `vim.pack.add{ {src=...}, ... }`, which `diver` uses in
-- `lua/plugins/init.lua` and `lua/plugins/core/init.lua`. Each spec is a table
-- with a git `src`, optional `version` (e.g. `vim.version.range('1.*')`), and
-- `branch`. This function shows the spec shape.
--
-- @usage
--   local specs = learn_vim_api.pack_specs({ "folke/which-key.nvim" })
---@param repos string[]
---@return vim.pack.Spec[]
function M.pack_specs(repos)
    local specs = {}
    for _, repo in ipairs(repos) do
        table.insert(specs, { src = 'https://github.com/' .. repo, update = true })
    end
    return specs
end

return M
