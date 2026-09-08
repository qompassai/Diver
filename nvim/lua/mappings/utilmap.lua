-- /qompassai/Diver/lua/mappings/utilmap.lua
-- Qompass AI Diver Utility Mappings Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@module 'mappings.utilmap'
local M = {}
local api = vim.api
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, {
		desc = desc,
		silent = true,
	})
end
---@param name string
---@param rhs string|function
---@param desc string
local function create_user_command(name, rhs, desc)
	api.nvim_create_user_command(name, rhs, {
		desc = desc,
		force = true,
	})
end
---@param message string
---@param level? integer
---@param title? string
local function notify(message, level, title)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = title or 'Utility mappings',
	})
end
---@param executable string
---@return boolean
local function require_executable(executable)
	if vim.fn.executable(executable) == 1 then
		return true
	end
	notify(('%s is not available in PATH'):format(executable), vim.log.levels.ERROR)
	return false
end
---@param argv string[]
---@param height? integer
local function open_terminal(argv, height)
	height = height or 14
	vim.cmd(('botright %dsplit'):format(height))
	vim.cmd('enew')
	vim.bo.bufhidden = 'wipe'
	local job_id = vim.fn.jobstart(argv, { term = true })
	if job_id <= 0 then
		notify(('Unable to start terminal job: %s'):format(vim.inspect(argv)), vim.log.levels.ERROR)
		vim.cmd('close')
		return
	end
	vim.cmd('startinsert')
end
---@param group integer
local function setup_terminal_mappings(group)
	map('t', '<Esc>', [[<C-\><C-n>]], 'Terminal: enter Normal mode')
	map('t', '<C-h>', [[<C-\><C-n><C-w>h]], 'Terminal window: move left')
	map('t', '<C-j>', [[<C-\><C-n><C-w>j]], 'Terminal window: move down')
	map('t', '<C-k>', [[<C-\><C-n><C-w>k]], 'Terminal window: move up')
	map('t', '<C-l>', [[<C-\><C-n><C-w>l]], 'Terminal window: move right')
	api.nvim_create_autocmd({
		'TermOpen',
		'BufEnter',
	}, {
		group = group,
		pattern = 'term://*',
		desc = 'Enter Insert mode in terminal buffers',
		callback = function(args)
			if vim.bo[args.buf].buftype == 'terminal' then
				vim.cmd('startinsert')
			end
		end,
	})
	create_user_command('AudioTerm', function()
		open_terminal({ vim.o.shell }, 12)
	end, 'Open a utility shell')
	map('n', '<leader>at', '<cmd>AudioTerm<cr>', 'Audio: open utility terminal')
end
local function setup_quickfix_mappings()
	map('n', '<leader>zo', '<cmd>copen<cr>', 'Quickfix: open')
	map('n', '<leader>zc', '<cmd>cclose<cr>', 'Quickfix: close')
	map('n', '<leader>zn', '<cmd>cnext<cr>', 'Quickfix: next item')
	map('n', '<leader>zp', '<cmd>cprevious<cr>', 'Quickfix: previous item')
	map('n', '<leader>zN', '<cmd>cnewer<cr>', 'Quickfix: newer list')
	map('n', '<leader>zP', '<cmd>colder<cr>', 'Quickfix: older list')
end
local function setup_image_mappings()
	map('n', '<leader>ip', function()
		local ok, image = pcall(require, 'config.image')
		if ok and type(image.toggle) == 'function' then
			image.toggle()
			return
		end
		notify('config.image.toggle() is unavailable', vim.log.levels.ERROR, 'Image mappings')
	end, 'Image: toggle preview')
end
local function setup_audio_commands()
	create_user_command('AudioPreview', 'make preview', 'Build the audio preview target')
	create_user_command('AudioFinal', 'make final', 'Build the final audio target')
	create_user_command('AudioPlay', function()
		if require_executable('mpv') then
			open_terminal({
				'mpv',
				'audio/preview.wav',
			}, 12)
		end
	end, 'Play the audio preview')
	create_user_command('AudioRenderCsound', function()
		if require_executable('csound') then
			open_terminal({
				'csound',
				'-o',
				'audio/csound_layer.wav',
				'csd/texture.csd',
			}, 12)
		end
	end, 'Render the Csound layer')
	map('n', '<leader>av', '<cmd>AudioPreview<cr>', 'Audio: build preview')
	map('n', '<leader>af', '<cmd>AudioFinal<cr>', 'Audio: build final')
	map('n', '<leader>ap', '<cmd>AudioPlay<cr>', 'Audio: play preview')
	map('n', '<leader>ar', '<cmd>AudioRenderCsound<cr>', 'Audio: render Csound layer')
end
local function setup_keymap_picker()
	map('n', '<leader>?', function()
		local ok, fzf = pcall(require, 'fzf-lua')
		if ok and type(fzf.keymaps) == 'function' then
			fzf.keymaps()
			return
		end
		notify('fzf-lua is unavailable', vim.log.levels.ERROR, 'Keymap picker')
	end, 'Mappings: open keymap picker')
