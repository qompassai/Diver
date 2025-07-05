-- /qompassai/Diver/lua/types/ui/html.lua
-- Qompass AI Diver HTML Config Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta

---@class HtmlCmpConfig
---@field sources table

---@class HtmlNlsConfig
---@type table[]

---@class HtmlLspConfig
---@field on_attach fun(client: any, bufnr: integer)?
---@field capabilities table?

---@class HtmlPreviewConfig
---@field port integer
---@field browser_cmd string
---@field auto_start boolean
---@field refresh_delay integer
---@field allowed_file_types string[]

---@class HtmlConformConfig
---@field formatters_by_ft table<string, string[]>
---@field format_on_save table

---@class HtmlSetupConfig
---@field cmp HtmlCmpConfig
---@field nls HtmlNlsConfig
---@field lsp fun(opts: HtmlLspConfig): nil
---@field treesitter any
---@field lint any
---@field emmet any
---@field preview fun(opts?: HtmlPreviewConfig): nil
---@field conform HtmlConformConfig

