-- #################################################################
-- /qompassai/Diver/lua/utils/games/aseprite/config.lua
-- Qompass AI Aseprite Config
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

---@alias AsepriteAlphaRange
---| 0 # EIGHT_BIT
---| 1 # PERCENTAGE

---@alias AsepriteBrushPreview
---| 0 # NONE
---| 1 # EDGES
---| 2 # FULL
---| 3 # FULLALL
---| 4 # FULLNEDGES

---@alias AsepriteBrushType
---| 0 # CIRCLE
---| 1 # SQUARE
---| 2 # LINE

---@alias AsepriteCelContentFormat
---| 0 # COMPRESSED
---| 1 # KEEP_AS_IS
---| 2 # RAW_IMAGE

---@alias AsepriteCelsTarget
---| 'selected' # CelsTarget::Selected

---@alias AsepriteColorMode
---| 0 # doc::ColorMode::RGB

---@alias AsepriteColorProfileBehavior
---| 0 # DISABLE
---| 1 # EMBEDDED
---| 2 # CONVERT
---| 3 # ASSIGN
---| 4 # ASK

---@alias AsepriteColorSelector
---| 'tint_shade_tone' # app::ColorBar::ColorSelector::TINT_SHADE_TONE

---@alias AsepriteDocumentEnumDefault
---| 'default' # Upstream C++ enum DEFAULT value

---@alias AsepriteDownsampling
---| 0 # NEAREST
---| 1 # BILINEAR
---| 2 # BILINEAR_MIPMAP
---| 3 # TRILINEAR_MIPMAP

---@alias AsepriteEyedropperChannel
---| 0 # COLOR_ALPHA
---| 1 # COLOR
---| 2 # ALPHA
---| 3 # RGBA
---| 4 # RGB
---| 5 # HSVA
---| 6 # HSV
---| 7 # HSLA
---| 8 # HSL
---| 9 # GRAYA
---| 10 # GRAY
---| 11 # INDEX

---@alias AsepriteEyedropperSample
---| 0 # ALL_LAYERS
---| 1 # CURRENT_LAYER
---| 2 # FIRST_REFERENCE_LAYER

---@alias AsepriteHueSaturationMode
---| 'hsl_mul' # filters::HueSaturationFilter::Mode::HSL_MUL

---@alias AsepritePaintingCursorType
---| 0 # SIMPLE_CROSSHAIR
---| 1 # CROSSHAIR_ON_SPRITE
---| 2 # CROSSHAIR_ON_SPRITE_WITHOUT_UI_SCALE

---@alias AsepritePivotPosition
---| 0 # NORTHWEST
---| 1 # NORTH
---| 2 # NORTHEAST
---| 3 # WEST
---| 4 # CENTER
---| 5 # EAST
---| 6 # SOUTHWEST
---| 7 # SOUTH
---| 8 # SOUTHEAST

---@alias AsepriteRightClickMode
---| 0 # PAINT_BGCOLOR
---| 1 # PICK_FGCOLOR
---| 2 # ERASE
---| 3 # SCROLL
---| 4 # RECTANGULAR_MARQUEE
---| 5 # LASSO
---| 6 # SELECT_LAYER_AND_MOVE

---@alias AsepriteSelectionMode
---| 0 # REPLACE
---| 1 # ADD
---| 2 # SUBTRACT
---| 3 # INTERSECT

---@alias AsepriteSequenceDecision
---| 0 # ASK
---| 1 # YES
---| 2 # NO

---@alias AsepriteSheetType
---| 'packed'
---| 'rows'
---| 'columns'
---| 'horizontal'
---| 'vertical'

---@alias AsepriteTileMode
---| 'auto' # app::TilesetMode::Auto

---@alias AsepriteTimelinePosition
---| 0 # BOTTOM
---| 1 # LEFT
---| 2 # RIGHT

---@alias AsepriteToGrayAlgorithm
---| 0 # LUMA
---| 1 # HSV
---| 2 # HSL

---@alias AsepriteWindowColorProfile
---| 0 # MONITOR
---| 1 # SRGB
---| 2 # SPECIFIC