end
local function setup_salesforce_commands()
	local function current_file()
		return api.nvim_buf_get_name(0)
	end
	local function current_basename()
		return vim.fn.expand('%:t:r')
	end
	---@param file string
	---@return boolean
	local function is_apex_script(file)
		return file:match('%.apex$') ~= nil
	end
	---@param file string
	---@return boolean
	local function is_apex_metadata(file)
		return file:match('%.cls$') ~= nil or file:match('%.trigger$') ~= nil
	end
	---@param file string
	---@return string?
	local function lwc_bundle_dir(file)
		return file:match('(.*/lwc/[^/]+)')
	end
	local function validate_file_and_cli()
		local file = current_file()
		if file == '' then
			notify('No current file', vim.log.levels.WARN, 'Salesforce')
			return nil
		end
		if not require_executable('sf') then
			return nil
		end
		return file
	end
	create_user_command('SfApexRun', function()
		local file = validate_file_and_cli()
		if file then
			open_terminal({
				'sf',
				'apex',
				'run',
				'--file',
				file,
			})
		end
	end, 'Execute the current anonymous Apex file')
	create_user_command('SfDeployFile', function()
		local file = validate_file_and_cli()
		if file then
			open_terminal({
				'sf',
				'project',
				'deploy',
				'start',
				'--source-dir',
				file,
			})
		end
	end, 'Deploy the current Salesforce file')
	create_user_command('SfRetrieveFile', function()
		local file = validate_file_and_cli()
		if file then
			open_terminal({
				'sf',
				'project',
				'retrieve',
				'start',
				'--source-dir',
				file,
			})
		end
	end, 'Retrieve the current Salesforce file')
	create_user_command('SfTailLog', function()
		if require_executable('sf') then
			open_terminal({
				'sf',
				'apex',
				'tail',
				'log',
				'--color',
			}, 16)
		end
	end, 'Tail Salesforce Apex logs')
	create_user_command('SfOrgOpen', function()
		if not require_executable('sf') then
			return
		end
		vim.system({
			'sf',
			'org',
			'open',
		}, {
			text = true,
		}, function(result)
			if result.code ~= 0 then
				vim.schedule(function()
					notify(vim.trim(result.stderr), vim.log.levels.ERROR, 'Salesforce')
				end)
			end
		end)
	end, 'Open the Salesforce org in a browser')
	create_user_command('SfRunCurrentTestClass', function()
		local file = validate_file_and_cli()
		if file then
			open_terminal({
				'sf',
				'apex',
				'run',
				'test',
				'--tests',
				current_basename(),
				'--synchronous',
				'--result-format',
				'human',
			}, 16)
		end
	end, 'Run the current Apex test class')
	create_user_command('SfSmart', function()
		local file = validate_file_and_cli()
		if not file then
			return
		end
		local filetype = vim.bo.filetype
		if filetype == 'apex' and is_apex_script(file) then
			open_terminal({
				'sf',
				'apex',
				'run',
				'--file',
				file,
			})
			return
		end
		if filetype == 'apex' and is_apex_metadata(file) then
			open_terminal({
				'sf',
				'project',
				'deploy',
				'start',
				'--source-dir',
				file,
			})
			return
		end
		local bundle = lwc_bundle_dir(file) or file:match('(.*/aura/[^/]+)')
		open_terminal({
			'sf',
			'project',
			'deploy',
			'start',
			'--source-dir',
			bundle or file,
		})
	end, 'Run the context-appropriate Salesforce action')
	map('n', '<leader>sa', '<cmd>SfApexRun<cr>', 'Salesforce: run anonymous Apex')
	map('n', '<leader>sd', '<cmd>SfDeployFile<cr>', 'Salesforce: deploy current file')
	map('n', '<leader>sr', '<cmd>SfRetrieveFile<cr>', 'Salesforce: retrieve current file')
	map('n', '<leader>sl', '<cmd>SfTailLog<cr>', 'Salesforce: tail logs')
	map('n', '<leader>so', '<cmd>SfOrgOpen<cr>', 'Salesforce: open org')
	map('n', '<leader>st', '<cmd>SfRunCurrentTestClass<cr>', 'Salesforce: run current test class')
	map('n', '<leader>ss', '<cmd>SfSmart<cr>', 'Salesforce: smart action')
end
local function setup_spell_mappings()
	map('n', '<leader>wa', function()
		local ok, utils = pcall(require, 'utils')
		if ok and utils.spell and type(utils.spell.add_from_dictionary) == 'function' then
			utils.spell.add_from_dictionary()
			return
		end
		notify('utils.spell.add_from_dictionary() is unavailable', vim.log.levels.WARN, 'Spell mappings')
	end, 'Spelling: add from custom dictionary')
	map('n', '<leader>wg', 'zg', 'Spelling: add word under cursor')
end
function M.setup_utilmap()
	if M.configured then
		return
	end
	M.configured = true
	local group = api.nvim_create_augroup('UtilityMappings', {
		clear = true,
	})
	setup_terminal_mappings(group)
	setup_quickfix_mappings()
	setup_image_mappings()
	setup_audio_commands()
	setup_keymap_picker()
	setup_salesforce_commands()
	setup_spell_mappings()
end
return M
