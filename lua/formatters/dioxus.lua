-- #################################################################
-- /qompassai/Diver/lua/formatters/dioxus.lua
-- Qompass AI Diver Native Dioxus RSX Formatter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/DioxusLabs/dioxus
---@source https://dioxuslabs.com/learn/0.7/guides/tools/

local fs = vim.fs
local type = type

local TIMEOUT_MS = 30000

---@param context FormatContext
---@return string[]
local function args(context)
    assert(type(context) == 'table')
    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')
    assert(type(context.root) == 'string')
    assert(context.root ~= '')

    --
    -- fmt:
    --   Run Dioxus's RSX formatter.
    --
    -- -f -:
    --   Read the current source from stdin and emit the formatted complete
    --   source to stdout. This preserves unsaved Neovim buffer changes.
    --
    -- Deliberately omitted:
    --
    --   --all-code
    --
    -- Default behavior formats Dioxus RSX only, leaving ordinary Rust source
    -- ownership to rustfmt/cargo fmt. Do not combine dx fmt --all-code with
    -- rustfmt as an automatic formatting chain.
    --
    -- Deliberately omitted:
    --
    --   --check
    --
    -- A formatter adapter requires formatted source on stdout. --check is
    -- suitable for CI, not buffer replacement.
    --
    -- Deliberately omitted:
    --
    --   --split-line-attributes
    --
    -- Its absence explicitly selects the Dioxus CLI default behavior: retain
    -- compact attributes unless normal RSX layout requires line splitting.
    --
    return {
        'fmt',

        '-f',
        '-',
    }
end

---@param context FormatContext
---@return string
local function cwd(context)
    assert(type(context) == 'table')
    assert(type(context.root) == 'string')
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

---@type Formatter
return {
    --
    -- Dioxus CLI executable. Install with:
    --
    --   cargo install dioxus-cli --locked
    --
    -- Do not substitute cargo run here: formatter invocation must not compile
    -- the current project or mutate Cargo dependency state.
    --
    cmd = 'dx',

    args = args,

    --
    -- args() consumes stdin explicitly through "-"; no filename is appended.
    --
    append_fname = false,

    --
    -- Execute from the Dioxus/Cargo project root so dx resolves project-local
    -- configuration, assets, and workspace context consistently.
    --
    cwd = cwd,

    --
    -- Feed the complete current Neovim buffer to dx fmt. This allows RSX
    -- formatting before the buffer has been written to disk.
    --
    stdin = true,

    --
    -- dx fmt writes formatted source to stdout when passed "-f -".
    --
    stream = 'stdout',

    --
    -- Formatting should not compile, build, serve, bundle, start a watcher,
    -- access the network, or modify project files outside the current buffer.
    --
    timeout = TIMEOUT_MS,

    root_markers = {
        'Dioxus.toml',
        'dioxus.toml',

        'Cargo.toml',

        '.git',
    },
}