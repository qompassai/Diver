-- ~/.config/nvim/lua/dap/kotlin.lua
-- Kotlin DAP configuration for Neovim 0.13 built-in vim.debug, no plugins
--
-- Uses fwcd/kotlin-debug-adapter as the preferred adapter.
-- Supports:
-- - Gradle/Maven Kotlin/JVM launch
-- - Main class launch
-- - Current-file-derived main class guess
-- - JDWP attach to an existing JVM process

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "kotlin",
\tcommand = "kotlin-debug-adapter",
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.kotlin" })
end

local function executable(cmd)
\treturn fn.executable(cmd) == 1
end

local function input(prompt, default, completion)
\treturn fn.input(prompt, default or "", completion or "")
end

local function cwd()
\treturn fn.getcwd()
end

local function current_file()
\treturn api.nvim_buf_get_name(0)
end

local function file_exists(path)
\treturn type(path) == "string" and path ~= "" and uv.fs_stat(path) ~= nil
end

local function is_dir(path)
\tlocal stat = uv.fs_stat(path)
\treturn stat and stat.type == "directory" or false
end

local function path_join(...)
\treturn table.concat({ ... }, "/")
end

local function workspace_root()
\tlocal file = current_file()
\tlocal start = file ~= "" and file or cwd()

\tlocal root = vim.fs.root(start, {
\t\t"build.gradle.kts",
\t\t"build.gradle",
\t\t"settings.gradle.kts",
\t\t"settings.gradle",
\t\t"pom.xml",
\t\t".git",
\t})

\treturn root or cwd()
end

local function has_gradle(root)
\treturn file_exists(path_join(root, "build.gradle.kts")) or file_exists(path_join(root, "build.gradle"))
end

local function has_maven(root)
\treturn file_exists(path_join(root, "pom.xml"))
end

local function compiled_output_candidates(root)
\treturn {
\t\tpath_join(root, "build", "classes", "kotlin", "main"),
\t\tpath_join(root, "build", "classes", "java", "main"),
\t\tpath_join(root, "target", "classes", "kotlin", "main"),
\t\tpath_join(root, "target", "classes"),
\t}
end

local function has_compiled_output(root)
\tfor _, path in ipairs(compiled_output_candidates(root)) do
\t\tif is_dir(path) then
\t\t\treturn true
\t\tend
\tend
\treturn false
end

local function ensure_adapter()
\tif executable(M.adapter.command) then
\t\treturn true
\tend

\tnotify(
\t\t("Kotlin DAP adapter not found: %s
Install fwcd/kotlin-debug-adapter and put it in PATH.")
\t\t\t:format(M.adapter.command),
\t\tvim.log.levels.ERROR
\t)
\treturn false
end

local function ensure_project_root()
\tlocal root = workspace_root()
\tif not has_gradle(root) and not has_maven(root) then
\t\tnotify("Kotlin debug requires a Gradle or Maven project root", vim.log.levels.ERROR)
\t\treturn nil
\tend
\treturn root
end

local function ensure_built(root)
\tif has_compiled_output(root) then
\t\treturn true
\tend

\tlocal build_now = input("No compiled Kotlin classes found. Build now? [Y/n]: ", "Y")
\tif build_now:lower() == "n" then
\t\tnotify("Build required before Kotlin debug launch", vim.log.levels.WARN)
\t\treturn false
\tend

\tlocal result
\tif has_gradle(root) then
\t\tif executable("gradle") then
\t\t\tresult = vim.system({ "gradle", "classes" }, { cwd = root, text = true }):wait()
\t\telseif executable("./gradlew") then
\t\t\tresult = vim.system({ "./gradlew", "classes" }, { cwd = root, text = true }):wait()
\t\telseif file_exists(path_join(root, "gradlew")) then
\t\t\tresult = vim.system({ path_join(root, "gradlew"), "classes" }, { cwd = root, text = true }):wait()
\t\tend
\telseif has_maven(root) then
\t\tif executable("mvn") then
\t\t\tresult = vim.system({ "mvn", "-DskipTests", "compile" }, { cwd = root, text = true }):wait()
\t\tend
\tend

\tif not result then
\t\tnotify("No supported build command found for Kotlin project", vim.log.levels.ERROR)
\t\treturn false
\tend

\tif result.code ~= 0 then
\t\tlocal stderr = result.stderr ~= "" and result.stderr or "Kotlin build failed"
\t\tnotify(stderr, vim.log.levels.ERROR)
\t\treturn false
\tend

\treturn has_compiled_output(root)
end

local function prompt_args()
\tlocal raw = input("Args: ", "")
\tif raw == "" then
\t\treturn {}
\tend
\treturn vim.split(raw, "%s+", { trimempty = true })
end

local function prompt_vm_args()
\tlocal raw = input("VM args: ", "")
\tif raw == "" then
\t\treturn {}
\tend
\treturn vim.split(raw, "%s+", { trimempty = true })
end

local function prompt_env()
\tlocal env = {}
\twhile true do
\t\tlocal key = input("Env key (blank to finish): ", "")
\t\tif key == "" then
\t\t\tbreak
\t\tend
\t\tenv[key] = input("Env value for " .. key .. ": ", "")
\tend
\treturn env
end

local function package_name_from_file(file)
\tif file == "" or not file_exists(file) then
\t\treturn nil
\tend

\tfor _, line in ipairs(fn.readfile(file)) do
\t\tlocal pkg = line:match("^%s*package%s+([%w%._]+)")
\t\tif pkg then
\t\t\treturn pkg
\t\tend
\tend

\treturn nil
end

local function class_name_from_file(file)
\tif file == "" then
\t\treturn nil
\tend
\treturn fn.fnamemodify(file, ":t:r")
end

local function guessed_main_class()
\tlocal file = current_file()
\tif file == "" then
\t\treturn nil
\tend

\tlocal cls = class_name_from_file(file)
\tif not cls then
\t\treturn nil
\tend

\tlocal pkg = package_name_from_file(file)
\tif pkg and pkg ~= "" then
\t\treturn pkg .. "." .. cls
\tend

\treturn cls
end

local function choose_main_class()
\tlocal guess = guessed_main_class() or ""
\tlocal main_class = input("Kotlin main class: ", guess)
\tif main_class == "" then
\t\treturn nil
\tend
\treturn main_class
end

local function start(config)
\tif not ensure_adapter() then
\t\treturn
\tend

\tconfig.type = M.adapter.name
\tdebug.start(config)
end

function M.build()
\tlocal root = ensure_project_root()
\tif not root then
\t\treturn
\tend

\tif ensure_built(root) then
\t\tnotify("Kotlin project build complete")
\tend
end

function M.launch_main()
\tlocal root = ensure_project_root()
\tif not root then
\t\treturn
\tend

\tif not ensure_built(root) then
\t\treturn
\tend

\tlocal main_class = choose_main_class()
\tif not main_class then
\t\tnotify("Main class is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Kotlin launch main",
\t\tprojectRoot = root,
\t\tmainClass = main_class,
\t\targs = prompt_args(),
\t\tvmArgs = prompt_vm_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t})
end

