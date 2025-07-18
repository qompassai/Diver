-- /qompassai/Diver/types/md.lua
-- Qompass AI Markdown Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta

---@class API
---@field setup fun(options?: Options)
---@field from_file fun(path: string, options?: ImageOptions): Image|nil
---@field from_url fun(url: string, options?: ImageOptions, callback: fun(image: Image|nil))
---@field clear fun(id?: string)
---@field get_images fun(opts?: { window?: number, buffer?: number, namespace?: string }): Image[]
---@field hijack_buffer fun(path: string, window?: number, buffer?: number, options?: ImageOptions): Image|nil
---@field is_enabled fun(): boolean
---@field enable fun()
---@field disable fun()

---@class State
---@field enabled boolean
---@field backend Backend
---@field options Options
---@field images { [string]: Image }
---@field extmarks_namespace any
---@field remote_cache { [string]: string }
---@field tmp_dir string
---@field disable_decorator_handling boolean
---@field hijacked_win_buf_images { [string]: Image }
---@field processor ImageProcessor

---@class DocumentIntegrationOptions
---@field enabled? boolean
---@field download_remote_images? boolean
---@field clear_in_insert_mode? boolean
---@field only_render_image_at_cursor? boolean
---@field only_render_image_at_cursor_mode? "inline"|"popup"
---@field filetypes? string[]
---@field resolve_image_path? function
---@field floating_windows? boolean

---@alias IntegrationOptions DocumentIntegrationOptions

---@class Options
---@field backend 'kitty'|'ueberzug'
---@field integrations table<string, IntegrationOptions>
---@field max_width? number
---@field max_height? number
---@field max_width_window_percentage? number
---@field max_height_window_percentage? number
---@field scale_factor? number
---@field kitty_method "normal"|"unicode-placeholders"
---@field window_overlap_clear_enabled? boolean
---@field window_overlap_clear_ft_ignore? string[]
---@field editor_only_render_when_focused? boolean
---@field tmux_show_only_in_active_window? boolean
---@field hijack_file_patterns? string[]
---@field processor? string

---@class BackendFeatures
---@field crop boolean

---@class Backend
---@field state State
---@field features BackendFeatures
---@field setup fun(state: State)
---@field render fun(image: Image, x: number, y: number, width?: number, height?: number)
---@field clear fun(id?: string, shallow?: boolean)

---@class ImageGeometry
---@field x? number
---@field y? number
---@field row? number
---@field col? number
---@field width? number
---@field height? number

---@class ImageOptions: ImageGeometry
---@field id? string
---@field window? number
---@field buffer? number
---@field with_virtual_padding? boolean
---@field inline? boolean
---@field namespace? string
---@field max_width_window_percentage? number
---@field max_height_window_percentage? number

---@class ImageBounds
---@field top number
---@field right number
---@field bottom number
---@field left number

---@class MagickRockImage
---@field adaptive_resize fun(self: MagickRockImage, width: number, height: number)
---@field clone fun(self: MagickRockImage): MagickRockImage
---@field composite fun(self: MagickRockImage, source: MagickRockImage, x: number, y: number, operator?: string)
---@field crop fun(self: MagickRockImage, width: number, height: number, x?: number, y?: number)
---@field destroy fun(self: MagickRockImage)
---@field get_format fun(self: MagickRockImage): string
---@field get_height fun(self: MagickRockImage): number
---@field get_width fun(self: MagickRockImage): number
---@field modulate fun(self: MagickRockImage, brightness?: number, saturation?: number, hue?: number)
---@field resize fun(self: MagickRockImage, width: number, height: number)
---@field resize_and_crop fun(self: MagickRockImage, width: number, height: number)
---@field scale fun(self: MagickRockImage, width: number, height: number)
---@field set_format fun(self: MagickRockImage, format: string)
---@field write fun(self: MagickRockImage, path: string)

---@class Image
---@field id string
---@field internal_id number
---@field path string
---@field resized_path string
---@field cropped_path string
---@field original_path string
---@field image_width number
---@field image_height number
---@field max_width_window_percentage? number
---@field max_height_window_percentage? number
---@field window? number
---@field buffer? number
---@field with_virtual_padding? boolean
---@field inline? boolean
---@field geometry ImageGeometry
---@field rendered_geometry ImageGeometry
---@field bounds ImageBounds
---@field is_rendered boolean
---@field resize_hash? string
---@field crop_hash? string
---@field global_state State
---@field render fun(self: Image, geometry?: ImageGeometry)
---@field clear fun(self: Image, shallow?: boolean)
---@field move fun(self: Image, x: number, y: number)
---@field brightness fun(self: Image, brightness: number)
---@field saturation fun(self: Image, saturation: number)
---@field hue fun(self: Image, hue: number)
---@field namespace? string
---@field extmark? { id: number, row: number, col: number }
---@field last_modified? number
---@field has_extmark_moved fun (self:Image): (boolean, number?, number?)
---@field ignore_global_max_size? boolean

---@class ImageProcessor
--- We need to:
--- - get image format
--- - convert non-png images to png
--- - get dimensions
--- - resize
--- - crop
--- - adjust brightness, saturation, hue
---@field get_format fun(path: string): string
---@field convert_to_png fun(path: string, output_path?: string): string
---@field get_dimensions fun(path: string): { width: number, height: number }
---@field resize fun(path: string, width: number, height: number, output_path?: string): string
---@field crop fun(path: string, x: number, y: number, width: number, height: number, output_path?: string): string
---@field brightness fun(path: string, brightness: number, output_path?: string): string
---@field saturation fun(path: string, saturation: number, output_path?: string): string
---@field hue fun(path: string, hue: number, output_path?: string): string

-- wish proper generics were a thing here
---@class IntegrationContext
---@field api API
---@field options IntegrationOptions
---@field state State

---@class Integration
---@field setup? fun(api: API, options: IntegrationOptions, state: State)

---@class Window
---@field id number
---@field buffer number
---@field buffer_filetype string
---@field buffer_is_listed boolean
---@field x number
---@field y number
---@field width number
---@field height number
---@field scroll_x number
---@field scroll_y number
---@field is_visible boolean
---@field is_normal boolean
---@field is_floating boolean
---@field zindex number
---@field rect { top: number, right: number, bottom: number, left: number }
---@field masks { x: number, y: number, width: number, height: number }[]

---@class KittyControlConfig
---@field action "t"|"T"|"p"|"d"|"f"|"c"|"a"|"q"
---@field image_id? string|number
---@field image_number? number
---@field placement_id? string|number
---@field quiet? 0|1|2
---@field transmit_format? 32|24|100
---@field transmit_medium? "d"|"f"|"t"|"s"
---@field transmit_more? 0|1
---@field transmit_width? number
---@field transmit_height? number
---@field transmit_file_size? number
---@field transmit_file_offset? number
---@field transmit_compression? 0|1
---@field display_x? number
---@field display_y? number
---@field display_width? number
---@field display_height? number
---@field display_x_offset? number
---@field display_y_offset? number
---@field display_columns? number
---@field display_rows? number
---@field display_cursor_policy? 0|1
---@field display_virtual_placeholder? 0|1
---@field display_zindex? number
---@field display_delete? "a"|"A"|"i"|"I"|"p"
---@field tty? string
