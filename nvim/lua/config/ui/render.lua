-- /qompassai/Diver/lua/config/markdown/render.lua
-- Qompass AI Diver UI Render Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local uv = vim.uv
local image = require('config.ui.image')
local namespace = api.nvim_create_namespace('native_render')
---@alias RenderKind
---| 'css'
---| 'html'
---| 'image'
---| 'latex'
---| 'markdown'
---| 'video'
---@class RenderBuffer
---@field browser_opened boolean
---@field enabled boolean
---@field frame_path string|nil
---@field group_name string
---@field job vim.SystemObj|nil
---@field kind RenderKind
---@field last_static_html string|nil
---@field path string
---@field temp_dir string|nil
---@field token integer
---@field video_busy boolean
---@field video_counter integer
---@field video_time number
---@field video_timer uv.uv_timer_t|nil

M.config = {
	auto_enable = {
		css = false,
		html = false,
		image = false,
		latex = false,
		markdown = false,
		video = false,
	},
	browser_reload_ms = 900,
	debounce_ms = 180,
	latex = {
		zindex = 70,
	},
	video = {
		fps = 2,
		scale_width = 1280,
	},
}
M.state = {
	buffers = {},
	notified = {},
}
local image_extensions = {
	avif = true,
	gif = true,
	jpeg = true,
	jpg = true,
	png = true,
	svg = true,
	webp = true,
}
local video_extensions = {
	avi = true,
	m4v = true,
	mkv = true,
	mov = true,
	mp4 = true,
	mpeg = true,
	mpg = true,
	ogv = true,
	webm = true,
}
local filetype_kinds = {
	css = 'css',
	html = 'html',
	htm = 'html',
	htmx = 'html',
	latex = 'latex',
	less = 'css',
	markdown = 'markdown',
	['markdown.mdx'] = 'markdown',
	mdx = 'markdown',
	plaintex = 'latex',
	sass = 'css',
	scss = 'css',
	tex = 'latex',
	xhtml = 'html',
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
		title = 'Native live renderer',
	})
end

---@param bufnr integer
---@return boolean
local function valid_buffer(bufnr)
	return api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr)
end

---@param path string
---@return string|nil
local function extension(path)
	return path:lower():match('%.([%w]+)$')
end

---@param bufnr integer
---@return string
local function buffer_path(bufnr)
	local path = api.nvim_buf_get_name(bufnr)
	if path == '' then
		return ''
	end

	local absolute = fn.fnamemodify(path, ':p')
	if type(absolute) ~= 'string' then
		return path
	end
	return vim.fs.normalize(absolute)
end

---@param path string
---@return string
local function path_directory(path)
	if path ~= '' then
		local directory = vim.fs.dirname(path)
		if type(directory) == 'string' and directory ~= '' then
			return directory
		end
	end

	local cwd = uv.cwd()
	if type(cwd) == 'string' and cwd ~= '' then
		return cwd
	end
	return '.'
end

---@param path string
---@return string
local function path_name(path)
	local name = fn.fnamemodify(path, ':t')
	if type(name) == 'string' and name ~= '' then
		return name
	end
	return path
end

---@param bufnr integer
---@return RenderKind|nil
local function detect_kind(bufnr)
	local filetype = vim.bo[bufnr].filetype
	---@type RenderKind|nil
	local kind = filetype_kinds[filetype]
	if kind then
		return kind
	end
	local ext = extension(buffer_path(bufnr))
	if ext and image_extensions[ext] then
		return 'image'
	end
	if ext and video_extensions[ext] then
		return 'video'
	end
	if ext == 'htm' or ext == 'html' or ext == 'xhtml' then
		return 'html'
	end
	if ext == 'md' or ext == 'markdown' or ext == 'mdx' then
		return 'markdown'
	end
	if ext == 'css' then
		return 'css'
	end
	if ext == 'tex' then
		return 'latex'
	end
	return nil
end

