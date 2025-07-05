-- /qompassai/Diver/lua/types/lang/cmp.lua
-- Qompass AI Diver CMP Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-------------------------------------------------------------------
---@meta

---@class CmpConfigModule
---@field blink_cmp fun(): BlinkCmpConfig
---@field nvim_cmp fun(): nil

---@class BlinkCmpConfig
---@field keymap table
---@field appearance BlinkCmpAppearance
---@field completion BlinkCmpCompletion
---@field snippets table
---@field sources BlinkCmpSources
---@field cmdline? table
---@field fuzzy? BlinkCmpFuzzy

---@class BlinkCmpAppearance
---@field nerd_font_variant string
---@field kind_icons table<string, string>

---@class BlinkCmpCompletion
---@field documentation BlinkCmpDocumentation

---@class BlinkCmpDocumentation
---@field auto_show boolean

---@class BlinkCmpSources
---@field default string[]
---@field providers table<string, BlinkCmpSourceProvider>

---@class BlinkCmpSourceProvider
---@field name string
---@field enabled boolean
---@field module string
---@field min_keyword_length? integer
---@field max_items? integer
---@field score_offset? integer
---@field fallbacks? string[]
---@field opts? table

---@class BlinkCmpFuzzy
---@field use_typo_resistance? boolean
---@field use_frecency? boolean
---@field use_proximity? boolean
