-- #################################################################
-- /qompassai/Diver/lua/bsp/servers/init.lua
-- Qompass AI Init
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
--- Registry of every build server the native BSP client knows how to talk
--- to. Plain-language version: each entry names one program that can answer
--- "how does this project build?" and points at the Lua module that knows
--- how to find that program's project root and read its `.bsp/*.json`
--- connection file. `M.detect` walks the list in order and returns the first
--- server whose root markers match the current buffer.
---@module 'dev.bsp.servers'

local M = {}

---@class QompassBspServerEntry
---@field name string Short server name, also matched against connection `name`.
---@field module string Lua module path implementing the server contract.
---@field filetypes string[] Vim filetypes that may belong to this server.
---@field summary string One-line plain-language description.

---@type QompassBspServerEntry[]
local registry = {
    {
        name = 'gradle',
        module = 'bsp.servers.gradle',
        filetypes = { 'java', 'kotlin', 'groovy' },
        summary = 'Gradle builds (Java/Kotlin, incl. Android apps) via build-server-for-gradle',
    },
    {
        name = 'cargo-bsp',
        module = 'bsp.servers.cargo',
        filetypes = { 'rust' },
        summary = 'Cargo builds (Rust, incl. the phlow agent runtime) via cargo-bsp',
    },
    {
        name = 'bazelbsp',
        module = 'bsp.servers.bazel',
        filetypes = { 'java', 'kotlin', 'scala', 'python', 'cpp', 'bzl' },
        summary = 'Bazel workspaces (multi-language) via JetBrains Hirschgarten',
    },
    {
        name = 'sbt',
        module = 'bsp.servers.sbt',
        filetypes = { 'scala', 'java' },
        summary = 'sbt builds (Scala/Java); BSP is built into sbt itself since 1.4.0',
    },
    {
        name = 'mill',
        module = 'bsp.servers.mill',
        filetypes = { 'scala', 'java', 'kotlin' },
        summary = 'Mill builds (Scala/Java/Kotlin); BSP built in since Mill 0.9.3',
    },
    {
        name = 'bloop',
        module = 'bsp.servers.bloop',
        filetypes = { 'scala', 'java' },
        summary = 'Bloop compile server (backs sbt/Gradle/Maven/Mill exports)',
    },
    {
        name = 'scala-cli',
        module = 'bsp.servers.scalacli',
        filetypes = { 'scala' },
        summary = 'scala-cli (Scala/Java scripts and small projects)',
    },
    {
        name = 'pants',
        module = 'bsp.servers.pants',
        filetypes = { 'python', 'java', 'scala', 'go', 'sh' },
        summary = 'Pants monorepo builds (experimental-bsp goal)',
    },
    {
        name = 'swift-bsp',
        module = 'bsp.servers.swift',
        filetypes = { 'swift' },
        summary = 'SwiftPM/Xcode projects via the community swift-bsp server',
    },
}

---@return QompassBspServerEntry[]
function M.list()
    return registry
end

---@param name string
---@return QompassBspServerEntry|nil
function M.get(name)
    if type(name) ~= 'string' or name == '' then
        return nil
    end

    for _, entry in ipairs(registry) do
        if entry.name == name then
            return entry
        end
    end

    return nil
end

---@return string[]
function M.filetypes()
    local seen = {}
    local filetypes = {}

    for _, entry in ipairs(registry) do
        for _, filetype in ipairs(entry.filetypes) do
            if not seen[filetype] then
                seen[filetype] = true
                filetypes[#filetypes + 1] = filetype
            end
        end
    end

    table.sort(filetypes)
    return filetypes
end

---@param entry QompassBspServerEntry
---@return table|nil
local function load_server(entry)
    local ok, server = pcall(require, entry.module)
    if ok and type(server) == 'table' then
        return server
    end
    return nil
end

---@param entry QompassBspServerEntry
---@param root string
---@return boolean strong_hit, boolean bsp_hit
local function match_markers(entry, root)
    local server = load_server(entry)
    if not server or type(server.markers) ~= 'function' then
        return false, false
    end

    local ok, markers = pcall(server.markers)
    if not ok or type(markers) ~= 'table' then
        return false, false
    end

    local strong_hit, bsp_hit = false, false
    for _, marker in ipairs(markers) do
        if type(marker) == 'string' and marker ~= '' then
            local stat = vim.uv.fs_stat(vim.fs.joinpath(root, marker))
            if stat then
                if marker == '.bsp' then
                    bsp_hit = true
                else
                    strong_hit = true
                end
            end
        end
    end

    return strong_hit, bsp_hit
end

---@param root string
---@return QompassBspServerEntry|nil
function M.detect_root(root)
    if type(root) ~= 'string' or root == '' then
        return nil
    end

    local bsp_dir_found = false
    for _, entry in ipairs(registry) do
        local strong_hit, bsp_hit = match_markers(entry, root)
        if strong_hit then
            return entry
        end
        bsp_dir_found = bsp_dir_found or bsp_hit
    end

    if not bsp_dir_found then
        return nil
    end

    -- Only a bare `.bsp/` matched: the cards inside are the best signal.
    local util_ok, util = pcall(require, 'bsp.servers.util')
    local connections = {}
    if util_ok and type(util) == 'table' and type(util.list_connections) == 'function' then
        local ok_list, listed = pcall(util.list_connections, root)
        if ok_list and type(listed) == 'table' then
            connections = listed
        end
    end

    -- Prefer the server whose registry name matches a card's `name`.
    for _, entry in ipairs(registry) do
        for _, connection in ipairs(connections) do
            if connection.name == entry.name then
                return entry
            end
        end
    end

    -- Else the first server (registry order) that can produce a valid card.
    for _, entry in ipairs(registry) do
        local server = load_server(entry)
        if server and type(server.connection) == 'function' then
            local ok_conn, connection = pcall(server.connection, root)
            if ok_conn and connection ~= nil then
                return entry
            end
        end
    end

    return nil
end

---@param bufnr? integer
---@return QompassBspServerEntry|nil, string|nil
function M.detect(bufnr)
    for _, entry in ipairs(registry) do
        local server = load_server(entry)
        if server and type(server.root) == 'function' then
            local ok_root, root = pcall(server.root, bufnr)
            if ok_root and type(root) == 'string' and root ~= '' then
                -- Disambiguate: the best server for this root wins over
                -- whichever module happened to match first.
                return M.detect_root(root) or entry, root
            end
        end
    end

    return nil, nil
end

return M
