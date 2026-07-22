-- ~/.config/nvim/lua/dap/android.lua

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapters = {
\tlldb = {
\t\tcommand = "lldb-dap",
\t},
\tadb = {
\t\tcommand = "adb",
\t},
\tjdb = {
\t\tcommand = "jdb",
\t},
}

local function executable(cmd)
\treturn fn.executable(cmd) == 1
end

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.android" })
end

local function system(cmd)
\tlocal result = vim.system(cmd, { text = true }):wait()
\treturn result.code, (result.stdout or ""), (result.stderr or "")
end

local function trim(s)
\treturn (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_lines(s)
\tif not s or s == "" then
\t\treturn {}
\tend
\treturn vim.split(s, "
", { trimempty = true })
end

local function input(prompt, default, completion)
\treturn fn.input(prompt, default or "", completion or "")
end

local function pick(items, prompt)
\tif #items == 0 then
\t\treturn nil
\tend

\tlocal choices = { prompt or "Select:" }
\tfor i, item in ipairs(items) do
\t\tchoices[#choices + 1] = string.format("%d. %s", i, item)
\tend

\tlocal choice = fn.inputlist(choices)
\tif choice < 1 or choice > #items then
\t\treturn nil
\tend

\treturn items[choice]
end

local function adb(...)
\treturn { M.adapters.adb.command, ... }
end

local function ensure_adb()
\tif not executable(M.adapters.adb.command) then
\t\tnotify("adb not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend
\treturn true
end

local function ensure_lldb()
\tif not executable(M.adapters.lldb.command) then
\t\tnotify("lldb-dap not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend
\treturn true
end

local function connected_devices()
\tif not ensure_adb() then
\t\treturn {}
\tend

\tlocal code, stdout, stderr = system(adb("devices"))
\tif code ~= 0 then
\t\tnotify(trim(stderr) ~= "" and trim(stderr) or "adb devices failed", vim.log.levels.ERROR)
\t\treturn {}
\tend

\tlocal devices = {}
\tfor _, line in ipairs(split_lines(stdout)) do
\t\tif not line:match("^List of devices attached") and line:match("%S") then
\t\t\tlocal serial, state = line:match("^(%S+)%s+(%S+)")
\t\t\tif serial and state == "device" then
\t\t\t\tdevices[#devices + 1] = serial
\t\t\tend
\t\tend
\tend

\treturn devices
end

local function choose_device()
\tlocal devices = connected_devices()
\tif #devices == 0 then
\t\tnotify("No Android devices/emulators detected", vim.log.levels.WARN)
\t\treturn nil
\tend

\tif #devices == 1 then
\t\treturn devices[1]
\tend

\treturn pick(devices, "Android device:")
end

local function adb_shell(serial, command)
\treturn adb("-s", serial, "shell", command)
end

local function package_from_gradle()
\tlocal cwd = fn.getcwd()
\tlocal candidates = {
\t\tcwd .. "/app/build.gradle",
\t\tcwd .. "/app/build.gradle.kts",
\t\tcwd .. "/build.gradle",
\t\tcwd .. "/build.gradle.kts",
\t}

\tfor _, file in ipairs(candidates) do
\t\tif uv.fs_stat(file) then
\t\t\tfor _, line in ipairs(fn.readfile(file)) do
\t\t\t\tlocal pkg = line:match('applicationId%s+"([^"]+)"')
\t\t\t\t\tor line:match("applicationId%s*=%s*"([^"]+)"")
\t\t\t\t\tor line:match('namespace%s+"([^"]+)"')
\t\t\t\t\tor line:match("namespace%s*=%s*"([^"]+)"")
\t\t\t\tif pkg then
\t\t\t\t\treturn pkg
\t\t\t\tend
\t\t\tend
\t\tend
\tend

\treturn nil
end

local function resolve_package_name()
\tlocal guessed = package_from_gradle() or ""
\tlocal pkg = input("Android package: ", guessed)
\tif pkg == nil or pkg == "" then
\t\treturn nil
\tend
\treturn pkg
end

local function resolve_activity()
\tlocal activity = input("Launch activity (optional, e.g. .MainActivity): ", "")
\tif activity == nil then
\t\treturn nil
\tend
\treturn activity
end

local function resolve_port(default)
\tlocal value = input("Local TCP port: ", tostring(default or 8700))
\tlocal num = tonumber(value)
\tif not num then
\t\treturn nil
\tend
\treturn num
end

local function list_jdwp(serial)
\tlocal code, stdout, stderr = system(adb("-s", serial, "jdwp"))
\tif code ~= 0 then
\t\tnotify(trim(stderr) ~= "" and trim(stderr) or "adb jdwp failed", vim.log.levels.ERROR)
\t\treturn {}
\tend

\tlocal pids = {}
\tfor _, line in ipairs(split_lines(stdout)) do
\t\tif line:match("^%d+$") then
\t\t\tpids[#pids + 1] = line
\t\tend
\tend

\treturn pids
end

local function pid_for_package(serial, package_name)
\tlocal code, stdout = system(adb_shell(serial, "pidof " .. package_name))
\tif code == 0 then
\t\tlocal pid = trim(stdout)
\t\tif pid ~= "" then
\t\t\tpid = pid:match("^(%d+)")
\t\t\tif pid then
\t\t\t\treturn pid
\t\t\tend
\t\tend
\tend

\tlocal code2, stdout2 = system(adb_shell(serial, "ps -A"))
\tif code2 ~= 0 then
\t\treturn nil
\tend

\tfor _, line in ipairs(split_lines(stdout2)) do
\t\tif line:match(package_name:gsub("%.", "%%.")) then
\t\t\tlocal cols = vim.split(trim(line), "%s+")
\t\t\tfor i = 1, #cols do
\t\t\t\tif cols[i] == package_name and cols[2] and cols[2]:match("^%d+$") then
\t\t\t\t\treturn cols[2]
\t\t\t\tend
\t\t\tend
\t\tend
\tend

\treturn nil
end

function M.select_device()
\tlocal serial = choose_device()
\tif serial then
\t\tnotify("Using device: " .. serial)
\tend
\treturn serial
end

function M.launch_app()
\tlocal serial = choose_device()
\tif not serial then
\t\treturn
\tend

\tlocal package_name = resolve_package_name()
\tif not package_name then
\t\treturn
\tend

\tlocal activity = resolve_activity()
\tlocal command

\tif activity ~= "" then
\t\tlocal component = activity:match("^%.") and (package_name .. "/" .. package_name .. activity)
\t\t\tor (package_name .. "/" .. activity)
\t\tcommand = string.format("am start -D -n %s", component)
\telse
\t\tcommand = string.format("monkey -p %s -c android.intent.category.LAUNCHER 1", package_name)
\tend

\tlocal code, stdout, stderr = system(adb_shell(serial, command))
\tif code ~= 0 then
\t\tnotify(trim(stderr) ~= "" and trim(stderr) or "Failed to launch app", vim.log.levels.ERROR)
\t\treturn
\tend

\tnotify("Launched " .. package_name .. " on " .. serial)
\tif trim(stdout) ~= "" then
\t\tnotify(trim(stdout))
\tend
end

function M.forward_jdwp()
\tlocal serial = choose_device()
\tif not serial then
\t\treturn
\tend

\tlocal package_name = resolve_package_name()
\tif not package_name then
\t\treturn
\tend

\tlocal pid = pid_for_package(serial, package_name)
\tif not pid then
\t\tlocal jdwp = list_jdwp(serial)
\t\tpid = pick(jdwp, "JDWP PID:")
\t\tif not pid then
\t\t\tnotify("No JDWP process selected", vim.log.levels.WARN)
\t\t\treturn
\t\tend
\tend

\tlocal port = resolve_port(8700)
\tif not port then
\t\treturn
\tend

\tlocal code, _, stderr = system(adb("-s", serial, "forward", ("tcp:%d"):format(port), ("jdwp:%s"):format(pid)))
\tif code ~= 0 then
\t\tnotify(trim(stderr) ~= "" and trim(stderr) or "adb forward failed", vim.log.levels.ERROR)
\t\treturn
\tend

\tnotify(string.format("Forwarded localhost:%d -> jdwp:%s (%s)", port, pid, package_name))
end

function M.clear_forwards()
\tlocal serial = choose_device()
\tif not serial then
\t\treturn
\tend

\tlocal code, _, stderr = system(adb("-s", serial, "forward", "--remove-all"))
\tif code ~= 0 then
\t\tnotify(trim(stderr) ~= "" and trim(stderr) or "Failed to clear adb forwards", vim.log.levels.ERROR)
\t\treturn
\tend

\tnotify("Cleared adb forwards for " .. serial)
end

function M.native_attach_lldb()
\tif not ensure_lldb() then
\t\treturn
\tend

\tlocal serial = choose_device()
\tif not serial then
\t\treturn
\tend

\tlocal package_name = resolve_package_name()
\tif not package_name then
\t\treturn
\tend

\tlocal pid = pid_for_package(serial, package_name)
\tif not pid then
\t\tnotify("Could not resolve PID for package " .. package_name, vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal port = resolve_port(5039)
\tif not port then
\t\treturn
\tend

\tlocal code, _, stderr = system(adb("-s", serial, "forward", ("tcp:%d"):format(port), ("localfilesystem:/data/data/%s/debug.socket"):format(package_name)))
\tif code ~= 0 then
\t\tnotify(
\t\t\ttrim(stderr) ~= "" and trim(stderr)
\t\t\t\tor "adb forward for native debug failed; ensure app/native debug socket exists",
\t\t\tvim.log.levels.ERROR
\t\t)
\t\treturn
\tend

\tdebug.start({
\t\ttype = "lldb",
\t\trequest = "attach",
\t\tname = "Android Native Attach (lldb-dap)",
\t\tprogram = input("Local binary path (unstripped .so or executable): ", fn.getcwd() .. "/", "file"),
\t\tpid = tonumber(pid),
\t\tcwd = fn.getcwd(),
\t\tinitCommands = {
\t\t\tstring.format("platform select remote-android"),
\t\t\tstring.format("platform connect connect://127.0.0.1:%d", port),
\t\t},
\t})

\tnotify(string.format("Started LLDB native attach for %s (pid %s)", package_name, pid))
end

function M.logcat()
\tlocal serial = choose_device()
\tif not serial then
\t\treturn
\tend

\tvim.cmd("botright split")
\tlocal buf = api.nvim_create_buf(false, true)
\tapi.nvim_win_set_buf(0, buf)

\tlocal job = vim.fn.jobstart({ M.adapters.adb.command, "-s", serial, "logcat" }, {
\t\tpty = true,
\t\tstdout_buffered = false,
\t\ton_stdout = function(_, data)
\t\t\tif not data then
\t\t\t\treturn
\t\t\tend
\t\t\tapi.nvim_buf_set_lines(buf, -1, -1, false, data)
\t\tend,
\t\ton_stderr = function(_, data)
\t\t\tif not data then
\t\t\t\treturn
\t\t\tend
\t\t\tapi.nvim_buf_set_lines(buf, -1, -1, false, data)
\t\tend,
\t})

\tif job <= 0 then
\t\tnotify("Failed to start logcat", vim.log.levels.ERROR)
\t\treturn
\tend

\tvim.bo[buf].bufhidden = "wipe"
\tvim.bo[buf].filetype = "logcat"
\tvim.bo[buf].swapfile = false
\tvim.b[buf].android_logcat_job = job
\tnotify("Streaming logcat for " .. serial)
end

function M.setup()
\tapi.nvim_create_user_command("AndroidSelectDevice", M.select_device, {
\t\tdesc = "Select Android device/emulator",
\t})

\tapi.nvim_create_user_command("AndroidLaunch", M.launch_app, {
\t\tdesc = "Launch Android app in debug-friendly mode",
\t})

\tapi.nvim_create_user_command("AndroidForwardJdwp", M.forward_jdwp, {
\t\tdesc = "Forward JDWP port for Java/Kotlin debugging",
\t})

\tapi.nvim_create_user_command("AndroidClearForwards", M.clear_forwards, {
\t\tdesc = "Clear adb forwards for selected device",
\t})

\tapi.nvim_create_user_command("AndroidNativeAttach", M.native_attach_lldb, {
\t\tdesc = "Attach lldb-dap to Android native process",
\t})

\tapi.nvim_create_user_command("AndroidLogcat", M.logcat, {
\t\tdesc = "Open adb logcat in a split",
\t})

\tvim.keymap.set("n", "<leader>aa", M.launch_app, { desc = "Android launch app" })
\tvim.keymap.set("n", "<leader>aj", M.forward_jdwp, { desc = "Android forward JDWP" })
\tvim.keymap.set("n", "<leader>an", M.native_attach_lldb, { desc = "Android native attach" })
\tvim.keymap.set("n", "<leader>al", M.logcat, { desc = "Android logcat" })
\tvim.keymap.set("n", "<leader>ax", M.clear_forwards, { desc = "Android clear forwards" })
end

return M