---@param bufnr integer
---@param kind RenderKind
---@return RenderBuffer
local function ensure_state(bufnr, kind)
	---@type RenderBuffer|nil
	local state = M.state.buffers[bufnr]
	if state then
		state.kind = kind
		state.path = buffer_path(bufnr)
		return state
	end

	state = {
		browser_opened = false,
		enabled = false,
		frame_path = nil,
		group_name = 'RenderBuffer' .. bufnr,
		job = nil,
		kind = kind,
		last_static_html = nil,
		path = buffer_path(bufnr),
		temp_dir = nil,
		token = 0,
		video_busy = false,
		video_counter = 0,
		video_time = 0,
		video_timer = nil,
	}
	M.state.buffers[bufnr] = state
	return state
end

---@param state RenderBuffer
---@return string
local function ensure_temp_dir(state)
	if state.temp_dir and fn.isdirectory(state.temp_dir) == 1 then
		return state.temp_dir
	end

	local directory = fn.tempname()
	fn.mkdir(directory, 'p')
	state.temp_dir = directory
	return directory
end

---@param bufnr integer
---@return string
local function buffer_text(bufnr)
	return table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

---@param path string
---@param content string
---@return boolean
local function write_text(path, content)
	local lines = vim.split(content, '\n', {
		plain = true,
	})
	local ok = pcall(fn.writefile, lines, path)
	return ok
end

---@param value string
---@return string
local function html_escape(value)
	return value:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;'):gsub("'", '&#39;')
end

---@param path string
---@return string
local function base_uri(path)
	local directory = path_directory(path)
	local uri = vim.uri_from_fname(directory)
	if uri:sub(-1) ~= '/' then
		uri = uri .. '/'
	end
	return uri
end

---@param base string
---@return string
local function base_element(base)
	return '<base href="' .. html_escape(base) .. '">'
end

---@return string
local function reload_script()
	return table.concat({
		'<script data-live-reload>',
		'window.setTimeout(function () {',
		'  window.location.reload();',
		'}, ',
		tostring(M.config.browser_reload_ms),
		');',
		'</script>',
	}, '\n')
end

---@param content string
---@param base string
---@param live boolean
---@return string
local function prepare_html_document(content, base, live)
	local addition = base_element(base)
	local lower = content:lower()
	local head_start = lower:find('<head', 1, true)

	if head_start then
		local head_end = content:find('>', head_start, true)
		if head_end then
			content = content:sub(1, head_end) .. '\n' .. addition .. content:sub(head_end + 1)
		end
	else
		content = addition .. '\n' .. content
	end

	if not live then
		return content
	end

	local script = reload_script()
	lower = content:lower()
	local body_end = lower:find('</body>', 1, true)
	if body_end then
		return content:sub(1, body_end - 1) .. script .. '\n' .. content:sub(body_end)
	end

	return content .. '\n' .. script
end

---@param text string
---@return string
local function inline_markdown(text)
	text = html_escape(text)
	text = text:gsub('!%[([^%]]-)%]%(([^%)]+)%)', '<img alt="%1" src="%2">')
	text = text:gsub('%[([^%]]-)%]%(([^%)]+)%)', '<a href="%2">%1</a>')
	text = text:gsub('`([^`]+)`', '<code>%1</code>')
	text = text:gsub('%*%*([^*]+)%*%*', '<strong>%1</strong>')
	text = text:gsub('__([^_]+)__', '<strong>%1</strong>')
	text = text:gsub('%*([^*]+)%*', '<em>%1</em>')
	return text
end

