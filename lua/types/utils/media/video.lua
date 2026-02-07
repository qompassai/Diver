-- /home/phaedrus/.config/nvim/lua/types/utils/media/video.lua
-- Qompass AI Media Video Types Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@version JIT
---@meta
---@class media.FT_Bitmap
---@field buffer                                           ffi.cdata* Bitmap buffer data
---@field pitch                                            integer Bytes per row
---@field rows                                             integer Height in pixels
---@field width                                            integer Width in pixels

---@class media.FT_FaceRec
---@field glyph                                            media.FT_GlyphSlotRec Glyph slot

---@class media.FT_GlyphSlotRec
---@field bitmap                                           media.FT_Bitmap Bitmap data
---@field bitmap_left                                      integer Left bearing
---@field bitmap_top                                       integer Top bearing

---@class media.BlendParams
---@field b                                                integer Foreground blue
---@field bg_b                                             integer Background blue
---@field bg_g                                             integer Background green
---@field bg_r                                             integer Background red
---@field buffer_ptr                                       any Buffer pointer
---@field cell_h                                           integer Cell height
---@field cell_w                                           integer Cell width
---@field cell_x                                           integer Cell X position
---@field cell_y                                           integer Cell Y position
---@field g                                                integer Foreground green
---@field glyph                                            media.GlyphData Glyph data
---@field height                                           integer Frame height
---@field r                                                integer Foreground red
---@field width                                            integer Frame width

---@class media.Cell
---@field [1]                                              string Character
---@field [2]                                              media.Highlight Highlight attributes

---@class media.FontState
---@field char_height                                      integer Character height in pixels
---@field char_width                                       integer Character width in pixels
---@field face                                             ffi.cdata*? FreeType face handle
---@field lib                                              ffi.cdata*? FreeType library handle

---@class media.FrameData
---@field cells                                            media.Cell[][] Grid of cells [row][col]
---@field height                                           integer Frame height in characters
---@field width                                            integer Frame width in characters

---@class media.GlyphData
---@field data                                             integer[][] Pixel data [y][x] with alpha values 0-255
---@field height                                           integer Glyph height in pixels
---@field left                                             integer Left bearing offset
---@field top                                              integer Top bearing offset
---@field width                                            integer Glyph width in pixels

---@class media.Highlight
---@field background                                       integer? Background color (0xRRGGBB)
---@field bold                                             boolean? Bold text
---@field foreground                                       integer? Foreground color (0xRRGGBB)
---@field italic                                           boolean? Italic text
---@field underline                                        boolean? Underlined text
---@class (exact)                                          media.Options
---@field address                                          string Server address
---@field char_height                                      integer Character height in pixels
---@field char_width                                       integer Character width in pixels
---@field font_path                                        string Path to TTF font file
---@field fps                                              integer Frames per second
---@field kind                                             'ffmpeg'|'x264'|'raw' Encoder type
---@field output                                           string Output file path
---@field use_fontrender                                   boolean Use font rendering

---@class media.RenderBuffer
---@field height                                           integer Buffer height in pixels
---@field ptr                                              ffi.cdata* Buffer pointer
---@field size                                             integer Buffer size in bytes
---@field width                                            integer Buffer width in pixels

---@class media.RGB
---@field b                                                integer Blue component (0-255)
---@field g                                                integer Green component (0-255)
---@field r                                                integer Red component (0-255)

---@class media.State
---@field dispose?                                         fun() Cleanup function
---@field output?                                          string Output file path

---@alias media.Color                                      integer RGB color as 0xRRGGBB
---@alias media.ColorComponent                             integer Color component value (0-255)
---@alias media.FontPath                                   string Absolute path to TrueType font file

local M = {}
local lv = vim.log.levels

local state = {} ---@type media.State

----@type media.Options
local default_config = {
    address = vim.v.servername,
    char__pixel_height = 20,
    char__pixel_width = 10,
    font_path = '/usr/share/fonts/TTF/CaskaydiaCoveNerdFontMono-Bold.ttf',
    fps = 30,
    kind = 'x264',
    output = '/tmp/record.mp4',
    use_fontrender = true,
}

M.start = function(opts)
    if state.dispose then
        vim.notify('Already recording', lv.WARN)
        return
    end
    opts = vim.tbl_deep_extend('force', default_config, opts or {})
    local dispose, err = require('rec.task').dispatch(opts)
    if err then
        vim.notify('Failed to start recorder: ' .. err, lv.ERROR)
        return
    end

    state.dispose = dispose
    state.output = opts.output
    vim.notify('Recording started: ' .. state.output, lv.INFO)
end

---@return string? output The output file path or nil if not recording
M.stop = function()
    if not state.dispose then
        vim.notify('Not recording', lv.WARN)
        return
    end

    state.dispose()
    local output = state.output
    state.dispose = nil
    state.output = nil

    vim.notify('Recording stopped: ' .. output, lv.INFO)
    return output
end

---@param opts? media.Options
---@return string? output The output file path or nil
M.toggle = function(opts)
    return state.dispose and M.stop() or M.start(opts)
end
return M