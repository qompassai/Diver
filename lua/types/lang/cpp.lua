#!/usr/bin/env lua

-- /qompassai/Diver/lua/types/lang/cpp.lua
-- Qompass AI CPP Types Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@version 5.1, JIT
---@meta
---@alias CppStandard                                      'c++11'|'c++14'|'c++17'|'c++20'|'c++23'
---@class CppConfig
---@field standard                                         CppStandard
---@field compiler                                         'g++'|'clang++'
---@field flags                                            string[]
---@class CppModule
---@field compile                                          fun(opts?: table): nil
---@field run                                              fun(): nil
---@field debug                                            fun(): nil