---@class AsepriteColor
---@field r integer Red channel, 0 through 255
---@field g integer Green channel, 0 through 255
---@field b integer Blue channel, 0 through 255
---@field a integer Alpha channel, 0 through 255

---@class AsepriteFontInfo
---@field file string Font file or face name
---@field size integer Font size
---@field weight integer Font weight

---@class AsepriteAdvancedModePreferences
---@field show_alert? boolean

---@class AsepriteAsepriteFormatPreferences
---@field cel_format? AsepriteCelContentFormat

---@class AsepriteBrushPreferences
---@field pattern? AsepriteDocumentEnumDefault

---@class AsepriteCanvasSizePreferences
---@field trim_outside? boolean

---@class AsepriteCelsPreferences
---@field user_data_visibility? boolean

---@class AsepriteColorBarPreferences
---@field bg_color? AsepriteColor
---@field bg_tile? integer Normally omit for doc::notile
---@field box_size? integer
---@field default_tileset_mode? AsepriteTileMode
---@field discrete_wheel? boolean
---@field entries_separator? boolean
---@field fg_color? AsepriteColor
---@field fg_tile? integer Normally omit for doc::notile
---@field harmony? integer
---@field selector? AsepriteColorSelector
---@field show_color_and_tiles? boolean
---@field show_invalid_fg_bg_color_alert? boolean
---@field tiles_box_size? integer
---@field wheel_model? integer

---@class AsepriteColorPreferences
---@field files_with_profile? AsepriteColorProfileBehavior
---@field manage? boolean
---@field missing_profile? AsepriteColorProfileBehavior
---@field window_profile? AsepriteWindowColorProfile
---@field window_profile_name? string Required when window_profile is 2
---@field working_rgb_space? string

---@class AsepriteContextBarPreferences
---@field show_corner_radius? boolean

---@class AsepriteCssPreferences
---@field generate_html? boolean
---@field pixel_scale? integer
---@field show_alert? boolean
---@field with_vars? boolean

---@class AsepriteCursorPreferences
---@field brush_preview? AsepriteBrushPreview
---@field brush_preview_in_preview? boolean
---@field cursor_color? AsepriteColor|string `mask` means app::Color::fromMask()
---@field cursor_scale? integer
---@field painting_cursor_type? AsepritePaintingCursorType
---@field snap_to_grid? boolean
---@field tile_preview? AsepriteBrushPreview
---@field use_native_cursor? boolean

---@class AsepriteEditorPreferences
---@field auto_fit? boolean
---@field auto_scroll? boolean
---@field auto_select_layer? boolean
---@field auto_select_layer_quick? boolean
---@field downsampling? AsepriteDownsampling
---@field invert_brush_size_wheel? boolean
---@field play_all? boolean
---@field play_once? boolean
---@field play_subtags? boolean
---@field right_click_mode? AsepriteRightClickMode
---@field show_scrollbars? boolean
---@field straight_line_preview? boolean
---@field zoom_from_center_with_keys? boolean
---@field zoom_from_center_with_wheel? boolean
---@field zoom_with_slide? boolean
---@field zoom_with_wheel? boolean

---@class AsepriteExperimentalPreferences
---@field compose_groups? boolean
---@field flash_layer? boolean
---@field hue_with_sat_value_for_color_selector? boolean
---@field load_wintab_driver? boolean
---@field multiple_windows? boolean
---@field new_blend? boolean
---@field new_render_engine? boolean
---@field nonactive_layers_opacity? integer Range: 0 through 255
---@field nonactive_layers_opacity_preview? integer Range: 0 through 255
---@field one_finger_as_mouse_movement? boolean
---@field tooltip_delay? integer Milliseconds
---@field use_native_clipboard? boolean
---@field use_native_file_dialog? boolean
---@field use_selection_tool_loop? boolean
---@field use_shaders_for_color_selectors? boolean

---@class AsepriteExportFilePreferences
---@field animation_default_extension? string
---@field image_default_extension? string
---@field show_overwrite_files_alert? boolean

