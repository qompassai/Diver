-- /qompassai/Diver/docs/learn-lua/modules/learn_lua.lua
-- Qompass AI Diver :: Learn Lua — core language reference
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------------------------------------------

--- Core Lua language, taught from the Diver config.
--
-- This module is a *runnable* tour of the Lua language features you will meet
-- when reading `diver`. Every function here is real Lua you could paste into
-- `:lua` inside Neovim. The comments use two annotation systems at once:
--
-- * **LDoc tags** (`@param`, `@return`, `@usage`) — these build the HTML docs.
-- * **LuaCATS annotations** (`---@param`, `---@return`, `---@type`) — these
--   feed `lua-language-server` so you get hovers and red squiggles in Neovim.
--
-- The two look almost identical on purpose. A single triple-dash comment with
-- `@param name type description` satisfies *both* tools. That is why `diver`
-- can document itself and type-check itself from the same comments.
--
-- @module learn_lua
-- @author Qompass AI
-- @license Apache-2.0

local M = {}

-- ---------------------------------------------------------------------------
-- 1. The eight Lua types
-- ---------------------------------------------------------------------------

--- Return the literal Lua type name of any value.
--
-- Lua has exactly eight types: `nil`, `boolean`, `number`, `string`,
-- `function`, `table`, `userdata`, and `thread`. You already know the
-- difference between a boolean and a float — Lua does *not* split numbers into
-- int and float as separate types (in Lua 5.1 / LuaJIT, which is what Neovim
-- uses, every number is a 64-bit float). The `type()` builtin tells you which
-- of the eight you are holding.
--
-- @usage
--   learn_lua.kind_of(true)   --> "boolean"
--   learn_lua.kind_of(3.14)   --> "number"
--   learn_lua.kind_of("hi")   --> "string"
--   learn_lua.kind_of(nil)    --> "nil"
---@param value any
---@return type # one of: nil|boolean|number|string|function|table|userdata|thread
function M.kind_of(value)
    return type(value)
end

--- Demonstrate Lua truthiness.
--
-- This is the single most important rule for reading `diver`. In Lua **only
-- `false` and `nil` are falsy**. *Everything else is truthy* — including `0`,
-- the empty string `""`, and empty tables `{}`. That is why you constantly see
-- guards like `if client.server_capabilities.completionProvider then` in
-- `lua/config/core/lsp.lua`: the field is either a truthy table or `nil`.
--
-- @usage
--   learn_lua.is_truthy(0)   --> true   (0 is truthy in Lua!)
--   learn_lua.is_truthy("")  --> true
--   learn_lua.is_truthy(nil) --> false
---@param value any
---@return boolean
function M.is_truthy(value)
    -- `not not value` collapses any value to a real boolean: the first `not`
    -- gives the opposite boolean, the second flips it back.
    return not not value
end

-- ---------------------------------------------------------------------------
-- 2. nil-coalescing with `or`, defaults with `and`/`or`
-- ---------------------------------------------------------------------------

--- Pick the first argument that is not `nil`/`false`, else a fallback.
--
-- `a or b` evaluates to `a` when `a` is truthy, otherwise to `b`. `diver` uses
-- this for defaults all over `init.lua`, e.g.
-- `user = env.USER or fn.system('whoami')`. It is Lua's equivalent of the
-- `??` operator in other languages.
--
-- @usage
--   learn_lua.default_to(vim.env.EDITOR, "nvim")
---@generic T
---@param value T?
---@param fallback T
---@return T
function M.default_to(value, fallback)
    return value or fallback
end

--- A safe ternary: `cond and a or b`.
--
-- Lua has no `?:` operator. The idiom `cond and a or b` works **as long as
-- `a` is never `false`/`nil`** (otherwise it would fall through to `b`). You
-- can see this exact shape in `init.lua`:
-- `o.shell = fn.executable('pwsh') == 1 and 'pwsh' or 'powershell'`.
--
---@param cond boolean
---@param when_true any
---@param when_false any
---@return any
function M.ternary(cond, when_true, when_false)
    return cond and when_true or when_false
