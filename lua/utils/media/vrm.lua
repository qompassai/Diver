local M = {}
local api = vim.api
local fn = vim.fn
local notify = vim.notify
local uv = vim.uv or vim.loop
local levels = vim.log.levels
local sep = package.config:sub(1, 1)
local xdg_config = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local xdg_data = vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")
local xdg_state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
M.config_root = xdg_config .. "/nvim/lua/utils/media"
M.projects_root = xdg_data .. "/vrm"
M.state_root = xdg_state .. "/vrm"
local function join(...)
	return table.concat({ ... }, sep)
end
local function exists(path)
	local stat = uv.fs_stat(path)
	return stat ~= nil
end

local function is_dir(path)
	local stat = uv.fs_stat(path)
	return stat and stat.type == "directory" or false
end

local function mkdirp(path)
	fn.mkdir(path, "p")
end
local function write_file(path, lines)
	fn.writefile(lines, path)
end
local function read_template(name)
	local path = join(M.config_root, "templates", name)
	if fn.filereadable(path) == 1 then
		return fn.readfile(path)
	end
	return nil
end
local function project_paths(name)
	local root = join(M.projects_root, name)
	return {
		name = name,
		root = root,
		exports = join(root, "exports"),
		textures = join(root, "textures"),
		texture_source = join(root, "textures", "source"),
		texture_guides = join(root, "textures", "guides"),
		texture_exports = join(root, "textures", "exports"),
		blender = join(root, "blender"),
		unity = join(root, "unity"),
		docs = join(root, "docs"),
		scripts = join(root, "scripts"),
		notes = join(root, "docs", "notes.md"),
		checklist = join(root, "docs", "export-checklist.md"),
		readme = join(root, "README.md"),
		manifest = join(root, "vrm.json"),
		versions = join(root, "versions"),
	}
end
M.projects_root = join(xdg_data, "vrm")
function M.project(name)
	local root = join(M.projects_root, name)
	return {
		name = name,
		root = root,
		exports = join(root, "exports"),
		docs = join(root, "docs"),
		notes = join(root, "docs", "notes.md"),
		checklist = join(root, "docs", "export-checklist.md"),
		manifest = join(root, "vrm.json"),
		versions = join(root, "versions"),
	}
end

function M.get_project_name()
	local cwd = fn.getcwd()
	if cwd:find(vim.pesc(M.projects_root), 1, false) == 1 then
		local rel = cwd:gsub("^" .. vim.pesc(M.projects_root) .. sep .. "?", "")
		return rel:match("([^" .. sep .. "]+)")
	end
	return nil
end

function M.current_project()
	local name = M.get_project_name()
	if name then
		return project_paths(name)
	end
	return nil
end

function M.ensure_templates()
	mkdirp(join(M.config_root, "templates"))
	mkdirp(join(M.config_root, "scripts"))
end

function M.bootstrap()
	M.ensure_templates()
	local checklist = read_template("export-checklist.md")
	if not checklist then
		write_file(join(M.config_root, "templates", "export-checklist.md"), {
			"# VRM export checklist",
			"",
			"- [ ] Save source model changes in VRoid/Blender.",
			"- [ ] Export VRM or copy latest VRM into exports/.",
			"- [ ] Verify textures and transparency.",
			"- [ ] Verify blendshapes / expressions.",
			"- [ ] Test import target (Blender/Unity/VRChat/VSeeFace).",
			"- [ ] Archive version in versions/.",
			"- [ ] Update docs/notes.md.",
		})
	end
	if fn.filereadable(join(M.config_root, "templates", "README.md")) == 0 then
		write_file(join(M.config_root, "templates", "README.md"), {
			"# {{name}}",
			"",
			"## Purpose",
			"",
			"- Avatar/project notes.",
			"",
			"## Targets",
			"",
			"- [ ] Blender",
			"- [ ] Unity",
			"- [ ] VRChat",
			"- [ ] VSeeFace",
			"",
			"## Notes",
			"",
		})
	end

	if fn.filereadable(join(M.config_root, "templates", "vrm.json")) == 0 then
		write_file(join(M.config_root, "templates", "vrm.json"), {
			"{",
			'  "name": "{{name}}",',
			'  "primary_vrm": "exports/{{name}}.vrm",',
			'  "targets": ["blender", "unity"],',
			'  "notes": "docs/notes.md"',
			"}",
		})
	end
