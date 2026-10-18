-- /qompassai/lua/types/ui/image.lua
-- Qompass AI Image
---@meta

---@alias ui.image.Source string
---@alias ui.image.Blob string

---@class ui.image.Options
---@field allow_http? boolean
---@field cache_entry_count_max? integer
---@field debounce_ms? integer
---@field enabled? boolean
---@field image_bytes_max? integer
---@field markdown_filetypes? table<string, boolean>
---@field notify_errors? boolean
---@field pending_request_count_max? integer
---@field preview_height_fraction? number
---@field preview_margin? integer
---@field preview_row? integer
---@field preview_width_fraction? number
---@field preview_zindex? integer

---@class ui.image.Config
---@field allow_http                                       boolean
---@field cache_entry_count_max                            integer
---@field debounce_ms integer
---@field enabled boolean
---@field image_bytes_max integer
---@field markdown_filetypes table<string, boolean>
---@field notify_errors boolean
---@field pending_request_count_max integer
---@field preview_height_fraction number
---@field preview_margin integer
---@field preview_row integer
---@field preview_width_fraction number
---@field preview_zindex integer

---@class ui.image.HttpResponse
---@field body? ui.image.Blob
---@field headers? table<string, string>
---@field status? integer
---@field status_code? integer

---@class ui.image.Handle
---@field clear? fun(self: ui.image.Handle)
---@field delete? fun(self: ui.image.Handle)
---@field show? fun(self: ui.image.Handle, options: table)

---@class ui.image.State
---@field augroup_id? integer
---@field buf? integer
---@field cache table<string, ui.image.Blob>
---@field cache_keys string[]
---@field enabled boolean
---@field generation_id integer
---@field img? ui.image.Handle
---@field path? ui.image.Source
---@field pending_request_count integer
---@field timer? uv.uv_timer_t
---@field win? integer