function M.launch_current_file()
\tlocal root = ensure_project_root()
\tif not root then
\t\treturn
\tend

\tif not ensure_built(root) then
\t\treturn
\tend

\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Kotlin file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal main_class = guessed_main_class()
\tif not main_class then
\t\tnotify("Could not infer main class from current file", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Kotlin launch current file",
\t\tprojectRoot = root,
\t\tmainClass = main_class,
\t\targs = prompt_args(),
\t\tvmArgs = prompt_vm_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t})
end

function M.launch_prompt()
\tlocal root = ensure_project_root()
\tif not root then
\t\treturn
\tend

\tif not ensure_built(root) then
\t\treturn
\tend

\tlocal main_class = input("Main class: ", "")
\tif main_class == "" then
\t\tnotify("Main class is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Kotlin launch prompt",
\t\tprojectRoot = root,
\t\tmainClass = main_class,
\t\targs = prompt_args(),
\t\tvmArgs = prompt_vm_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t})
end

function M.attach_jdwp()
\tlocal host = input("Host: ", "127.0.0.1")
\tif host == "" then
\t\thost = "127.0.0.1"
\tend

\tlocal port = tonumber(input("Port: ", "5005"))
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tdebug.start({
\t\ttype = "kotlin-jvm",
\t\trequest = "attach",
\t\tname = "Kotlin attach JDWP",
\t\thostName = host,
\t\tport = port,
\t\tcwd = workspace_root(),
\t})
end

function M.gradle_debug_hint()
\tlocal root = workspace_root()
\tlocal lines = {
\t\t"Gradle Kotlin/JVM debug examples:",
\t\t"",
\t\t"./gradlew run --debug-jvm",
\t\t"./gradlew test --debug-jvm",
\t\t"",
\t\t"Then attach with host 127.0.0.1 and port 5005 if your JVM is listening there.",
\t\t"",
\t\t"Project root:",
\t\troot,
\t}

\tvim.cmd("new")
\tlocal buf = api.nvim_get_current_buf()
\tapi.nvim_buf_set_lines(buf, 0, -1, false, lines)
\tvim.bo[buf].bufhidden = "wipe"
\tvim.bo[buf].filetype = "markdown"
end

function M.setup()
\tapi.nvim_create_user_command("KotlinDapBuild", M.build, {
\t\tdesc = "Build Kotlin project classes",
\t})

\tapi.nvim_create_user_command("KotlinDapMain", M.launch_main, {
\t\tdesc = "Debug Kotlin main class",
\t})

\tapi.nvim_create_user_command("KotlinDapFile", M.launch_current_file, {
\t\tdesc = "Debug current Kotlin file as main class",
\t})

\tapi.nvim_create_user_command("KotlinDapPrompt", M.launch_prompt, {
\t\tdesc = "Prompt for Kotlin main class and debug it",
\t})

\tapi.nvim_create_user_command("KotlinDapAttach", M.attach_jdwp, {
\t\tdesc = "Attach to Kotlin/JVM JDWP process",
\t})

\tapi.nvim_create_user_command("KotlinGradleDebugHint", M.gradle_debug_hint, {
\t\tdesc = "Show Gradle debug attach hint",
\t})

\tvim.keymap.set("n", "<leader>kb", M.build, { desc = "Kotlin DAP build" })
\tvim.keymap.set("n", "<leader>km", M.launch_main, { desc = "Kotlin DAP main" })
\tvim.keymap.set("n", "<leader>kf", M.launch_current_file, { desc = "Kotlin DAP file" })
\tvim.keymap.set("n", "<leader>kp", M.launch_prompt, { desc = "Kotlin DAP prompt" })
\tvim.keymap.set("n", "<leader>ka", M.attach_jdwp, { desc = "Kotlin DAP attach" })
\tvim.keymap.set("n", "<leader>kh", M.gradle_debug_hint, { desc = "Kotlin gradle debug hint" })
end

return M