end

local function render(lines, vars)
	local out = {}
	for _, line in ipairs(lines) do
		local s = line
		for k, v in pairs(vars) do
			s = s:gsub("{{" .. k .. "}}", v)
		end
		out[#out + 1] = s
	end
	return out
end
function M.create_project(name)
	if not name or name == "" then
		notify("VRM project name required", levels.ERROR)
		return
	end
	M.bootstrap()
	local p = project_paths(name)

	for _, dir in ipairs({
		p.root,
		p.exports,
		p.textures,
		p.texture_source,
		p.texture_guides,
		p.texture_exports,
		p.blender,
		p.unity,
		p.docs,
		p.scripts,
		p.versions,
	}) do
		mkdirp(dir)
	end
	local vars = {
		name = name,
	}
	if fn.filereadable(p.readme) == 0 then
		write_file(p.readme, render(read_template("README.md") or { "# {{name}}" }, vars))
	end
	if fn.filereadable(p.checklist) == 0 then
		write_file(p.checklist, read_template("export-checklist.md") or { "# VRM export checklist" })
	end
	if fn.filereadable(p.notes) == 0 then
		write_file(p.notes, {
			"# Notes",
			"",
			"## " .. os.date("%Y-%m-%d"),
			"",
			"- Created project.",
		})
	end
	if fn.filereadable(p.manifest) == 0 then
		write_file(p.manifest, render(read_template("vrm.json") or { "{}" }, vars))
	end
	notify("Created VRM project: " .. p.root, levels.INFO)
	vim.cmd("edit " .. fn.fnameescape(p.readme))
end

function M.open_project(name)
	local p = project_paths(name)
	if not is_dir(p.root) then
		notify("VRM project not found: " .. p.root, levels.ERROR)
		return
	end
	vim.cmd("edit " .. fn.fnameescape(p.readme))
end

function M.open_notes(name)
	local p = name and project_paths(name) or M.current_project()
	if not p then
		notify("Not inside a VRM project and no name was provided", levels.ERROR)
		return
	end
	vim.cmd("edit " .. fn.fnameescape(p.notes))
end

function M.open_checklist(name)
	local p = name and project_paths(name) or M.current_project()
	if not p then
		notify("Not inside a VRM project and no name was provided", levels.ERROR)
		return
	end
	vim.cmd("edit " .. fn.fnameescape(p.checklist))
end

function M.open_exports(name)
	local p = name and project_paths(name) or M.current_project()
	if not p then
		notify("Not inside a VRM project and no name was provided", levels.ERROR)
		return
	end
	vim.cmd("edit " .. fn.fnameescape(p.exports))
end

function M.append_note(text)
	local p = M.current_project()
	if not p then
		notify("Not inside a VRM project", levels.ERROR)
		return
	end
	if not text or text == "" then
		notify("Note text required", levels.ERROR)
		return
	end
	fn.writefile({ "", "## " .. os.date("%Y-%m-%d %H:%M"), "", "- " .. text }, p.notes, "a")
	notify("Appended note to " .. p.notes, levels.INFO)
end

function M.backup_current_vrm(name)
	local p = name and project_paths(name) or M.current_project()
	if not p then
		notify("Not inside a VRM project and no name was provided", levels.ERROR)
		return
	end

	local vrm = join(p.exports, p.name .. ".vrm")
	if not exists(vrm) then
		notify("Primary VRM not found: " .. vrm, levels.ERROR)
		return
	end

	local stamp = os.date("%Y%m%d-%H%M%S")
	local dest = join(p.versions, p.name .. "-" .. stamp .. ".vrm")
	local ok = vim.uv.fs_copyfile(vrm, dest)
	if not ok then
		notify("Failed to back up VRM to " .. dest, levels.ERROR)
		return
	end
	notify("Backed up VRM to " .. dest, levels.INFO)
end

function M.package_project(name)
	local p = name and project_paths(name) or M.current_project()
	if not p then
		notify("Not inside a VRM project and no name was provided", levels.ERROR)
		return
	end

	mkdirp(M.state_root)
	local out = join(M.state_root, p.name .. "-" .. os.date("%Y%m%d-%H%M%S") .. ".zip")
	local cmd = { "zip", "-r", out, p.root }
	vim.system(cmd, { text = true }, function(obj)
		vim.schedule(function()
			if obj.code == 0 then
				notify("Packaged VRM project: " .. out, levels.INFO)
			else
				notify("Package failed: " .. (obj.stderr or obj.stdout or "unknown error"), levels.ERROR)
			end
		end)
	end)
end

function M.list_projects()
	if fn.isdirectory(M.projects_root) == 0 then
		notify("VRM projects root does not exist: " .. M.projects_root, levels.WARN)
		return
	end

	local items = {}
	for _, entry in ipairs(fn.readdir(M.projects_root)) do
		local path = join(M.projects_root, entry)
		if fn.isdirectory(path) == 1 then
			items[#items + 1] = entry
		end
	end
	table.sort(items)
	vim.ui.select(items, { prompt = "VRM project" }, function(choice)
		if choice then
			M.open_project(choice)
		end
	end)
end

function M.setup(opts)
	opts = opts or {}
	if opts.projects_root then
		M.projects_root = opts.projects_root
	end
	if opts.state_root then
		M.state_root = opts.state_root
	end
	if opts.config_root then
		M.config_root = opts.config_root
	end

	M.bootstrap()

	api.nvim_create_user_command("VrmNew", function(command_opts)
		local name = command_opts.args
		if name == "" then
			vim.ui.input({ prompt = "New VRM project name: " }, function(input)
				if input and input ~= "" then
					M.create_project(input)
				end
			end)
		else
			M.create_project(name)
		end
	end, { nargs = "?", desc = "Create a new VRM project" })

	api.nvim_create_user_command("VrmOpen", function(command_opts)
		local name = command_opts.args
		if name == "" then
			M.list_projects()
		else
			M.open_project(name)
		end
	end, { nargs = "?", desc = "Open a VRM project" })

	api.nvim_create_user_command("VrmNotes", function(command_opts)
		local name = command_opts.args
		M.open_notes(name ~= "" and name or nil)
	end, { nargs = "?", desc = "Open VRM project notes" })

	api.nvim_create_user_command("VrmChecklist", function(command_opts)
		local name = command_opts.args
		M.open_checklist(name ~= "" and name or nil)
	end, { nargs = "?", desc = "Open VRM project checklist" })

	api.nvim_create_user_command("VrmExports", function(command_opts)
		local name = command_opts.args
		M.open_exports(name ~= "" and name or nil)
	end, {
		nargs = "?",
		desc = "Open VRM exports directory",
	})

	api.nvim_create_user_command("VrmNote", function(command_opts)
		M.append_note(command_opts.args)
	end, { nargs = 1, desc = "Append note to current VRM project" })

	api.nvim_create_user_command("VrmBackup", function(command_opts)
		local name = command_opts.args
		M.backup_current_vrm(name ~= "" and name or nil)
	end, {
		nargs = "?",
		desc = "Backup the current project VRM file",
	})

	api.nvim_create_user_command("VrmPackage", function(command_opts)
		local name = command_opts.args
		M.package_project(name ~= "" and name or nil)
	end, {
		nargs = "?",
		desc = "Package a VRM project as zip",
	})
end

return M
