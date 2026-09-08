#!/usr/bin/env lua
-- /qompassai/Diver/lua/types/utils/vulkan.lua
-- Qompass AI Vulkan Util Types
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@version                  JIT
---@class                    VulkanModule
---@field vulkan_layers_list                               fun(): nil
---@field vulkan_validation_status                         fun(): nil
---@field vulkan_run_with_validation                       fun(cmd: string): nil
---@field nvidia_summary                                   fun(): nil
---@field nvidia_watch                                     fun(interval?: number): nil
---@field dashboard                                        fun(): nil
local M = {}
---@param cmd                                              string
---@return string[]?                                       lines
---@return string?                                         error
function run_cmd(cmd) end

---@param title                                            string
---@param lines                                            string[]
---@param ft?                                              string
function create_scratch(title, lines, ft) end

---@param lines?                                           string[]
---@return string[]                                        layers
function parse_layers_from_vulkaninfo(lines) end

---@param fields                                           string[]
---@return string[]?                                       lines
---@return string?                                         error
function nvidia_smi_query(fields) end

return M