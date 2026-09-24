-- vim: ft=lua tw=80
-- Diver project luacheck config.
-- Loaded for files under this repo (nearest .luacheckrc wins; this takes
-- precedence over the global ~/.config/luacheck/.luacheckrc fallback).
-- Every option below is set to its documented default (luacheck 0.26.0),
-- in alphabetical order, except where noted.

allow_defined = false
allow_defined_top = false
cache = false
codes = false
color = true
compat = false
enable = {}
exclude_files = {}
formatter = "default"
global = true
globals = {}
ignore = {}
-- include_files is intentionally unset: assigning {} would exclude every
-- file; leaving it unset keeps the default "include all files".
jobs = 1
max_code_line_length = 80
max_comment_line_length = 80
max_cyclomatic_complexity = false
max_line_length = 80
max_string_line_length = 80
module = false
-- new_globals is intentionally unset: assigning it would wipe and replace
-- the allowed-globals set; unset keeps "do not overwrite".
-- new_read_globals is intentionally unset: same reason as new_globals.
not_globals = {}
-- only is intentionally unset: assigning {} would filter out every warning;
-- unset keeps the default "do not filter".
quiet = 0
ranges = false
-- "files" is declared because luacheck's luacheckrc std does not
-- list it; without this, the files["..."] override below warns as
-- undefined global when this file is itself linted.
read_globals = {
  "files",
  "vim",
}
redefined = true
self = false
std = "max"
unused = true
unused_args = true
unused_secondaries = true

-- Explicit version of luacheck's built-in "**/*.luacheckrc" -> "+luacheckrc"
-- detection. The builtin only fires when luacheck sees the real filename;
-- editor integrations that pipe via stdin bypass it, and --std on the CLI
-- wipes the defaults. This keeps the config file itself warning-free.
files["**/.luacheckrc"] = { std = "+luacheckrc" }
