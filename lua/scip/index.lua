--- SCIP indexer glue — code intelligence for precise jump-to-definition.
---
--- Plain-language version: SCIP is a format for pre-computed code knowledge:
--- exactly where every symbol is defined and used. This module wires up the
--- indexer so Neovim can offer precise go-to-definition even for huge
--- codebases. It runs on demand via its command; it needs a SCIP indexer
--- for your language.
---@module 'scip.index'
-- #################################################################
-- /qompassai/lua/scip/index.lua
-- Qompass AI SCIP Index
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

local api = vim.api

local config = require('scip.config')
local registry = require('scip.registry')
local root = require('scip.root')
local state = require('scip.state')
local ui = require('scip.ui')
local utils = require('scip.utils')

local M = {}

---@class ScipIndexOpts
---@field bufnr? integer Buffer used for indexer detection.
---@field root? string Explicit project root override.

---Byte budget for streamed subprocess output. A SCIP indexer (or the `scip`
---CLI) can emit arbitrary amounts of text; the stream keeps only the first
---this-many bytes of stdout plus the first this-many of stderr, then drains
---and discards the rest, so a pathological process cannot exhaust memory
---before its exit callback ever runs.
---@type integer
local OUTPUT_MAX_BYTES = 65536

---Bounded output accumulator for one stream of a subprocess.
---@class ScipOutputSink
---@field bytes integer Retained bytes.
---@field dropped integer Discarded bytes after the budget ran out.

---Start a new accumulator.
---@return ScipOutputSink
local function new_output_sink()
    return { bytes = 0, dropped = 0 }
end