---@param markdown string
---@param title string
---@return string
local function fallback_markdown_html(markdown, title)
	local output = {
		'<!doctype html>',
		'<html>',
		'<head>',
		'<meta charset="utf-8">',
		'<meta name="viewport" content="width=device-width,initial-scale=1">',
		'<title>' .. html_escape(title) .. '</title>',
		'<style>',
		':root { color-scheme: dark; }',
		'body { background:#1a1b26; color:#c0caf5; font:16px/1.6 sans-serif;',
		'       margin:0 auto; max-width:960px; padding:2rem; }',
		'a { color:#7dcfff; }',
		'code,pre { background:#16161e; color:#9ece6a; }',
		'code { padding:.15rem .35rem; }',
		'pre { overflow:auto; padding:1rem; }',
		'img,video { height:auto; max-width:100%; }',
		'blockquote { border-left:4px solid #7aa2f7; margin-left:0;',
		'             padding-left:1rem; color:#a0c4ff; }',
		'</style>',
		'</head>',
		'<body>',
	}
	local in_code = false
	local in_ordered = false
	local in_unordered = false

	local function close_lists()
		if in_unordered then
			output[#output + 1] = '</ul>'
			in_unordered = false
		end
		if in_ordered then
			output[#output + 1] = '</ol>'
			in_ordered = false
		end
	end

	for _, line in
		ipairs(vim.split(markdown, '\n', {
			plain = true,
		}))
	do
		local fence = line:match('^%s*```(.*)$')
		if fence then
			close_lists()
			if in_code then
				output[#output + 1] = '</code></pre>'
			else
				output[#output + 1] = '<pre><code data-language="' .. html_escape(vim.trim(fence)) .. '">'
			end
			in_code = not in_code
		elseif in_code then
			output[#output + 1] = html_escape(line)
		else
			local hashes, heading = line:match('^(#+)%s+(.+)$')
			local ordered = line:match('^%s*%d+[.)]%s+(.+)$')
			local unordered = line:match('^%s*[-+*]%s+(.+)$')
			local quote = line:match('^%s*>%s?(.*)$')

			if hashes and heading and #hashes <= 6 then
				close_lists()
				local level = #hashes
				output[#output + 1] = '<h' .. level .. '>' .. inline_markdown(heading) .. '</h' .. level .. '>'
			elseif ordered then
				if in_unordered then
					output[#output + 1] = '</ul>'
					in_unordered = false
				end
				if not in_ordered then
					output[#output + 1] = '<ol>'
					in_ordered = true
				end
				output[#output + 1] = '<li>' .. inline_markdown(ordered) .. '</li>'
			elseif unordered then
				if in_ordered then
					output[#output + 1] = '</ol>'
					in_ordered = false
				end
				if not in_unordered then
					output[#output + 1] = '<ul>'
					in_unordered = true
				end
				output[#output + 1] = '<li>' .. inline_markdown(unordered) .. '</li>'
			elseif quote then
				close_lists()
				output[#output + 1] = '<blockquote>' .. inline_markdown(quote) .. '</blockquote>'
			elseif line:match('^%s*[-*_][-*_][-*_]+%s*$') then
				close_lists()
				output[#output + 1] = '<hr>'
			elseif line:match('^%s*$') then
				close_lists()
			else
				close_lists()
				output[#output + 1] = '<p>' .. inline_markdown(line) .. '</p>'
			end
		end
	end

	close_lists()
	if in_code then
		output[#output + 1] = '</code></pre>'
	end
	output[#output + 1] = '</body>'
	output[#output + 1] = '</html>'
	return table.concat(output, '\n')
end

---@param css string
---@param title string
---@return string
local function css_preview_html(css, title)
	return table.concat({
		'<!doctype html>',
		'<html>',
		'<head>',
		'<meta charset="utf-8">',
		'<meta name="viewport" content="width=device-width,initial-scale=1">',
		'<title>' .. html_escape(title) .. '</title>',
		'<style>' .. css .. '</style>',
		'</head>',
		'<body>',
		'<main>',
		'<header><h1>CSS live preview</h1></header>',
		'<section>',
		'<h2>Typography and controls</h2>',
		'<p>This document updates while the Neovim buffer changes.</p>',
		'<p><a href="#">Example link</a></p>',
		'<button type="button">Button</button>',
		'<input aria-label="Example input" placeholder="Input">',
		'</section>',
		'<section class="preview-grid">',
		'<article><h3>Card one</h3><p>Example content.</p></article>',
		'<article><h3>Card two</h3><p>Example content.</p></article>',
		'</section>',
		'</main>',
		'</body>',
		'</html>',
	}, '\n')
end

---@param state RenderBuffer
---@param html string
---@param live boolean
local function publish_browser_html(state, html, live)
	local directory = ensure_temp_dir(state)
	local preview_path = vim.fs.joinpath(directory, 'preview.html')
	local static_html = prepare_html_document(html, base_uri(state.path), false)
	state.last_static_html = static_html

	local output = live and prepare_html_document(html, base_uri(state.path), true) or static_html
	if not write_text(preview_path, output) then
		notify_once('Unable to write browser preview', vim.log.levels.ERROR, 'browser-write:' .. state.path)
		return
	end

	if not state.browser_opened then
		local command, error_message = vim.ui.open(preview_path)
		if not command then
			notify_once(
				error_message or 'Unable to open the browser preview',
				vim.log.levels.ERROR,
				'browser-open:' .. state.path
			)
			return
		end
		state.browser_opened = true
	end
end

---@param bufnr integer
---@param state RenderBuffer
local function render_markdown_browser(bufnr, state)
	local content = buffer_text(bufnr)
	local title = path_name(state.path)

	if fn.executable('pandoc') ~= 1 then
		publish_browser_html(state, fallback_markdown_html(content, title), true)
		return
	end

	if state.job then
		pcall(function()
			state.job:kill(15)
		end)
	end

	state.token = state.token + 1
	local token = state.token
	state.job = vim.system({
		'pandoc',
		'--from=gfm',
		'--to=html5',
		'--standalone',
		'--mathml',
		'--metadata',
		'title=' .. title,
	}, {
		stdin = content,
		text = true,
	}, function(result)
		vim.schedule(function()
			if not state.enabled or state.token ~= token then
				return
			end

			if result.code ~= 0 or not result.stdout then
				publish_browser_html(state, fallback_markdown_html(content, title), true)
				return
			end

			publish_browser_html(state, result.stdout, true)
		end)
	end)
end

---@param bufnr integer
local function decorate_markdown(bufnr)
	api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for index, line in ipairs(lines) do
		local row = index - 1
		local hashes = line:match('^(#+)%s+')
		if hashes and #hashes <= 6 then
			api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
				priority = 120,
				virt_text = {
					{
						string.rep('▌', #hashes) .. ' ',
						'@markup.heading.' .. #hashes,
					},
				},
				virt_text_pos = 'overlay',
			})
		end

		local indent, state = line:match('^(%s*)[-+*]%s+%[([ xX])%]')
		if indent and state then
			local checkbox = line:find('%[', #indent + 1)
			if checkbox then
				local checked = state:lower() == 'x'
				api.nvim_buf_set_extmark(bufnr, namespace, row, checkbox - 1, {
					priority = 125,
					virt_text = {
						{
							checked and '☑  ' or '☐  ',
							checked and '@markup.list.checked' or '@markup.list.unchecked',
						},
					},
					virt_text_pos = 'overlay',
				})
			end
		end

		local search_from = 1
		while search_from <= #line do
			local start_col, end_col = line:find('!%[[^%]]*%]%((.-)%)', search_from)
			if not start_col then
				break
			end
			api.nvim_buf_set_extmark(bufnr, namespace, row, start_col - 1, {
				priority = 125,
				virt_text = {
					{
						'󰥶 ',
						'@markup.link.label',
					},
				},
				virt_text_pos = 'overlay',
			})
			search_from = math.max(end_col + 1, search_from + 1)
		end
	end
end

---@param destination string
---@param bufnr integer
---@return string|nil
local function resolve_markdown_image(destination, bufnr)
	destination = vim.trim(destination)
	destination = destination:match('^<([^>]+)>') or destination:match('^([^%s]+)')
	if not destination then
		return nil
	end

	local ok, decoded = pcall(vim.uri_decode, destination)
	if ok then
		destination = decoded
	end

	if destination:match('^https?://') or destination:match('^data:') then
		return nil
	end

	if destination:match('^file://') then
		local uri_ok, local_path = pcall(vim.uri_to_fname, destination)
		if not uri_ok then
			return nil
		end
		destination = local_path
	end

	local is_absolute = destination:sub(1, 1) == '/' or destination:match('^%a:[/\\]') ~= nil
	if not is_absolute then
		local path = buffer_path(bufnr)
		local directory = path_directory(path)
		destination = vim.fs.joinpath(directory, destination)
	end

	return vim.fs.normalize(destination)
end

---@param bufnr integer|nil
function M.preview_markdown_image(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local row = api.nvim_win_get_cursor(0)[1] - 1
	local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
	local destination = line:match('!%[[^%]]*%]%((.-)%)')
	if not destination then
		vim.notify('No Markdown image was found on the cursor line', vim.log.levels.INFO, {
			title = 'Native live renderer',
		})
		return
	end

	local path = resolve_markdown_image(destination, bufnr)
	if not path then
		vim.notify('Only local Markdown images are previewed natively', vim.log.levels.INFO, {
			title = 'Native live renderer',
		})
		return
	end
	image.preview(path)
end

---@param state RenderBuffer
local function cancel_job(state)
	if not state.job then
		return
	end
	pcall(function()
		state.job:kill(15)
	end)
	state.job = nil
end

---@param state RenderBuffer
---@param pdf_path string
---@param token integer
local function render_pdf_page(state, pdf_path, token)
	local directory = ensure_temp_dir(state)
	local png_path = vim.fs.joinpath(directory, 'latex-page.png')

	local command
	if fn.executable('pdftoppm') == 1 then
		command = {
			'pdftoppm',
			'-f',
			'1',
			'-singlefile',
			'-png',
			pdf_path,
			vim.fs.joinpath(directory, 'latex-page'),
		}
	elseif fn.executable('magick') == 1 then
		command = {
			'magick',
			pdf_path .. '[0]',
			'-strip',
			png_path,
		}
	else
		notify_once(
			'Install poppler or ImageMagick to convert the LaTeX PDF to PNG',
			vim.log.levels.ERROR,
			'latex-pdf-converter'
		)
		return
	end

	state.job = vim.system(command, {
		text = true,
	}, function(result)
		vim.schedule(function()
			if not state.enabled or state.token ~= token or result.code ~= 0 or fn.filereadable(png_path) ~= 1 then
				return
			end
			image.preview(png_path)
		end)
	end)
end

---@param bufnr integer
---@param state RenderBuffer
local function render_latex(bufnr, state)
	cancel_job(state)
	state.token = state.token + 1
	local token = state.token
	local directory = ensure_temp_dir(state)
	local source_path = vim.fs.joinpath(directory, 'document.tex')
	local pdf_path = vim.fs.joinpath(directory, 'document.pdf')

	if not write_text(source_path, buffer_text(bufnr)) then
		return
	end

	local command
	if fn.executable('tectonic') == 1 then
		command = {
			'tectonic',
			'--chatter',
			'minimal',
			'--outdir',
			directory,
			source_path,
		}
	elseif fn.executable('latexmk') == 1 then
		command = {
			'latexmk',
			'-pdf',
			'-interaction=nonstopmode',
			'-halt-on-error',
			'-outdir=' .. directory,
			source_path,
		}
	else
		notify_once('Install tectonic or latexmk to render LaTeX', vim.log.levels.ERROR, 'latex-compiler')
		return
	end

	local working_directory = path_directory(state.path)
	state.job = vim.system(command, {
		cwd = working_directory,
		text = true,
	}, function(result)
		vim.schedule(function()
			if not state.enabled or state.token ~= token then
				return
			end
			if result.code ~= 0 or fn.filereadable(pdf_path) ~= 1 then
				notify_once(
					'LaTeX compilation failed; inspect :messages and the source',
					vim.log.levels.WARN,
					'latex-build:' .. state.path
				)
				return
			end
			render_pdf_page(state, pdf_path, token)
		end)
	end)
end

---@param state RenderBuffer
local function stop_video(state)
	if state.video_timer then
		pcall(function()
			state.video_timer:stop()
			state.video_timer:close()
		end)
		state.video_timer = nil
	end
	cancel_job(state)
	state.video_busy = false
	state.video_time = 0
	image.close_preview()
	if state.frame_path then
		pcall(fn.delete, state.frame_path)
		state.frame_path = nil
	end
end

---@param state RenderBuffer
local function render_video_frame(state)
	if not state.enabled or state.kind ~= 'video' or state.video_busy then
		return
	end

	if fn.executable('ffmpeg') ~= 1 then
		notify_once('Install ffmpeg to preview video frames', vim.log.levels.ERROR, 'video-ffmpeg')
		return
	end

	state.video_busy = true
	state.video_counter = state.video_counter + 1
	local directory = ensure_temp_dir(state)
	local frame_path = vim.fs.joinpath(directory, 'video-frame-' .. state.video_counter .. '.png')
	local previous_frame = state.frame_path
	local interval = 1 / math.max(1, M.config.video.fps)

	state.job = vim.system({
		'ffmpeg',
		'-hide_banner',
		'-loglevel',
		'error',
		'-ss',
		string.format('%.3f', state.video_time),
		'-i',
		state.path,
		'-frames:v',
		'1',
		'-vf',
		'scale=' .. M.config.video.scale_width .. ':-2:force_original_aspect_ratio=decrease',
		'-y',
		frame_path,
	}, {
		text = true,
	}, function(result)
		vim.schedule(function()
			state.video_busy = false
			if not state.enabled or state.kind ~= 'video' then
				pcall(fn.delete, frame_path)
				return
			end

			if result.code ~= 0 or fn.filereadable(frame_path) ~= 1 then
				state.video_time = 0
				return
			end

			state.video_time = state.video_time + interval
			state.frame_path = frame_path
			image.preview(frame_path)
			if previous_frame and previous_frame ~= frame_path then
				pcall(fn.delete, previous_frame)
			end
		end)
	end)
end

---@param state RenderBuffer
local function start_video(state)
	stop_video(state)
	state.enabled = true

	---@type integer
	local interval_ms = math.max(250, math.floor(1000 / math.max(1, M.config.video.fps)))
	local timer = uv.new_timer()
	if not timer then
		return
	end
	state.video_timer = timer
	timer:start(0, interval_ms, function()
		vim.schedule(function()
			render_video_frame(state)
		end)
	end)
end

---@param bufnr integer
---@param state RenderBuffer
local function refresh_state(bufnr, state)
	if not state.enabled or not valid_buffer(bufnr) then
		return
	end

	state.path = buffer_path(bufnr)
	if state.kind == 'markdown' then
		decorate_markdown(bufnr)
		render_markdown_browser(bufnr, state)
	elseif state.kind == 'html' then
		publish_browser_html(state, buffer_text(bufnr), true)
	elseif state.kind == 'css' then
		publish_browser_html(state, css_preview_html(buffer_text(bufnr), path_name(state.path)), true)
	elseif state.kind == 'latex' then
		render_latex(bufnr, state)
	elseif state.kind == 'image' then
		image.preview(state.path)
	elseif state.kind == 'video' and not state.video_timer then
		start_video(state)
	end
end

---@param bufnr integer
---@param state RenderBuffer
local function schedule_refresh(bufnr, state)
	state.token = state.token + 1
	local token = state.token
	vim.defer_fn(function()
		if not state.enabled or state.token ~= token then
			return
		end
		refresh_state(bufnr, state)
	end, M.config.debounce_ms)
end

---@param bufnr integer|nil
function M.enable(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	if not valid_buffer(bufnr) then
		return
	end

	local kind = detect_kind(bufnr)
	if not kind then
		vim.notify('The current buffer does not have a supported render format', vim.log.levels.INFO, {
			title = 'Native live renderer',
		})
		return
	end

	local state = ensure_state(bufnr, kind)
	if state.enabled then
		refresh_state(bufnr, state)
		return
	end

	state.enabled = true
	local group = api.nvim_create_augroup(state.group_name, {
		clear = true,
	})
	if kind == 'markdown' or kind == 'html' or kind == 'css' or kind == 'latex' then
		api.nvim_create_autocmd({
			'TextChanged',
			'TextChangedI',
		}, {
			buffer = bufnr,
			callback = function()
				schedule_refresh(bufnr, state)
			end,
			group = group,
		})
	end

	api.nvim_create_autocmd({
		'BufEnter',
		'BufWritePost',
	}, {
		buffer = bufnr,
		callback = function()
			schedule_refresh(bufnr, state)
		end,
		group = group,
	})

	api.nvim_create_autocmd('BufWipeout', {
		buffer = bufnr,
		callback = function()
			M.disable(bufnr)
			if state.temp_dir then
				pcall(fn.delete, state.temp_dir, 'rf')
			end
			M.state.buffers[bufnr] = nil
		end,
		group = group,
		once = true,
	})

	refresh_state(bufnr, state)
end

---@param bufnr integer|nil
function M.disable(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	---@type RenderBuffer|nil
	local state = M.state.buffers[bufnr]
	if not state or not state.enabled then
		return
	end

	state.enabled = false
	state.token = state.token + 1
	cancel_job(state)
	pcall(api.nvim_del_augroup_by_name, state.group_name)
	if valid_buffer(bufnr) then
		api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
	end

	if state.kind == 'video' then
		stop_video(state)
	elseif state.kind == 'latex' or state.kind == 'image' then
		image.close_preview()
	elseif state.last_static_html and state.temp_dir then
		write_text(vim.fs.joinpath(state.temp_dir, 'preview.html'), state.last_static_html)
		state.browser_opened = false
	end
end

---@param bufnr integer|nil
function M.toggle(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	---@type RenderBuffer|nil
	local state = M.state.buffers[bufnr]
	if state and state.enabled then
		M.disable(bufnr)
	else
		M.enable(bufnr)
	end
end

---@param bufnr integer|nil
function M.refresh(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	---@type RenderBuffer|nil
	local state = M.state.buffers[bufnr]
	if not state or not state.enabled then
		M.enable(bufnr)
		return
	end
	refresh_state(bufnr, state)
end

function M.status()
	local bufnr = api.nvim_get_current_buf()
	---@type RenderBuffer|nil
	local state = M.state.buffers[bufnr]
	if not state then
		vim.notify('Renderer: inactive', vim.log.levels.INFO)
		return
	end

	vim.notify(
		'Renderer: ' .. (state.enabled and 'enabled' or 'disabled') .. ' (' .. state.kind .. ')',
		vim.log.levels.INFO
	)
end

local function shutdown()
	local buffers = {}
	for bufnr in pairs(M.state.buffers) do
		buffers[#buffers + 1] = bufnr
	end

	for _, bufnr in ipairs(buffers) do
		---@type RenderBuffer
		local state = M.state.buffers[bufnr]
		M.disable(bufnr)
		if state.temp_dir then
			pcall(fn.delete, state.temp_dir, 'rf')
		end
	end
end

function M.setup()
	local group = api.nvim_create_augroup('NativeRender', {
		clear = true,
	})

	api.nvim_create_autocmd({
		'BufReadPost',
		'FileType',
	}, {
		callback = function(args)
			if not valid_buffer(args.buf) then
				return
			end
			local kind = detect_kind(args.buf)
			if kind and M.config.auto_enable[kind] then
				M.enable(args.buf)
			end
		end,
		group = group,
	})

	api.nvim_create_autocmd('VimLeavePre', {
		callback = shutdown,
		group = group,
	})

	api.nvim_create_user_command('RenderEnable', function()
		M.enable()
	end, {
		force = true,
	})

	api.nvim_create_user_command('RenderDisable', function()
		M.disable()
	end, {
		force = true,
	})

	api.nvim_create_user_command('RenderToggle', function()
		M.toggle()
	end, {
		force = true,
	})

	api.nvim_create_user_command('RenderRefresh', function()
		M.refresh()
	end, {
		force = true,
	})

	api.nvim_create_user_command('RenderStatus', M.status, {
		force = true,
	})

	api.nvim_create_user_command('MarkdownRenderEnable', function()
		M.enable()
	end, {
		force = true,
	})

	api.nvim_create_user_command('MarkdownRenderDisable', function()
		M.disable()
	end, {
		force = true,
	})

	api.nvim_create_user_command('MarkdownRenderToggle', function()
		M.toggle()
	end, {
		force = true,
	})

	api.nvim_create_user_command('MarkdownImagePreview', function()
		M.preview_markdown_image()
	end, {
		force = true,
	})
end

M.setup()

return M
