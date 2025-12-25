-- vim.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@module 'types.core.vim'
---@class vim.fs
---@field basename fun(file: string|nil): string|nil
---@field dirname fun(file: string|nil): string|nil
---@field abspath fun(path: string): string
---@field normalize fun(path: string, opts?: { expand_env?: boolean, win?: boolean }): string
---@field joinpath fun(...: string): string
---@field find fun(
---  names: string|string[]|fun(name: string, path: string): boolean,
---  opts: { path?: string, upward?: boolean, stop?: string, type?: string, limit?: number, follow?: boolean }|nil)
---): string[]
---@field parents fun(start: string): (fun(_, dir: string): string|nil), nil, string|nil
---@field relpath fun(base: string, target: string, opts?: table): string|nil
---@field rm fun(path: string, opts?: { recursive?: boolean, force?: boolean }): nil
vim.fs = vim.fs or {}

---@class VimNativeAPI
---@field nvim_create_augroup fun(name: string, opts: table): integer
---@field nvim_create_autocmd fun(event: any, opts: table)
---@field nvim_get_runtime_file fun(pattern: string, all: boolean): string[]
---@field nvim_set_option_value fun(name: string, value: any, opts: table)

---@type VimNativeAPI
vim.api = vim.api
---@class vim.fn
---@field executable fun(name: string): boolean
---@field expand fun(path: string): string
---@field has fun(feature: string): boolean
---@field stdpath fun(what: string): string
---@class vim.uv
---@field available_parallelism fun(): integer