end

-- ---------------------------------------------------------------------------
-- 3. Numbers — there is no separate int type
-- ---------------------------------------------------------------------------

--- Convert a 1-based line number to the 0-based index the API expects.
--
-- This is not just arithmetic — it teaches a real `diver` gotcha. Vimscript
-- and the user-facing world are **1-based** (line 1 is the first line), but the
-- modern `vim.api.*` functions are **0-based**. `lua/config/core/parser.lua`
-- literally does `lnum = tonumber(lnum) - 1` for exactly this reason.
--
-- @usage learn_lua.to_zero_based(1) --> 0
---@param one_based number
---@return number
function M.to_zero_based(one_based)
    return one_based - 1
end

-- ---------------------------------------------------------------------------
-- 4. Multiple return values
-- ---------------------------------------------------------------------------

--- Return several values at once.
--
-- Lua functions can return more than one value. `diver`'s
-- `lua/config/core/schema.lua` returns `vim.Schema|nil, integer|nil` from
-- `get_index`. Callers can grab as many as they want; extras are discarded.
--
-- @usage local n, first, last = learn_lua.bounds({10, 20, 30})
---@param list any[]
---@return integer count
---@return any first
---@return any last
function M.bounds(list)
    local n = #list
    return n, list[1], list[n]
end

-- ---------------------------------------------------------------------------
-- 5. The `pcall` safety net (protected call)
-- ---------------------------------------------------------------------------

--- Try to require a module without crashing the whole config.
--
-- This is the single most-used safety pattern in `diver`. See
-- `lua/config/init.lua`'s `safe_require`. `pcall(f, ...)` runs `f` inside a
-- protected sandbox and returns `ok, result`: if `f` errored, `ok` is `false`
-- and `result` is the error message; otherwise `ok` is `true` and `result` is
-- the return value. A broken plugin therefore cannot take down your editor.
--
-- @usage local mod = learn_lua.safe_require("config.core.lsp")
---@param name string
---@return table|nil module
---@return string|nil err
function M.safe_require(name)
    local ok, mod = pcall(require, name)
    if not ok then
        return nil, mod -- on failure, `mod` holds the error string
    end
    return mod, nil
end

--- Guard a call so a thrown error becomes a soft warning.
--
-- Mirrors the `call_if_present` helper in `lua/config/init.lua`. It checks the
-- argument really is a function before calling it, then wraps the call in
-- `pcall` so an exception is reported via `vim.notify` instead of aborting.
--
---@param maybe_fn function|any
---@param arg any
---@return boolean ran_ok
function M.call_if_function(maybe_fn, arg)
    if type(maybe_fn) ~= 'function' then
        return false
    end
    local ok, err = pcall(maybe_fn, arg)
    if not ok then
        -- `vim.notify` is the canonical way to surface messages in Neovim.
        vim.notify(('learn_lua: call failed: %s'):format(err), vim.log.levels.WARN)
    end
    return ok
end

-- ---------------------------------------------------------------------------
-- 6. Closures — functions that remember their environment
-- ---------------------------------------------------------------------------

--- Build a counter closure.
--
-- A closure is a function that "captures" local variables from where it was
-- created. `diver` uses closures constantly as keymap and autocmd callbacks —
-- e.g. the `toggle_netrw` function defined *inside* `setup_cicdmap` in
-- `lua/mappings/cicdmap.lua` closes over the surrounding `opts`.
--
-- @usage
--   local next_id = learn_lua.make_counter(10)
--   next_id() --> 11
--   next_id() --> 12
---@param start? integer
---@return fun(): integer
function M.make_counter(start)
    local n = start or 0 -- captured by the closure below
    return function()
        n = n + 1
        return n
    end
end

return M
