#!/usr/bin/env lua5.1

-- /qompassai/Diver/lua/config/ui/image.lua
-- Qompass AI Diver Native Image Module
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------------------
local M = {}

local api = vim.api
local fn = vim.fn
local uv = vim.uv

---@class ImagePlacement
---@field id integer|nil
---@field key string
---@field opts table
---@field path string
---@field serial integer
---@field temp_path string|nil

---@class ImagePreview
---@field buf integer|nil
---@field enabled boolean
---@field path string|nil
---@field win integer|nil

M.config = {
	allow_cli_fallback = true,
	convert_non_png = true,
	prefer_luamagick = true,
	preview = {
		border = 'rounded',
		height_ratio = 0.70,
		title = ' Image Preview ',
		width_ratio = 0.32,
		zindex = 60,
	},
}

M.state = {
	notified = {},
	placements = {},
	preview = {
		buf = nil,
		enabled = false,
		path = nil,
		win = nil,
	},
	serial = 0,
}

local luamagick_checked = false
---@type table|nil
local luamagick_module = nil

local native_extensions = {
	png = true,
}

local convertible_extensions = {
	avif = true,
	gif = true,
	jpeg = true,
	jpg = true,
	svg = true,
	webp = true,
}

---@param message string
---@param level integer
---@param key string
local function notify_once(message, level, key)
	if M.state.notified[key] then
		return
	end

	M.state.notified[key] = true
	vim.notify(message, level, {
		title = 'Native image preview',
	})
end

---@return boolean
function M.is_available()
	return type(vim.ui) == 'table'
		and type(vim.ui.img) == 'table'
		and type(vim.ui.img.set) == 'function'
		and type(vim.ui.img.get) == 'function'
		and type(vim.ui.img.del) == 'function'
end

---@param path string
---@return string|nil
local function extension(path)
	return path:lower():match('%.([%w]+)$')
end

---@param path string|nil
---@return boolean
function M.is_image(path)
	if not path or path == '' then
		return false
	end

	local ext = extension(path)
	return ext ~= nil and (native_extensions[ext] == true or convertible_extensions[ext] == true)
end

---@param path string
---@return boolean
local function is_remote(path)
	return path:match('^https?://') ~= nil or path:match('^data:') ~= nil
end

---@param path string
---@return string
local function normalize_path(path)
	local expanded = fn.expand(path)
	if type(expanded) ~= 'string' or expanded == '' then
		return path
	end
	local absolute = fn.fnamemodify(expanded, ':p')
	if type(absolute) ~= 'string' or absolute == '' then
		return expanded
	end
	return vim.fs.normalize(absolute)
end

---@param path string
---@return boolean
local function is_readable_file(path)
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == 'file' and fn.filereadable(path) == 1
end

---@return table|nil
local function get_luamagick()
	if luamagick_checked then
		return luamagick_module
	end

	luamagick_checked = true
	if not M.config.prefer_luamagick then
		return nil
	end

	local ok, module = pcall(require, 'magick')
	if ok and type(module) == 'table' and type(module.load_image) == 'function' then
		luamagick_module = module
	end

	return luamagick_module
end

---@param path string
---@return boolean
function M.can_render(path)
	if not M.is_available() or is_remote(path) or not M.is_image(path) then
		return false
	end

	local ext = extension(path)
	if ext and native_extensions[ext] then
		return true
	end

	return M.config.convert_non_png
		and (get_luamagick() ~= nil or (M.config.allow_cli_fallback and fn.executable('magick') == 1))
end

---@param path string|nil
local function delete_temp(path)
	if path and path ~= '' then
		pcall(fn.delete, path)
	end
end

---@param path string
---@return any|nil
---@return string|nil
local function read_image_data(path)
	local ok, data = pcall(fn.readblob, path)
	if not ok then
		return nil, 'Unable to read image: ' .. path
	end
	return data, nil
end

---@param module table
---@param source string
---@param temp_path string
---@return boolean
---@return string|nil
local function convert_with_luamagick(module, source, temp_path)
	local load_ok, loaded = pcall(module.load_image, source)
	if not load_ok or loaded == nil then
		return false, 'LuaMagick could not load: ' .. source
	end

	local write_ok, write_result = pcall(function()
		if type(loaded.auto_orient) == 'function' then
			loaded:auto_orient()
		end
		if type(loaded.strip) == 'function' then
			loaded:strip()
		end
		loaded:set_format('png')
		return loaded:write(temp_path)
	end)
	pcall(function()
		loaded:destroy()
	end)
	if not write_ok or write_result == false or not is_readable_file(temp_path) then
		delete_temp(temp_path)
		return false, 'LuaMagick could not create a PNG preview'
	end
	return true, nil