---@class AsepriteEyedropperPreferences
---@field channel? AsepriteEyedropperChannel
---@field discard_brush? boolean
---@field sample? AsepriteEyedropperSample

---@class AsepriteFileSelectorPreferences
---@field current_folder? string
---@field show_hidden? boolean
---@field zoom? number

---@class AsepriteFiltersPreferences
---@field cels_target? AsepriteCelsTarget

---@class AsepriteGeneralPreferences
---@field autoshow_timeline? boolean
---@field data_recovery? boolean
---@field data_recovery_period? number
---@field edit_full_path? boolean
---@field expand_menubar_on_mouseover? boolean
---@field gpu_acceleration? boolean
---@field keep_closed_sprite_on_memory? boolean
---@field keep_closed_sprite_on_memory_for? number
---@field keep_edited_sprite_data? boolean
---@field keep_edited_sprite_data_for? integer
---@field language? string
---@field osx_async_view? boolean macOS-specific asynchronous view toggle
---@field recent_items? integer
---@field rewind_on_stop? boolean
---@field screen_scale? integer Zero selects automatic platform scaling
---@field show_full_path? boolean
---@field show_home? boolean
---@field show_menu_bar? boolean
---@field timeline_layer_panel_width? integer
---@field timeline_position? AsepriteTimelinePosition
---@field ui_scale? integer
---@field visible_timeline? boolean
---@field workspace_layout? string
---@field x11_stylus_id? string Linux/X11 stylus device identifier

---@class AsepriteGifPreferences
---@field interlaced? boolean
---@field loop? boolean
---@field preserve_palette_order? boolean
---@field show_alert? boolean

---@class AsepriteGridPreferences
---@field snap? boolean

---@class AsepriteGuidesPreferences
---@field auto_guides_color? AsepriteColor
---@field layer_edges_color? AsepriteColor

---@class AsepriteHueSaturationPreferences
---@field mode? AsepriteHueSaturationMode

---@class AsepriteJpegPreferences
---@field quality? number
---@field show_alert? boolean

---@class AsepriteLayersPreferences
---@field user_data_visibility? boolean

---@class AsepriteNewFilePreferences
---@field advanced? boolean
---@field background_color? integer
---@field color_mode? AsepriteColorMode
---@field height? integer
---@field pixel_ratio? string
---@field width? integer

---@class AsepriteNewsPreferences
---@field cache_file? string

---@class AsepriteOpenFilePreferences
---@field open_sequence? AsepriteSequenceDecision

---@class AsepritePerformancePreferences
---@field show_render_time? boolean

---@class AsepritePlaybackPreferences
---@field play_all? boolean
---@field play_once? boolean
---@field play_subtags? boolean

---@class AsepriteQuantizationPreferences
---@field advanced? boolean
---@field dithering_algorithm? string
---@field dithering_factor? integer
---@field fit_criteria? AsepriteDocumentEnumDefault
---@field rgbmap_algorithm? AsepriteDocumentEnumDefault
---@field to_gray? AsepriteToGrayAlgorithm
---@field with_alpha? boolean

---@class AsepriteRangePreferences
---@field alpha? AsepriteAlphaRange
---@field opacity? AsepriteAlphaRange

---@class AsepriteSaveBrushPreferences
---@field bg_color? boolean
---@field brush_angle? boolean
---@field brush_size? boolean
---@field brush_type? boolean
---@field fg_color? boolean
---@field image_color? boolean
---@field ink_opacity? boolean
---@field ink_type? boolean
---@field pixel_perfect? boolean
---@field shade? boolean

---@class AsepriteSaveFilePreferences
---@field default_extension? string
---@field show_export_animation_in_sequence_alert? boolean
---@field show_file_format_doesnt_support_alert? boolean

---@class AsepriteScriptsPreferences
---@field show_run_script_alert? boolean

