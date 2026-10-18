-- /qompassai/Diver/lua/games/love2d/config.lua
-- Qompass AI LÖVE2D Platform Config
---@module 'games.love2d.config'
-- Central knobs for the LÖVE2D platform core: pinned engine version,
-- managed-install locations, packager size caps, and user-owned hooks
-- (itch.io Butler). No credentials live here -- Butler needs the user's
-- own login, which stays outside the repo by design.

---@class Love2dConfig
---@field binaries string[] PATH candidates for a preinstalled love binary
---@field env_names string[] env vars that override binary discovery
---@field group_order string[] action-menu group ordering
---@field output_filetype string scratch output buffer filetype
---@field love_version string pinned LÖVE release (see versions.lua)
---@field package_file_count_max integer max files in one .love
---@field package_file_size_max_bytes integer max bytes per packaged file
---@field package_total_size_max_bytes integer max bytes per .love
---@field package_zip_epoch string fixed mtime (UTC) for deterministic zips
---@field download_timeout_ms integer curl timeout for managed downloads
---@field apidefs_dir string directory holding the generated love.lua stubs
---@field butler Love2dButlerConfig itch.io Butler hook (no credentials)

---@class Love2dButlerConfig
---@field binary string butler executable name on PATH
---@field default_channel string itch channel used when none is given

local M = {}

M.binaries = {
    'love',
}

M.download_timeout_ms = 120000

M.env_names = {
    'LOVE_BIN',
    'NVIM_LOVE_BIN',
}

M.group_order = {
    'Run',
    'Develop',
    'Package',
    'Release',
    'Library',
    'Setup',
}

-- Pinned engine release. Bumped deliberately by editing versions.lua's
-- ARTIFACTS table; this string must stay in sync with it.
M.love_version = '11.5'

M.output_filetype = 'love2d-output'

-- Packager bounds: a .love is a zip, and zips are a classic decompression-
-- bomb vector. Everything the packager touches is capped.
M.package_file_count_max = 20000
M.package_file_size_max_bytes = 100 * 1024 * 1024
M.package_total_size_max_bytes = 500 * 1024 * 1024

-- Fixed timestamp (UTC, ISO-8601) stamped on every staged file before
-- zipping, so identical trees produce byte-identical .love files.
M.package_zip_epoch = '2000-01-01T00:00:00Z'

-- Directory holding the generated LuaCATS stubs (apidefs/love.lua),
-- derived from this file's location so health checks work regardless of
-- where the repo is checked out.
local here = debug.getinfo(1, 'S').source:sub(2)
M.apidefs_dir = vim.fn.fnamemodify(here, ':h') .. '/apidefs'

-- Butler ships games to itch.io. The binary and the *channel* are config;
-- the itch user/API key are the operator's own `butler login` session and
-- are never stored here.
M.butler = {
    binary = 'butler',
    default_channel = 'linux',
}

---@type Love2dConfig
local config = M

return config
