-- /qompassai/Diver/lua/utils/toolmgr.lua
-- Qompass AI Diver Tool Manager (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Shared helpers for the tool-integration modules (git, cargo, khal, jj,
-- syncthing, tailscale, pass, tmux, ...): package-manager detection, tool
-- version probing, semver comparison, bounded GitHub release lookups, and
-- the canonical "update package / apply migrations / skip" choice dialog.
--
-- Every subprocess goes through security.rce.safe_exec (argv form only;
-- a bare string command is refused). Requiring this module performs no
-- I/O and registers no commands.

---@module 'utils.toolmgr'

local M = {}

local rce = require('security.rce')

local CURL_TIMEOUT_S = 15 -- wall-clock cap per GitHub API request.
local CURL_SIZE_BYTES_MAX = 262144 -- 256 KiB cap on any API response body.
local VERSION_BYTES_MAX = 4096 -- cap on --version output scanned for a version.
local REPO_PATTERN = '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -- owner/name shape.
local VERSION_PATTERN = '%d+%.%d+%.?%d*'

---Package managers in detection order. pacman first: Matt is Arch-based.
---@type string[]
local PACKAGE_MANAGERS = { 'pacman', 'apt', 'dnf', 'brew' }

---Install argv per package manager. sudo-bearing managers run without
---yes-flags so their own prompts stay visible in the terminal.
---@param manager string One of PACKAGE_MANAGERS.
---@param package string Package name as the manager knows it.
---@return string[]|nil argv
---@return string|nil err
local function install_argv(manager, package)
    if manager == 'pacman' then
        return { 'sudo', 'pacman', '-S', package }, nil
    end
    if manager == 'apt' then
        return { 'sudo', 'apt', 'install', package }, nil
    end
    if manager == 'dnf' then
        return { 'sudo', 'dnf', 'install', package }, nil
    end
    if manager == 'brew' then
        return { 'brew', 'install', package }, nil
    end
    return nil, 'unknown package manager: ' .. manager
end

---Detect the first available system package manager.
---@return string|nil manager 'pacman'|'apt'|'dnf'|'brew', or nil when none found.
function M.detect_package_manager()
    for _, manager in ipairs(PACKAGE_MANAGERS) do
        if vim.fn.executable(manager) == 1 then
            return manager
        end
    end
    return nil
end

---Check whether a binary is on PATH.
---@param name string Binary name, e.g. 'git'.
---@return boolean present
function M.binary_present(name)
    return vim.fn.executable(name) == 1
end

---Run a --version style command and extract the first X.Y[.Z] token.
---Never throws: missing binaries and parse failures return nil + reason.
---@param argv string[] argv for the version command, e.g. { 'git', '--version' }.
---@return string|nil version Dotted version, e.g. '2.47.1'.
---@return string|nil err Human-readable reason on expected failure.
function M.command_version(argv)
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = 10000 })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    local output = (result.stdout or ''):sub(1, VERSION_BYTES_MAX)
    local version = output:match(VERSION_PATTERN)
    if version == nil then
        return nil, 'no version token in output'
    end
    return version, nil
end

---Strip a tag down to its leading dotted-numeric run: 'v2.47.1' -> '2.47.1',
---'git-xet-v0.2.0' -> '0.2.0'.
---@param tag string Raw tag or version string.
---@return string|nil normalized
function M.normalize_version(tag)
    if type(tag) ~= 'string' then
        return nil
    end
    return tag:match(VERSION_PATTERN)
end