---@class AsepriteSelectionPreferences
---@field auto_opaque? boolean
---@field auto_show_selection_edges? boolean
---@field doubleclick_select_tile? boolean
---@field force_rotsprite? boolean
---@field keep_selection_after_clear? boolean
---@field mode? AsepriteSelectionMode
---@field modifiers_disable_handles? boolean
---@field modify_selection_brush? AsepriteBrushType
---@field modify_selection_quantity? integer
---@field move_edges? boolean
---@field move_on_add_mode? boolean
---@field multicel_when_layers_or_frames? boolean
---@field opaque? boolean
---@field pivot_position? AsepritePivotPosition
---@field pivot_visibility? boolean
---@field rotation_algorithm? AsepriteDocumentEnumDefault
---@field snap_to_grid? boolean
---@field transparent_color? AsepriteColor|string `mask` means transparent color

---@class AsepriteSharedPreferences
---@field ink? AsepriteDocumentEnumDefault
---@field share_dynamics? boolean
---@field share_ink? boolean

---@class AsepriteSlicesPreferences
---@field default_color? AsepriteColor
---@field use_keys? boolean
---@field user_data_visibility? boolean

---@class AsepriteSpritePreferences
---@field user_data_visibility? boolean

---@class AsepriteSpriteSheetPreferences
---@field default_extension? string
---@field preview? boolean
---@field sections? string
---@field show_overwrite_files_alert? boolean

---@class AsepriteStatusBarPreferences
---@field focus_frame_field_on_mouseover? boolean

---@class AsepriteSvgPreferences
---@field pixel_scale? integer
---@field show_alert? boolean

---@class AsepriteSymmetryModePreferences
---@field enabled? boolean

---@class AsepriteTabletPreferences
---@field api? string
---@field set_cursor_fix? boolean

---@class AsepriteTagsPreferences
---@field user_data_visibility? boolean

---@class AsepriteTextToolPreferences
---@field antialias? boolean
---@field font_face? string
---@field font_info? AsepriteFontInfo|string Serialized INI font descriptor
---@field font_size? integer

---@class AsepriteTgaPreferences
---@field bits_per_pixel? integer
---@field compress? boolean
---@field show_alert? boolean

---@class AsepriteThemePreferences
---@field font? string
---@field mini_font? string
---@field selected? string

---@class AsepriteTilemapPreferences
---@field show_delete_unused_tileset_alert? boolean

---@class AsepriteTilesetPreferences
---@field advanced? boolean
---@field base_index? integer
---@field cache_compressed_tilesets? boolean

---@class AsepriteTimelinePreferences
---@field drag_and_drop_from_edges? boolean
---@field keep_selection? boolean
---@field select_on_click? boolean
---@field select_on_click_with_key? boolean
---@field select_on_drag? boolean

---@class AsepriteUndoPreferences
---@field allow_nonlinear_history? boolean
---@field goto_modified? boolean
---@field show_tooltip? boolean
---@field size_limit? integer Zero is unlimited/default

---@class AsepriteUpdaterPreferences
---@field current_version? string
---@field exits? integer
---@field inits? integer
---@field is_developer? boolean
---@field last_check? integer
---@field new_url? string
---@field new_version? string
---@field uuid? string Runtime-generated identifier; normally omit
---@field wait_days? number

---@class AsepriteWebpPreferences
---@field compression? integer
---@field image_hint? integer
---@field image_preset? integer
---@field loop? boolean
---@field quality? integer
---@field show_alert? boolean
---@field type? integer

