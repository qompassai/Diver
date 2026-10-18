-- /qompassai/Diver/lua/bsp/servers/init.lua
-- Qompass AI Init
--- Registry of every build server the native BSP client knows how to talk
--- to. Plain-language version: each entry names one program that can answer
--- "how does this project build?" and points at the Lua module that knows
--- how to find that program's project root and read its `.bsp/*.json`
--- connection file. `M.detect` walks the list in order and returns the first
--- server whose root markers match the current buffer.
---@module 'dev.bsp.servers'

local M = {}

---@class QompassBspServerEntry
---@field filetypes string[] Vim filetypes that may belong to this server.
---@field module string Lua module path implementing the server contract.
---@field name string Short server name, also matched against connection `name`.
---@field summary string One-line plain-language description.

---@type QompassBspServerEntry[]
local registry = {
    {
        filetypes = { 'groovy', 'java', 'kotlin' },
        module = 'dev.bsp.servers.gradle',
        name = 'gradle',
        summary = 'Gradle builds (Java/Kotlin, incl. Android apps) via build-server-for-gradle',
    },
    {
        filetypes = { 'rust' },
        module = 'dev.bsp.servers.cargo',
        name = 'cargo-bsp',
        summary = 'Cargo builds (Rust, incl. the phlow agent runtime) via cargo-bsp',
    },
    {
        filetypes = { 'bzl', 'cpp', 'java', 'kotlin', 'python', 'scala' },
        module = 'dev.bsp.servers.bazel',
        name = 'bazelbsp',
        summary = 'Bazel workspaces (multi-language) via JetBrains Hirschgarten',
    },
    {
        filetypes = { 'java', 'scala' },
        module = 'dev.bsp.servers.sbt',
        name = 'sbt',
        summary = 'sbt builds (Scala/Java); BSP is built into sbt itself since 1.4.0',
    },
    {
        filetypes = { 'java', 'kotlin', 'scala' },
        module = 'dev.bsp.servers.mill',
        name = 'mill',
        summary = 'Mill builds (Scala/Java/Kotlin); BSP built in since Mill 0.9.3',
    },
    {
        filetypes = { 'java', 'scala' },
        module = 'dev.bsp.servers.bloop',
        name = 'bloop',
        summary = 'Bloop compile server (backs sbt/Gradle/Maven/Mill exports)',
    },
    {
        filetypes = { 'scala' },
        module = 'dev.bsp.servers.scalacli',
        name = 'scala-cli',
        summary = 'scala-cli (Scala/Java scripts and small projects)',
    },
    {
        filetypes = { 'go', 'java', 'python', 'scala', 'sh' },
        module = 'dev.bsp.servers.pants',
        name = 'pants',
        summary = 'Pants monorepo builds (experimental-bsp goal)',
    },
    {
        filetypes = { 'swift' },
        module = 'dev.bsp.servers.swift',
        name = 'swift-bsp',
        summary = 'SwiftPM/Xcode projects via the community swift-bsp server',
    },
}

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
    local util_ok, util = pcall(require, 'dev.bsp.servers.util')
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

---@return QompassBspServerEntry[]
function M.list()
    return registry
end

return M
