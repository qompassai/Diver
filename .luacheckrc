-- #################################################################
-- /qompassai/.luacheckrc
-- Qompass AI Config
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
ignore = {
    "631",  -- line too long
    "212",  -- unused argument
    "214",  -- unused hint
   -- "311",  -- unused variable (often intentional)
   -- "431",  -- shadowing (often intentional in Lua)
}

self = false

globals = {
    "vim",
}

-- lua/types/** are ---@meta LuaCATS stub files for LuaLS; they never execute
-- at runtime (require('types') was removed). They intentionally use the
-- `Foo = Foo` idiom to declare types, so W111 (global declared this way),
-- W113 (reading it back) and W212 (unused stub parameters) are by design.
files["lua/types/**"] = {
    ignore = { "111", "113", "212" },
}
