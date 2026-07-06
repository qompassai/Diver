#!/usr/bin/env lua5.1 JIT
-- /qompassai/Diver/lua/utils/docs/init.lua
-- Qompass AI Docs Utils Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
require('utils.docs.bounty')
require('utils.docs.clipboard')
require('utils.docs.docs').setup()
require('utils.docs.mime')
require('utils.docs.license').setup()
return M