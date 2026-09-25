-- vim: ft=lua tw=80

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
