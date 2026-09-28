-- #################################################################
-- /qompassai/Diver/lua/games/robocode/config.lua
-- Qompass AI Robocode Platform Config
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
-- Central knobs for the Robocode engine module: install-root discovery,
-- the user-owned robot development tree, headless battle defaults, and
-- safety caps. No credentials live here; battles run locally.
--
-- Install layout facts (verified 2026-09-28 against aur/robocode
-- 1.11.1-1 and the upstream 1.11.1 installer, md5 885de2ed788dd0f26f3f080de8bb8f43):
-- the package installs the upstream tree to /opt/robocode, whose launcher
-- script passes "$@" through to robocode.Robocode -- but the PKGBUILD's
-- `sed '/^java/!d'` matches no line of the 1.11.1 script (the java
-- invocation is indented inside an if-block), so /usr/bin/robocode ships
-- as a zero-byte stub. The module therefore launches via `java` from the
-- install root directly and treats a zero-size wrapper as unavailable.

---@class RobocodeConfig
---@field binaries string[] PATH candidates for the robocode launcher wrapper
---@field env_names string[] env vars that override install-root discovery
---@field install_roots string[] default Robocode installation roots
---@field dev_robots_dir string user-owned dir for developed robots (scaffolded + compiled here)
---@field battle_dir string dir where generated .battle specs are written
---@field battle_rounds integer default rounds per generated battle
---@field battle_tps integer turns per second for headless battles
---@field battle_timeout_ms integer max wall-clock for one headless battle
---@field compile_timeout_ms integer max wall-clock for one javac invocation
---@field robots_max integer max robots selectable for one battle
---@field scan_entries_max integer max files scanned during robot discovery
---@field output_lines_max integer max result-file lines shown after a battle
---@field jvm_heap string -Xmx value for the Robocode JVM

---@type RobocodeConfig
local M = {}

M.binaries = {
    'robocode',
}

M.env_names = {
    'ROBOCODE_HOME',
    'NVIM_ROBOCODE_HOME',
}

M.install_roots = {
    '/opt/robocode',
}

M.dev_robots_dir = '~/robocode/robots'
M.battle_dir = '~/robocode/battles'

M.battle_rounds = 10
M.battle_tps = 30
M.battle_timeout_ms = 300000
M.compile_timeout_ms = 60000
M.robots_max = 16
M.scan_entries_max = 500
M.output_lines_max = 40
M.jvm_heap = '512m'

return M