end

---@param path string
---@param callback fun(data: any|nil, temp_path: string|nil, error_message: string|nil)
local function prepare_png(path, callback)
	local ext = extension(path)
	if ext and native_extensions[ext] then
		local data, read_error = read_image_data(path)
		if data == nil then
			callback(nil, nil, read_error)
			return
		end

		callback(data, nil, nil)
		return
	end

	if not M.config.convert_non_png then
		callback(nil, nil, 'Neovim 0.13 renders PNG natively; conversion is disabled for: ' .. path)
		return
	end

	local temp_path = fn.tempname() .. '.png'
	local source = path
	if ext == 'gif' then
		source = path .. '[0]'
	end

	local module = get_luamagick()
	if module then
		local converted, conversion_error = convert_with_luamagick(module, source, temp_path)
		if converted then
			local data, read_error = read_image_data(temp_path)
			if data ~= nil then
				callback(data, temp_path, nil)
				return
			end
			delete_temp(temp_path)
			callback(nil, nil, read_error)
			return
		end
		if not M.config.allow_cli_fallback then
			callback(nil, nil, conversion_error)
			return
		end
	end
	if not M.config.allow_cli_fallback or fn.executable('magick') ~= 1 then
		callback(nil, nil, 'Install the LuaMagick rock or enable the ImageMagick CLI fallback')
		return
	end

	vim.system({
		'magick',
		source,
		'-auto-orient',
		'-strip',
		'png:' .. temp_path,
	}, {
		text = true,
	}, function(result)
		vim.schedule(function()
			if result.code ~= 0 or not is_readable_file(temp_path) then
				delete_temp(temp_path)
				local reason = vim.trim(result.stderr or '')
				if reason == '' then
					reason = 'ImageMagick conversion failed'
				end
				callback(nil, nil, reason)
				return
			end

			local data, read_error = read_image_data(temp_path)
			if data == nil then
				delete_temp(temp_path)
				callback(nil, nil, read_error)
				return
			end

			callback(data, temp_path, nil)
		end)
	end)
end

---@param key string
function M.remove(key)
	---@type ImagePlacement|nil
	local placement = M.state.placements[key]
	if not placement then
		return
	end

	M.state.placements[key] = nil

	if placement.id and M.is_available() then
		pcall(vim.ui.img.del, placement.id)
	end

	delete_temp(placement.temp_path)
end