---@class AsepritePreferences
---@field advanced_mode? AsepriteAdvancedModePreferences
---@field aseprite_format? AsepriteAsepriteFormatPreferences
---@field brush? AsepriteBrushPreferences
---@field canvas_size? AsepriteCanvasSizePreferences
---@field cels? AsepriteCelsPreferences
---@field color? AsepriteColorPreferences
---@field color_bar? AsepriteColorBarPreferences
---@field context_bar? AsepriteContextBarPreferences
---@field css? AsepriteCssPreferences
---@field cursor? AsepriteCursorPreferences
---@field editor? AsepriteEditorPreferences
---@field experimental? AsepriteExperimentalPreferences
---@field export_file? AsepriteExportFilePreferences
---@field eyedropper? AsepriteEyedropperPreferences
---@field file_selector? AsepriteFileSelectorPreferences
---@field filters? AsepriteFiltersPreferences
---@field general? AsepriteGeneralPreferences
---@field gif? AsepriteGifPreferences
---@field grid? AsepriteGridPreferences
---@field guides? AsepriteGuidesPreferences
---@field hue_saturation? AsepriteHueSaturationPreferences
---@field jpeg? AsepriteJpegPreferences
---@field layers? AsepriteLayersPreferences
---@field new_file? AsepriteNewFilePreferences
---@field news? AsepriteNewsPreferences
---@field open_file? AsepriteOpenFilePreferences
---@field perf? AsepritePerformancePreferences
---@field preview? AsepritePlaybackPreferences
---@field quantization? AsepriteQuantizationPreferences
---@field range? AsepriteRangePreferences
---@field save_brush? AsepriteSaveBrushPreferences
---@field save_file? AsepriteSaveFilePreferences
---@field scripts? AsepriteScriptsPreferences
---@field selection? AsepriteSelectionPreferences
---@field shared? AsepriteSharedPreferences
---@field slices? AsepriteSlicesPreferences
---@field sprite? AsepriteSpritePreferences
---@field sprite_sheet? AsepriteSpriteSheetPreferences
---@field status_bar? AsepriteStatusBarPreferences
---@field svg? AsepriteSvgPreferences
---@field symmetry_mode? AsepriteSymmetryModePreferences
---@field tablet? AsepriteTabletPreferences
---@field tags? AsepriteTagsPreferences
---@field text_tool? AsepriteTextToolPreferences
---@field tga? AsepriteTgaPreferences
---@field theme? AsepriteThemePreferences
---@field tilemap? AsepriteTilemapPreferences
---@field tileset? AsepriteTilesetPreferences
---@field timeline? AsepriteTimelinePreferences
---@field undo? AsepriteUndoPreferences
---@field updater? AsepriteUpdaterPreferences
---@field webp? AsepriteWebpPreferences

---@class AsepriteWindowFrame
---@field x? integer
---@field y? integer
---@field width? integer
---@field height? integer

---@class AsepriteGfxModeRuntime
---@field frame? AsepriteWindowFrame
---@field maximized? boolean

---@class AsepriteLayoutRuntime
---@field bg_color? integer
---@field fg_color? integer
---@field palette_spectrum_splitter? integer

---@class AsepriteMiniEditorRuntime
---@field enabled? boolean

---@class AsepriteRuntime
---@field gfx_mode? AsepriteGfxModeRuntime
---@field layout? AsepriteLayoutRuntime
---@field mini_editor? AsepriteMiniEditorRuntime
---@field recent_files_enabled? boolean
---@field recent_paths_enabled? boolean

---@class AsepritePaletteDirectories
---@field linux? string
---@field mac? string
---@field windows? string

---@class AsepriteConfig
---@field binaries? string[]
---@field env_names? string[]
---@field group_order? string[]
---@field output_filetype? string
---@field preferences? AsepritePreferences
---@field runtime? AsepriteRuntime
---@field sheet_types? AsepriteSheetType[]
---@field sprite_extensions? string[]
---@field user_palette_dir_by_os? AsepritePaletteDirectories

---@type AsepriteConfig
local M = {}

M.binaries = {
  'aseprite',
  'Aseprite',
}

M.env_names = {
  'ASEPRITE_BIN',
  'NVIM_ASEPRITE_BIN',
}

M.group_order = {
  'Editor',
  'Export',
  'Palette',
  'Scripting',
}

M.output_filetype = 'aseprite-output'

M.sheet_types = {
  'packed',
  'rows',
  'columns',
  'horizontal',
  'vertical',
}

