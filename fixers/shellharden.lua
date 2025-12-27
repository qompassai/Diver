-- /qompassai/Diver/fixers/shellharden.lua
-- Qompass AI Diver Shellharden Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  cmd = "shellharden",
  stdin = false,
  append_fname = true,
  args = {
    "--transform",
    "--replace",
  },
  stream = nil,
  ignore_exitcode = true,
  env = nil,
}