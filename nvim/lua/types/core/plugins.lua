-- /qompassai/Diver/lua/types/core/plugins.lua
-- Qompass AI Diver Core Plugin Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@alias vim.pack.SpecList vim.pack.Spec[]
---@class             vim.pack.Spec
---@field branch?                                          string
---@field build?                                           string|fun()
---@field cmd?                                             string[]
---@field config?                                          fun()
---@field dependencies?                                    vim.pack.Spec[]
---@field filetypes?                                       string[]
---@field hook?                                            fun(spec: vim.pack.Spec)
---@field event?                                           string[]
---@field init?                                            fun()
---@field opt?                                             boolean
---@field opts?                                            table

---@alias vim.pack.Spec.Config fun()
---@alias vim.pack.Spec.Event string|string[]

---@class                    vim.pack.Spec.Data
---@field config?                                          vim.pack.Spec.Config
---@field event?                                           vim.pack.Spec.Event

---@class                    vim.pack.Spec.Extended: vim.pack.Spec
---@field data?                                             vim.pack.Spec.Data

---@alias vim.pack.Spec.List                                vim.pack.Spec.Extended[]

---@class                    vim.pack.LoadData
---@field path?                                             string
---@field spec?                                             vim.pack.Spec
---@class                    vim.pack.Manager
---@field plugin_specs?                                     vim.pack.Spec.List
---@field augroup?                                          integer
---@field plugin_name?                                      fun(plugin: vim.pack.LoadData): string
---@field notify_error?                                     fun(name: string, err: any)
---@field configure?                                        fun(name: string, config: vim.pack.Spec.Config)
---@field packadd?                                          fun(plugin: vim.pack.LoadData)
---@field activate?                                         fun(plugin: vim.pack.LoadData)
---@field load?                                             fun(plugin: vim.pack.LoadData)
---@field configure_eager_plugins?                          fun()
---@field create_commands?                                  fun()
---@field specs?                                            fun(): vim.pack.Spec.List
---@field bootstrap?                                        fun()