---Feed a streamed chunk into the accumulator, keeping only up to the budget.
---@param sink ScipOutputSink
---@param chunk string
---@return string retained Retained portion of the chunk (possibly empty).
local function feed_output(sink, chunk)
    if sink.bytes >= OUTPUT_MAX_BYTES then
        sink.dropped = sink.dropped + #chunk

        return ''
    end

    local kept = chunk:sub(1, OUTPUT_MAX_BYTES - sink.bytes)

    sink.bytes = sink.bytes + #kept
    sink.dropped = sink.dropped + (#chunk - #kept)

    return kept
end

---Render a truncation notice when the stream exceeded the budget.
---@param sink ScipOutputSink
---@param name string Process name used in the notice.
---@return string? notice Nil when nothing was dropped.
local function truncation_notice(sink, name)
    if sink.dropped <= 0 then
        return nil
    end

    return string.format(
        '[scip] %s: output truncated at %d bytes; %d further bytes discarded',
        name,
        OUTPUT_MAX_BYTES,
        sink.dropped
    )
end

---Bounded result delivered to `bounded_system` exit callbacks.
---@class ScipBoundedResult
---@field code integer Process exit code.
---@field signal integer Termination signal.
---@field stdout string Retained stdout (first OUTPUT_MAX_BYTES bytes).
---@field stderr string Retained stderr (first OUTPUT_MAX_BYTES bytes).
---@field notices string[] Truncation notices; empty when nothing was dropped.

---Spawn `vim.system` with streaming, bounded output.
---
---Unlike `text = true` alone — which buffers the entire output before the
---exit callback runs — the stdout/stderr callbacks below drain the stream
---while retaining only the first OUTPUT_MAX_BYTES per stream. Truncation is
---reported through `notices` so the UI can surface it.
---
---@param command string[] argv; command[1] names the process in notices.
---@param cwd string Working directory.
---@param on_exit fun(result: ScipBoundedResult) Exit callback, run via vim.schedule.
---@return vim.SystemObj
local function bounded_system(command, cwd, on_exit)
    local out_sink, err_sink = new_output_sink(), new_output_sink()
    local out_parts, err_parts = {}, {}

    return vim.system(command, {
        cwd = cwd,
        text = true,
        timeout = config.get().timeout,
        stdout = function(_, chunk)
            if chunk ~= nil then
                out_parts[#out_parts + 1] = feed_output(out_sink, chunk)
            end
        end,
        stderr = function(_, chunk)
            if chunk ~= nil then
                err_parts[#err_parts + 1] = feed_output(err_sink, chunk)
            end
        end,
    }, function(result)
        vim.schedule(function()
            local notices = {}
            local out_notice = truncation_notice(out_sink, command[1])
            local err_notice = truncation_notice(err_sink, command[1])

            if out_notice ~= nil then
                notices[#notices + 1] = out_notice
            end

            if err_notice ~= nil then
                notices[#notices + 1] = err_notice
            end

            on_exit({
                code = result.code,
                signal = result.signal,
                stdout = table.concat(out_parts),
                stderr = table.concat(err_parts),
                notices = notices,
            })
        end)
    end)
end

---Render truncation notices as appendable text.
---@param result ScipBoundedResult
---@return string suffix '' when nothing was dropped, else the notices joined
---with newlines and a leading newline.
local function notice_suffix(result)
    if #result.notices == 0 then
        return ''
    end

    return '\n' .. table.concat(result.notices, '\n')
end

---Validate a generated SCIP index after indexing completes.
---
---This runs only when:
---
---1. `lint_after_index` is enabled.
---2. The `scip` CLI is executable.
---3. The generated index file exists.
---
---Validation is asynchronous, so it captures the state generation that
---triggered it and reports only while that generation still owns the state:
---a stale lint must not announce results for an indexing run the user has
---already superseded.
---
---@param expected_generation integer State generation captured when the indexing run finished.
---@param ctx ScipContext Indexing context (root, index file, buffer).
---@return boolean started True when validation started (or short-circuited
---with a warning); false when disabled.
local function lint_after_index(expected_generation, ctx)
    if not config.get().lint_after_index then
        return false
    end

    if not utils.executable('scip') then
        ui.notify(
            'SCIP index generated, but the scip CLI is unavailable for validation',
            vim.log.levels.WARN
        )

        return true
    end

    if not utils.path_exists(ctx.index_file) then
        ui.notify(
            'Indexer exited successfully but did not create ' .. ctx.index_file,
            vim.log.levels.WARN
        )

        return true
    end

    bounded_system({ 'scip', 'lint', ctx.index_file }, ctx.root, function(result)
        -- The run that triggered this lint may have been superseded while
        -- validation was in flight.
        if not state.owns(expected_generation) then
            return
        end

        if result.code == 0 then
            ui.notify('Index generated and validated: ' .. ctx.index_file)
            return
        end

        ui.notify('SCIP index validation failed', vim.log.levels.ERROR)

        result.stderr = result.stderr .. notice_suffix(result)

        ui.show_failure('SCIP lint', result)
    end)

    return true
end

---Resolve the indexer that should be used for an indexing request.
---
---If a name is supplied, that specific indexer is resolved. Otherwise the
---registry auto-detects an indexer from the current buffer and project.
---
---@param name string?
---@param bufnr integer
---@param root_override? string
---@return ScipMatch?, string?
local function resolve_indexer(name, bufnr, root_override)
    if name ~= nil and name ~= '' then
        return registry.resolve(name, bufnr, root_override)
    end

    return registry.detect(bufnr)
end

---Build the complete command line for a resolved SCIP indexer.
---
---The indexer executable becomes argv[1], followed by any static or dynamic
---arguments returned by the indexer configuration.
---
---@param match ScipMatch
---@return string[]?, string?
local function build_command(match)
    local args, resolve_error = utils.resolve_args(match.indexer.args, match.context)

    if args == nil then
        return nil, resolve_error
    end

    local command = {
        match.command,
    }

    vim.list_extend(command, args)

    return command, nil
end

---Generate a SCIP index for the current project.
---
---A named indexer may be supplied explicitly. Otherwise the configured registry
---selects the first enabled indexer matching the current buffer's filetype and
---project markers.
---
---Only one asynchronous indexing process may run at a time.
---
---@param name? string Explicit indexer name.
---@param opts? ScipIndexOpts Optional indexing overrides.
---@return nil
function M.run(name, opts)
    if state.running() then
        ui.notify('A SCIP indexer is already running; use :ScipCancel first', vim.log.levels.WARN)
        return
    end

    opts = opts or {}

    local bufnr = opts.bufnr or api.nvim_get_current_buf()

    local match, resolve_error = resolve_indexer(name, bufnr, opts.root)

    if match == nil then
        ui.notify(resolve_error or 'Unable to resolve a SCIP indexer', vim.log.levels.ERROR)
        return
    end

    local command, command_error = build_command(match)

    if command == nil then
        ui.notify(command_error or 'Unable to build SCIP indexer command', vim.log.levels.ERROR)
        return
    end

    local started_at = vim.uv.hrtime()

    ui.notify(('Indexing %s with %s'):format(match.context.root, match.command))

    -- Assigned by state.start() below. The exit callback cannot run before
    -- that assignment, so the upvalue is always populated when read.
    ---@type integer?
    local expected_generation = nil

    ---@type vim.SystemObj
    local job

    job = bounded_system(command, match.context.root, function(result)
        -- Ignore stale callbacks. This is important if a process
        -- was cancelled and another indexer started afterward.
        if state.job() ~= job then
            return
        end

        local elapsed = state.elapsed()

        state.clear()

        if result.code ~= 0 then
            ui.notify(
                ('%s failed after %.1f seconds'):format(match.command, elapsed),
                vim.log.levels.ERROR
            )

            result.stderr = result.stderr .. notice_suffix(result)

            ui.show_failure('SCIP: ' .. match.name, result)
            return
        end

        -- lint_after_index owns the enabled-flag check; when disabled it
        -- returns false and we fall through to the success notice.
        ---@cast expected_generation integer
        if lint_after_index(expected_generation, match.context) then
            return
        end

        ui.notify(('Index generated in %.1f seconds: %s'):format(elapsed, match.context.index_file))
    end)

    expected_generation = state.start(job, match.name, match.context.root, started_at)
end

---Cancel the currently active SCIP indexing process.
---
---SIGTERM is sent through the native `vim.SystemObj` API. State is cleared
---immediately so another indexing request can begin.
---
---@return nil
function M.cancel()
    if state.cancel() then
        ui.notify('SCIP indexing cancelled', vim.log.levels.WARN)
        return
    end

    ui.notify('No SCIP indexer is running')
end

---Show current SCIP indexer or index-file status.
---
---When an indexer is running, its name, project root, and elapsed runtime are
---reported. Otherwise this reports whether the current project already has an
---index file.
---
---@return nil
function M.status()
    if state.running() then
        ui.notify(
            ('%s has been indexing %s for %.1f seconds'):format(
                state.indexer() or '<unknown>',
                state.root() or '<unknown>',
                state.elapsed()
            )
        )
        return
    end

    local project_root = root.resolve()
    local index_file = config.index_path(project_root)

    if utils.path_exists(index_file) then
        ui.notify('SCIP index available: ' .. index_file)
        return
    end

    ui.notify('No SCIP index exists at ' .. index_file)
end

---Execute the main `scip` CLI against the current project's index.
---
---This helper is used by lint, print, snapshot, and stats. The caller supplies
---the subcommand-specific arguments while this function handles executable
---validation, project-root discovery, asynchronous execution, and output UI.
---
---@param arguments string[] SCIP CLI arguments after the executable name.
---@param title string Display/quickfix title.
---@param filetype? string Scratch-buffer filetype for successful output.
---@return nil
local function run_scip(arguments, title, filetype)
    if not utils.executable('scip') then
        ui.notify('The scip CLI is not executable', vim.log.levels.ERROR)
        return
    end

    local project_root = root.resolve()
    local index_file = config.index_path(project_root)

    if not utils.path_exists(index_file) then
        ui.notify('No SCIP index exists at ' .. index_file, vim.log.levels.ERROR)
        return
    end

    local command = {
        'scip',
    }

    vim.list_extend(command, arguments)

    bounded_system(command, project_root, function(result)
        if result.code ~= 0 then
            ui.notify(title .. ' failed', vim.log.levels.ERROR)

            result.stderr = result.stderr .. notice_suffix(result)

            ui.show_failure(title, result)
            return
        end

        ui.show_output(title, utils.system_output(result) .. notice_suffix(result), filetype)
    end)
end

---Validate the current project's SCIP index.
---@return nil
function M.lint()
    local project_root = root.resolve()

    run_scip({
        'lint',
        config.index_path(project_root),
    }, 'SCIP lint')
end

---Print the current SCIP index as JSON.
---
---Successful output is opened in a native scratch buffer with `json`
---filetype so syntax highlighting and normal Neovim JSON behavior apply.
---
---@return nil
function M.print()
    local project_root = root.resolve()

    run_scip({
        'print',
        '--json',
        config.index_path(project_root),
    }, 'SCIP index', 'json')
end

---Generate a human-readable snapshot of the current SCIP index.
---
---The snapshot is written below the current project root in `scip-snapshot`.
---
---@return nil
function M.snapshot()
    local project_root = root.resolve()
    local index_file = config.index_path(project_root)
    local destination = vim.fs.joinpath(project_root, 'scip-snapshot')

    run_scip({
        'snapshot',
        '--from',
        index_file,
        '--to',
        destination,
    }, 'SCIP snapshot')
end

---Show statistics for the current SCIP index.
---@return nil
function M.stats()
    local project_root = root.resolve()

    run_scip({
        'stats',
        '--from',
        config.index_path(project_root),
    }, 'SCIP statistics')
end

return M