M.sprite_extensions = {
  '.ase',
  '.aseprite',
}
M.user_palette_dir_by_os = {
  linux = (vim.fn.expand('$HOME') or '') .. '/.config/aseprite/palettes',
  mac = (vim.fn.expand('$HOME') or '') .. '/Library/Application Support/Aseprite/palettes',
  windows = (vim.fn.expand('$APPDATA') or '') .. '/Aseprite/palettes',
}
---@type AsepritePreferences
M.preferences = {
  advanced_mode = {
    show_alert = false,
  },
  aseprite_format = {
    cel_format = 0,
  },
  brush = {
    pattern = 'default',
  },
  canvas_size = {
    trim_outside = false,
  },
  cels = {
    user_data_visibility = false,
  },
  color = {
    files_with_profile = 1,
    manage = true,
    missing_profile = 3,
    window_profile = 0,
    working_rgb_space = 'sRGB',
  },
  color_bar = {
    bg_color = {
      r = 0,
      g = 0,
      b = 0,
      a = 255,
    },
    box_size = 11,
    default_tileset_mode = 'auto',
    discrete_wheel = false,
    entries_separator = true,
    fg_color = { r = 255, g = 255, b = 255, a = 255 },
    harmony = 0,
    selector = 'tint_shade_tone',
    show_color_and_tiles = true,
    show_invalid_fg_bg_color_alert = true,
    tiles_box_size = 16,
    wheel_model = 0,
  },

  context_bar = {
    show_corner_radius = false,
  },

  css = {
    generate_html = false,
    pixel_scale = 1,
    show_alert = true,
    with_vars = false,
  },

  cursor = {
    brush_preview = 2,
    brush_preview_in_preview = false,
    cursor_color = 'mask',
    cursor_scale = 1,
    painting_cursor_type = 1,
    snap_to_grid = false,
    tile_preview = 2,
    use_native_cursor = false,
  },

  editor = {
    auto_fit = false,
    auto_scroll = true,
    auto_select_layer = false,
    auto_select_layer_quick = true,
    downsampling = 0,
    invert_brush_size_wheel = false,
    play_all = false,
    play_once = false,
    play_subtags = true,
    right_click_mode = 0,
    show_scrollbars = true,
    straight_line_preview = true,
    zoom_from_center_with_keys = false,
    zoom_from_center_with_wheel = false,
    zoom_with_slide = false,
    zoom_with_wheel = true,
  },
  experimental = {
    compose_groups = false,
    flash_layer = false,
    hue_with_sat_value_for_color_selector = false,
    load_wintab_driver = false,
    multiple_windows = false,
    new_blend = true,
    new_render_engine = true,
    nonactive_layers_opacity = 255,
    nonactive_layers_opacity_preview = 255,
    one_finger_as_mouse_movement = true,
    tooltip_delay = 300,
    use_native_clipboard = true,
    use_native_file_dialog = true,
    use_selection_tool_loop = false,
    use_shaders_for_color_selectors = true,
  },
  export_file = {
    animation_default_extension = 'gif',
    image_default_extension = 'png',
    show_overwrite_files_alert = true,
  },
  eyedropper = {
    channel = 0,
    discard_brush = false,
    sample = 0,
  },

  file_selector = {
    show_hidden = true,
    zoom = 1.0,
  },

  filters = {
    cels_target = 'selected',
  },
  general = {
    autoshow_timeline = true,
    data_recovery = true,
    data_recovery_period = 2.0,
    edit_full_path = false,
    expand_menubar_on_mouseover = false,
    gpu_acceleration = false,
    keep_closed_sprite_on_memory = true,
    keep_closed_sprite_on_memory_for = 15.0,
    keep_edited_sprite_data = true,
    keep_edited_sprite_data_for = 7,
    language = 'en',
    recent_items = 24,
    rewind_on_stop = false,
    screen_scale = 2,
    show_full_path = true,
    show_home = true,
    show_menu_bar = true,
    timeline_layer_panel_width = 160,
    timeline_position = 0,
    ui_scale = 1,
    visible_timeline = true,
    workspace_layout = '_default_',
  },

  gif = {
    interlaced = false,
    loop = true,
    preserve_palette_order = true,
    show_alert = true,
  },

  grid = {
    snap = false,
  },

  guides = {
    auto_guides_color = { r = 0, g = 0, b = 255, a = 128 },
    layer_edges_color = { r = 0, g = 0, b = 255, a = 255 },
  },

  hue_saturation = {
    mode = 'hsl_mul',
  },

  jpeg = {
    quality = 1.0,
    show_alert = true,
  },

  layers = {
    user_data_visibility = false,
  },

  new_file = {
    advanced = false,
    background_color = 0,
    color_mode = 0,
    height = 32,
    width = 32,
  },

  open_file = {
    open_sequence = 0,
  },

  perf = {
    show_render_time = false,
  },

  preview = {
    play_all = false,
    play_once = false,
    play_subtags = true,
  },

  quantization = {
    advanced = false,
    dithering_factor = 100,
    fit_criteria = 'default',
    rgbmap_algorithm = 'default',
    to_gray = 0,
    with_alpha = true,
  },

  range = {
    alpha = 0,
    opacity = 1,
  },

  save_brush = {
    bg_color = false,
    brush_angle = true,
    brush_size = true,
    brush_type = true,
    fg_color = false,
    image_color = true,
    ink_opacity = true,
    ink_type = true,
    pixel_perfect = false,
    shade = true,
  },

  save_file = {
    default_extension = 'aseprite',
    show_export_animation_in_sequence_alert = true,
    show_file_format_doesnt_support_alert = true,
  },

  scripts = {
    show_run_script_alert = true,
  },

  selection = {
    auto_opaque = true,
    auto_show_selection_edges = true,
    doubleclick_select_tile = true,
    force_rotsprite = false,
    keep_selection_after_clear = false,
    mode = 0,
    modifiers_disable_handles = true,
    modify_selection_brush = 0,
    modify_selection_quantity = 1,
    move_edges = true,
    move_on_add_mode = true,
    multicel_when_layers_or_frames = true,
    opaque = false,
    pivot_position = 4,
    pivot_visibility = false,
    rotation_algorithm = 'default',
    snap_to_grid = true,
    transparent_color = 'mask',
  },

  shared = {
    ink = 'default',
    share_dynamics = true,
    share_ink = false,
  },

  slices = {
    default_color = { r = 0, g = 0, b = 255, a = 255 },
    use_keys = false,
    user_data_visibility = false,
  },

  sprite = {
    user_data_visibility = false,
  },

  sprite_sheet = {
    default_extension = 'png',
    preview = true,
    show_overwrite_files_alert = true,
  },

  status_bar = {
    focus_frame_field_on_mouseover = false,
  },

  svg = {
    pixel_scale = 1,
    show_alert = true,
  },

  symmetry_mode = {
    enabled = false,
  },

  tablet = {
    set_cursor_fix = true,
  },

  tags = {
    user_data_visibility = false,
  },

  text_tool = {
    antialias = false,
    font_info = {
      file = 'Aseprite',
      size = 7,
      weight = 400,
    },
    font_size = 12,
  },

  tga = {
    bits_per_pixel = 0,
    compress = true,
    show_alert = true,
  },

  theme = {
    selected = 'default',
  },

  tilemap = {
    show_delete_unused_tileset_alert = true,
  },

  tileset = {
    advanced = false,
    base_index = 1,
    cache_compressed_tilesets = true,
  },

  timeline = {
    drag_and_drop_from_edges = true,
    keep_selection = false,
    select_on_click = true,
    select_on_click_with_key = true,
    select_on_drag = true,
  },

  undo = {
    allow_nonlinear_history = false,
    goto_modified = true,
    show_tooltip = true,
    size_limit = 0,
  },

  webp = {
    compression = 6,
    image_hint = 0,
    image_preset = 0,
    loop = true,
    quality = 100,
    show_alert = true,
    type = 0,
  },
}

---@type AsepriteRuntime
M.runtime = {
  gfx_mode = {
    frame = {
      x = 8733,
      y = 354,
      width = 1792,
      height = 1072,
    },
    maximized = false,
  },

  layout = {
    bg_color = 0,
    fg_color = 0,
    palette_spectrum_splitter = 80,
  },

  mini_editor = {
    enabled = true,
  },

  recent_files_enabled = true,
  recent_paths_enabled = true,
}
return M