---Compare two dotted versions numerically. Missing parts count as 0, so
---'2.47' equals '2.47.0'.
---@param a string First version (already normalized).
---@param b string Second version (already normalized).
---@return integer -1 when a<b, 0 when equal, 1 when a>b.
function M.compare_versions(a, b)
    local parts_a = vim.split(a, '.', { plain = true })
    local parts_b = vim.split(b, '.', { plain = true })
    local width = math.max(#parts_a, #parts_b)
    for index = 1, width do
        local num_a = tonumber(parts_a[index]) or 0
        local num_b = tonumber(parts_b[index]) or 0
        if num_a < num_b then
            return -1
        end
        if num_a > num_b then
            return 1
        end
    end
    return 0
end

---Fetch the latest release tag for owner/name from the GitHub API.
---Bounded: 15 s wall clock, 256 KiB body, argv-only curl (no shell).
---@param repo string 'owner/name', validated against REPO_PATTERN.
---@return string|nil tag e.g. 'v2.47.1'.
---@return string|nil err Human-readable reason on expected failure.
function M.github_latest_tag(repo)
    if type(repo) ~= 'string' or not repo:match(REPO_PATTERN) then
        return nil, 'repo must look like owner/name, got ' .. tostring(repo)
    end
    local url = 'https://api.github.com/repos/' .. repo .. '/releases/latest'
    local argv = {
        'curl',
        '-sS',
        '--max-time',
        tostring(CURL_TIMEOUT_S),
        '--max-filesize',
        tostring(CURL_SIZE_BYTES_MAX),
        url,
    }
    local result, exec_err = rce.safe_exec(argv, { timeout_ms = (CURL_TIMEOUT_S + 5) * 1000 })
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'curl exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200)
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok or type(decoded) ~= 'table' then
        return nil, 'GitHub API response did not decode as JSON'
    end
    local tag = decoded.tag_name
    if type(tag) ~= 'string' or tag == '' then
        return nil, 'GitHub API response has no tag_name'
    end
    return tag, nil
end

---@class utils.toolmgr.BinarySpec
---@field name string Binary name for PATH probing, e.g. 'git'.
---@field version_argv? string[] argv producing version output (default { name, '--version' }).
---@field min_version? string Minimum acceptable dotted version, e.g. '2.40.0'.

---@class utils.toolmgr.BinaryReport
---@field name string
---@field present boolean
---@field version string|nil
---@field meets_minimum boolean
---@field detail string One-line human summary.

---Probe one binary: presence, version, minimum-version gate.
---Never throws; every outcome is reported in the returned table.
---@param spec utils.toolmgr.BinarySpec
---@return utils.toolmgr.BinaryReport
function M.check_binary(spec)
    local report = {
        name = spec.name,
        present = false,
        version = nil,
        meets_minimum = false,
        detail = spec.name .. ': not found on PATH',
    }
    if not M.binary_present(spec.name) then
        return report
    end
    report.present = true
    local argv = spec.version_argv or { spec.name, '--version' }
    local version, version_err = M.command_version(argv)
    if version == nil then
        report.detail = spec.name .. ': present but version unreadable (' .. tostring(version_err) .. ')'
        return report
    end
    report.version = version
    if spec.min_version == nil then
        report.meets_minimum = true
        report.detail = ('%s: %s (no minimum declared)'):format(spec.name, version)
        return report
    end
    if M.compare_versions(version, spec.min_version) >= 0 then
        report.meets_minimum = true
        report.detail = ('%s: %s meets minimum %s'):format(spec.name, version, spec.min_version)
    else
        report.detail = ('%s: %s below minimum %s'):format(spec.name, version, spec.min_version)
    end
    return report
end

---@class utils.toolmgr.Migration
---@field version string Release whose changes this migration handles.
---@field description string One-line summary shown before applying.
---@field apply fun(): boolean, string Applies the migration; returns ok + note.

---Apply each migration newer than from_version, oldest first.
---@param migrations utils.toolmgr.Migration[]
---@param from_version string|nil Dotted version the config was written for.
---@return integer applied_count
---@return string[] notes Per-migration outcome lines.
function M.apply_migrations(migrations, from_version)
    local from = M.normalize_version(from_version or '0.0.0') or '0.0.0'
    local pending = {}
    for _, migration in ipairs(migrations) do
        local target = M.normalize_version(migration.version)
        if target ~= nil and M.compare_versions(target, from) > 0 then
            pending[#pending + 1] = migration
        end
    end
    table.sort(pending, function(left, right)
        local left_v = M.normalize_version(left.version) or '0.0.0'
        local right_v = M.normalize_version(right.version) or '0.0.0'
        return M.compare_versions(left_v, right_v) < 0
    end)
    local applied_count = 0
    local notes = {}
    for _, migration in ipairs(pending) do
        local ok, apply_err = pcall(migration.apply)
        if ok and apply_err ~= false then
            applied_count = applied_count + 1
            notes[#notes + 1] = ('applied %s: %s'):format(migration.version, migration.description)
        else
            notes[#notes + 1] = ('FAILED %s: %s'):format(migration.version, tostring(apply_err))
        end
    end
    return applied_count, notes
end

---@class utils.toolmgr.UpdateSpec
---@field tool_label string Human label, e.g. 'git'.
---@field repo string 'owner/name' for the GitHub release lookup.
---@field package string Package name for the system package manager.
---@field current_version string|nil Installed dotted version (nil = not installed).
---@field known_upstream_version string Newest version this module knows about.
---@field migrations utils.toolmgr.Migration[] Config migrations for new releases.
---@field select_impl? fun(items: string[], opts: table, on_choice: fun(idx: integer|nil)) Test seam.

---Compare installed + known versions against the latest GitHub release and
---offer update / migrate / skip. Never installs without the explicit
---vim.ui.select choice. All network I/O is bounded (see M.github_latest_tag).
---@param spec utils.toolmgr.UpdateSpec
function M.check_update(spec)
    local label = spec.tool_label
    if spec.current_version == nil then
        vim.notify(label .. ': not installed; nothing to update', vim.log.levels.WARN)
        return
    end
    local tag, tag_err = M.github_latest_tag(spec.repo)
    if tag == nil then
        vim.notify(label .. ': release check failed: ' .. tostring(tag_err), vim.log.levels.WARN)
        return
    end
    local latest = M.normalize_version(tag)
    local current = M.normalize_version(spec.current_version)
    local known = M.normalize_version(spec.known_upstream_version)
    if latest == nil or current == nil or known == nil then
        vim.notify(label .. ': unparseable version in comparison', vim.log.levels.WARN)
        return
    end
    local baseline = known
    if M.compare_versions(current, known) > 0 then
        baseline = current
    end
    if M.compare_versions(latest, baseline) <= 0 then
        vim.notify(('%s: up to date (%s; latest %s)'):format(label, current, latest), vim.log.levels.INFO)
        return
    end
    local items = {
        'Update package via system package manager',
        'Apply config migrations for ' .. latest,
        'Skip',
    }
    local select_impl = spec.select_impl or vim.ui.select
    select_impl(items, { prompt = ('%s %s -> %s:'):format(label, current, latest) }, function(choice)
        if choice == 1 then
            M.install_package(label, spec.package)
        elseif choice == 2 then
            local applied, notes = M.apply_migrations(spec.migrations or {}, current)
            vim.notify(
                ('%s: %d migration(s) applied\n%s'):format(label, applied, table.concat(notes, '\n')),
                vim.log.levels.INFO
            )
        end
    end)
end

---Install a package in a visible terminal split so sudo prompts stay
---interactive. Called only from the explicit update choice in M.check_update.
---@param label string Human label for notifications.
---@param package string Package name as the manager knows it.
function M.install_package(label, package)
    local manager = M.detect_package_manager()
    if manager == nil then
        vim.notify(label .. ': no supported package manager found (pacman/apt/dnf/brew)', vim.log.levels.ERROR)
        return
    end
    local argv, argv_err = install_argv(manager, package)
    if argv_err ~= nil then
        vim.notify(label .. ': ' .. argv_err, vim.log.levels.ERROR)
        return
    end
    vim.cmd('botright 15split')
    local buf = vim.api.nvim_get_current_buf()
    vim.fn.termopen(argv)
    vim.api.nvim_buf_set_name(buf, 'toolmgr://install/' .. label)
    vim.notify(('%s: installing via %s (terminal below)'):format(label, manager), vim.log.levels.INFO)
end

return M