---@param prefix string
function M.clear_prefix(prefix)
	local keys = {}
	for key in pairs(M.state.placements) do
		if key:sub(1, #prefix) == prefix then
			keys[#keys + 1] = key
		end
	end

	for _, key in ipairs(keys) do
		M.remove(key)
	end
end

---@param prefix string
---@param retained table<string, boolean>
function M.retain_prefix(prefix, retained)
	local keys = {}
	for key in pairs(M.state.placements) do
		if key:sub(1, #prefix) == prefix and not retained[key] then
			keys[#keys + 1] = key
		end
	end

	for _, key in ipairs(keys) do
		M.remove(key)
	end
end

---@param key string
---@param path string
---@param opts table
---@return integer|nil
function M.place(key, path, opts)
	if not M.is_available() then
		notify_once(
			'vim.ui.img is unavailable; use a Neovim 0.13 build with native image support',
			vim.log.levels.WARN,
			'backend'
		)
		return nil
	end

	if is_remote(path) then
		notify_once('Remote Markdown images are not fetched automatically', vim.log.levels.INFO, 'remote')
		return nil
	end

	path = normalize_path(path)
	if not M.is_image(path) or not is_readable_file(path) then
		return nil
	end

	---@type ImagePlacement|nil
	local existing = M.state.placements[key]
	if existing and existing.path == path then
		existing.opts = vim.deepcopy(opts)
		if existing.id then
			pcall(vim.ui.img.set, existing.id, existing.opts)
		end
		return existing.id
	end

	M.remove(key)
	M.state.serial = M.state.serial + 1

	---@type ImagePlacement
	local placement = {
		id = nil,
		key = key,
		opts = vim.deepcopy(opts),
		path = path,
		serial = M.state.serial,
		temp_path = nil,
	}
	M.state.placements[key] = placement

	prepare_png(path, function(data, temp_path, error_message)
		if M.state.placements[key] ~= placement then
			delete_temp(temp_path)
			return
		end

		if error_message or data == nil then
			M.state.placements[key] = nil
			delete_temp(temp_path)
			notify_once(
				error_message or ('Unable to prepare image: ' .. path),
				vim.log.levels.ERROR,
				'prepare:' .. path
			)
			return
		end

		local ok, image_id = pcall(vim.ui.img.set, data, placement.opts)
		if not ok or type(image_id) ~= 'number' then
			M.state.placements[key] = nil
			delete_temp(temp_path)
			notify_once('Native image display failed for: ' .. path, vim.log.levels.ERROR, 'display:' .. path)
			return
		end

		placement.id = image_id
		placement.temp_path = temp_path
	end)

	return placement.id
end

local function clear_all()
	local keys = {}
	for key in pairs(M.state.placements) do
		keys[#keys + 1] = key
	end

	for _, key in ipairs(keys) do
		M.remove(key)
	end
end

---@return string|nil
local function current_image_path()
	local path = api.nvim_buf_get_name(0)
	if path == '' or not M.is_image(path) then
		return nil
	end
	return normalize_path(path)
end

---@return integer
---@return integer
local function preview_dimensions()
	local width = math.max(10, math.floor(vim.o.columns * M.config.preview.width_ratio))
	local available_height = math.max(5, vim.o.lines - vim.o.cmdheight - 2)
	local height = math.max(5, math.floor(available_height * M.config.preview.height_ratio))
	return width, height
end

---@return integer
local function ensure_preview_window()
	---@type ImagePreview
	local preview = M.state.preview
	if preview.win and api.nvim_win_is_valid(preview.win) then
		return preview.win
	end
	local width, height = preview_dimensions()
	preview.buf = api.nvim_create_buf(false, true)
	api.nvim_set_option_value('bufhidden', 'wipe', {
		buf = preview.buf,
	})
	preview.win = api.nvim_open_win(preview.buf, false, {
		border = M.config.preview.border,
		col = vim.o.columns - width - 2,
		focusable = false,
		height = height,
		relative = 'editor',
		row = 1,
		style = 'minimal',
		title = M.config.preview.title,
		title_pos = 'center',
		width = width,
		zindex = M.config.preview.zindex,
	})
	api.nvim_set_option_value('winblend', 0, {
		win = preview.win,
	})
	api.nvim_set_option_value('winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder', {
		win = preview.win,
	})

	return preview.win
end
---@param path string|nil
function M.preview(path)
	path = path or current_image_path()
	if not path or not M.is_image(path) then
		vim.notify('No supported image path was provided', vim.log.levels.WARN, {
			title = 'Native image preview',
		})
		return
	end

	if is_remote(path) then
		notify_once('Remote images are not fetched automatically', vim.log.levels.INFO, 'remote')
		return
	end
	path = normalize_path(path)
	---@type integer
	local win = ensure_preview_window()
	local position = api.nvim_win_get_position(win)
	local width = api.nvim_win_get_width(win)
	local height = api.nvim_win_get_height(win)
	M.state.preview.enabled = true
	M.state.preview.path = path
	M.place('preview', path, {
		col = position[2] + 2,
		height = height,
		row = position[1] + 2,
		width = width,
		zindex = M.config.preview.zindex + 1,
	})
end
M.render = M.preview
---@param preserve_path boolean|nil
function M.close_preview(preserve_path)
	M.remove('preview')
	local preview = M.state.preview
	if preview.win and api.nvim_win_is_valid(preview.win) then
		pcall(api.nvim_win_close, preview.win, true)
	end
	preview.buf = nil
	preview.enabled = false
	preview.win = nil
	if not preserve_path then
		preview.path = nil
	end
end
---@param path string|nil
function M.toggle(path)
	if M.state.preview.enabled then
		M.close_preview()
		return
	end
	M.preview(path)
end
function M.refresh()
	local path = M.state.preview.path or current_image_path()
	if not path then
		return
	end
	M.close_preview(true)
	M.preview(path)
end
function M.setup()
	local group = api.nvim_create_augroup('NativeImages', {
		clear = true,
	})
	api.nvim_create_user_command('ImagePreview', function(args)
		local path = args.args ~= '' and args.args or nil
		M.preview(path)
	end, {
		complete = 'file',
		force = true,
		nargs = '?',
	})
	api.nvim_create_user_command('ImagePreviewToggle', function(args)
		local path = args.args ~= '' and args.args or nil
		M.toggle(path)
	end, {
		complete = 'file',
		force = true,
		nargs = '?',
	})
	api.nvim_create_user_command('ImagePreviewRefresh', M.refresh, {
		force = true,
	})
	api.nvim_create_user_command('ImagePreviewClose', function()
		M.close_preview()
	end, {
		force = true,
	})
	api.nvim_create_autocmd('VimResized', {
		callback = function()
			if M.state.preview.enabled then
				M.refresh()
			end
		end,
		group = group,
	})
	api.nvim_create_autocmd('VimLeavePre', {
		callback = clear_all,
		group = group,
	})
end
M.setup()
return M
