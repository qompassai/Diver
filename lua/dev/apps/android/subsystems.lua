-- #################################################################
-- /qompassai/lua/dev/android/subsystems.lua
-- Qompass AI Android subsystem wiring
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
--- Presence checks for the diver subsystems that serve Android work.
---
--- Plain-language version: Android development touches half of diver —
--- LSP for Kotlin/Java, DAP for debugging, linters for Android Lint,
--- formatters for ktlint, SCIP for indexing. This module asks each one
--- "are you here and usable?" without ever erroring when something is
--- missing, so :AndroidDoctor can report the real state.
---
--- Wiring facts (verified 2026-09-27):
--- - LSP: lsp/kotlin_ls.lua drives fwcd/kotlin-language-server (deprecated
---   upstream in favor of JetBrains' official kotlin-lsp; stdio is its
---   default mode). lsp/java_ls.lua drives georgewfraser/java-language-server.
--- - DAP: lua/dap/android.lua is a real native adapter (lldb-server deploy
---   + JDWP forwarding) with :AndroidBuildInstallLaunch et al.
--- - Linters: lua/linters/android_lint.lua runs :app:lintDebug through
---   gradlew and parses the SARIF report; detekt/ktlint linters cover
---   style on kotlin buffers.
--- - Formatters: lua/formatters/ktlint.lua formats kotlin via ktlint.
--- - SCIP: lua/scip/indexers/java.lua indexes Gradle projects (Kotlin
---   included) with scip-java --build-tool=gradle.
--- - Refactor: flows through LSP code actions (lua/refactor/lsp.lua);
---   nothing Android-specific is needed.
--- - AI: lua/ai/ has no dev-suite build hook; android build/test stays in
---   this suite. Documented here so the gap is explicit, not silent.

local M = {}

---@class AndroidSubsystemCheck
---@field id string Stable check id.
---@field name string Subsystem name.
---@field present boolean Whether the subsystem integration is available.
---@field detail string What was found.

---Check whether an executable is on PATH.
---@param name string Executable name.
---@return boolean
local function has_executable(name)
    return vim.fn.executable(name) == 1
end

---Check whether a runtime file exists (no require side effects).
---@param relpath string Path under a runtimepath entry, e.g. 'lua/scip/indexers/java.lua'.
---@return boolean
local function has_runtime_file(relpath)
    local found = vim.api.nvim_get_runtime_file(relpath, false)
    return #found > 0
end

---@return AndroidSubsystemCheck
local function check_kotlin_lsp()
    local present = has_executable('kotlin-language-server')
    return {
        id = 'lsp-kotlin',
        name = 'Kotlin LSP',
        present = present,
        detail = present
                and 'kotlin-language-server on PATH (fwcd server; upstream deprecated, see kotlin/kotlin-lsp).'
            or 'kotlin-language-server not on PATH; lsp/kotlin_ls.lua cannot attach.',
    }
end

---@return AndroidSubsystemCheck
local function check_java_lsp()
    local present = has_executable('java-language-server')
    return {
        id = 'lsp-java',
        name = 'Java LSP',
        present = present,
        detail = present and 'java-language-server on PATH.'
            or 'java-language-server not on PATH; lsp/java_ls.lua cannot attach.',
    }
end

---@return AndroidSubsystemCheck
local function check_dap()
    local ok, dap_android = pcall(require, 'dap.android')
    local present = ok and type(dap_android) == 'table' and type(dap_android.setup) == 'function'
    return {
        id = 'dap-android',
        name = 'Android DAP',
        present = present,
        detail = present and 'dap.android loaded: lldb native attach + JDWP forwarding available.'
            or 'dap.android module unavailable.',
    }
end

---@return AndroidSubsystemCheck
local function check_android_lint()
    local ok, linters = pcall(require, 'linters')
    local present = false
    if ok and type(linters) == 'table' and type(linters.get_definition) == 'function' then
        local definition = linters.get_definition('android_lint')
        present = type(definition) == 'table'
    end

    return {
        id = 'linter-android-lint',
        name = 'Android Lint adapter',
        present = present,
        detail = present and 'linters/android_lint.lua registered (runs :app:lintDebug, parses SARIF).'
            or 'linters/android_lint.lua not registered.',
    }
end

---@return AndroidSubsystemCheck
local function check_ktlint_formatter()
    local ok, formatters = pcall(require, 'formatters')
    local present = false
    if ok and type(formatters) == 'table' and type(formatters.get_definition) == 'function' then
        local definition = formatters.get_definition('ktlint')
        present = type(definition) == 'table'
    end

    return {
        id = 'formatter-ktlint',
        name = 'ktlint formatter',
        present = present,
        detail = present and 'formatters/ktlint.lua registered for kotlin.' or 'formatters/ktlint.lua not registered.',
    }
end

---@return AndroidSubsystemCheck
local function check_scip()
    local present = has_runtime_file('lua/scip/indexers/java.lua')
    return {
        id = 'scip-java',
        name = 'SCIP indexer (java/kotlin)',
        present = present,
        detail = present and 'scip/indexers/java.lua present: indexes Gradle projects (incl. Kotlin) via scip-java.'
            or 'scip/indexers/java.lua missing from runtimepath.',
    }
end

---@return AndroidSubsystemCheck
local function check_refactor()
    local present = has_runtime_file('lua/refactor/lsp.lua')
    return {
        id = 'refactor-lsp',
        name = 'Refactor via LSP',
        present = present,
        detail = present and 'refactor/lsp.lua present: rename/code-action flow through the Kotlin/Java LSP servers.'
            or 'refactor/lsp.lua missing from runtimepath.',
    }
end

---Run every subsystem presence check.
---@return AndroidSubsystemCheck[]
function M.check_all()
    return {
        check_kotlin_lsp(),
        check_java_lsp(),
        check_dap(),
        check_android_lint(),
        check_ktlint_formatter(),
        check_scip(),
        check_refactor(),
    }
end

return M
