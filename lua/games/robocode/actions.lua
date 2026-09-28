-- #################################################################
-- /qompassai/Diver/lua/games/robocode/actions.lua
-- Qompass AI Robocode Actions
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
-- Interactive Robocode actions: scaffold a robot from Robocode's own
-- "new robot" template, compile it with javac, pick combatants for a
-- headless battle, and open the GUI. This module only wires prompts to
-- the launch builders in games.robocode; the battle itself runs as a
-- tracked vim.system job so :RobocodeStop can end it.
--
-- NOTE: games.robocode is required lazily inside functions (not at the
-- top) because init.lua requires this module -- a top-level require
-- would capture a half-initialized table.
local shared_util = require('games.shared.util')

local notify = vim.notify
local levels = vim.log.levels
local M = {}

---@type vim.SystemObj?
local battle_job = nil

---Stop the running battle/GUI, if any. Idempotent: safe with no job.
local function stop_current()
    local job = battle_job
    battle_job = nil
    if job ~= nil then
        pcall(job.kill, job, 'sigterm')
    end
end

---Robocode's own "new robot" wizard template (templates/newrobot.tpt
---from the 1.11.1 installer), tabs re-indented to 4 spaces. Upstream
---ships no AdvancedRobot template, so none is invented here.
local ROBOT_TEMPLATE = [[package $PACKAGE;
import robocode.*;
//import java.awt.Color;

// API help : https://robocode.sourceforge.io/docs/robocode/robocode/Robot.html

/**
 * $CLASSNAME - a robot by (your name here)
 */
public class $CLASSNAME extends Robot
{
    /**
     * run: $CLASSNAME's default behavior
     */
    public void run() {
        // Initialization of the robot should be put here

        // After trying out your robot, try uncommenting the import at the top,
        // and the next line:

        // setColors(Color.red,Color.blue,Color.green); // body,gun,radar

        // Robot main loop
        while(true) {
            // Replace the next 4 lines with any behavior you would like
            ahead(100);
            turnGunRight(360);
            back(100);
            turnGunRight(360);
        }
    }

    /**
     * onScannedRobot: What to do when you see another robot
     */
    public void onScannedRobot(ScannedRobotEvent e) {
        // Replace the next line with any behavior you would like
        fire(1);
    }

    /**
     * onHitByBullet: What to do when you're hit by a bullet
     */
    public void onHitByBullet(HitByBulletEvent e) {
        // Replace the next line with any behavior you would like
        back(10);
    }

    /**
     * onHitWall: What to do when you hit a wall
     */
    public void onHitWall(HitWallEvent e) {
        // Replace the next line with any behavior you would like
        back(20);
    }
}
]]

---@param path string
---@param content string
---@return boolean ok
---@return string? err
local function write_file(path, content)
    local handle, open_err = io.open(path, 'w')
    if handle == nil then
        return false, tostring(open_err)
    end
    handle:write(content)
    handle:close()
    return true
end

---Compile one robot source against the Robocode API jar.
---@param file string absolute .java path
local function compile_robot(file)
    local robocode = require('games.robocode')
    local javac = robocode.find_javac()
    if javac == nil then
        notify('Robocode: javac not found on PATH (install a JDK to compile robots)', levels.ERROR)
        return
    end
    local root = robocode.find_install_root()
    if root == nil then
        notify('Robocode: install root not found, cannot build a compile classpath', levels.ERROR)
        return
    end
    local out_dir = robocode.dev_robots_dir()
    vim.system(
        { javac, '-cp', root .. '/libs/robocode.jar', '-d', out_dir, file },
        { text = true, timeout = robocode.config.compile_timeout_ms },
        vim.schedule_wrap(function(completed)
            if completed.code == 0 then
                notify('Robocode: compiled ' .. vim.fn.fnamemodify(file, ':t'), levels.INFO)
            else
                local err = shared_util.trim(completed.stderr or '')
                notify('Robocode: compile failed:\n' .. err, levels.ERROR)
            end
        end)
    )
end

---Discover robots under a robots dir: '**/*.class' becomes 'pkg.Class'.
---Inner classes (names containing $) are skipped; output is sorted.
---@param robots_dir string
---@param extension '.class'|'.java'
---@return string[] sorted robot/source names, capped
local function discover(robots_dir, extension)
    local robocode = require('games.robocode')
    local paths = vim.fn.globpath(robots_dir, '**/*' .. extension, false, true)
    ---@type string[]
    local names = {}
    local prefix = robots_dir .. '/'
    local limit = math.min(#paths, robocode.config.scan_entries_max)
    for i = 1, limit do
        local rel = paths[i]
        if vim.startswith(rel, prefix) then
            rel = rel:sub(#prefix + 1)
        end
        local name = rel:sub(1, -(#extension + 1)):gsub('/', '.')
        if not name:find('$', 1, true) then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

---@param pkg string
---@return boolean valid Java package name (dot-separated lowercase identifiers)
local function valid_package(pkg)
    if pkg == '' then
        return false
    end
    -- Lua patterns cannot quantify a group, so validate dot placement
    -- up front: gmatch would silently skip empty segments.
    if pkg:sub(1, 1) == '.' or pkg:sub(-1) == '.' or pkg:find('%.%.') ~= nil then
        return false
    end
    for segment in pkg:gmatch('[^.]+') do
        if segment:match('^[a-z_][%w_]*$') == nil then
            return false
        end
    end
    return true
end

---Scaffold a new robot from Robocode's own template, open it, compile it.
function M.new_robot()
    local robocode = require('games.robocode')

    local pkg = shared_util.trim(vim.fn.input('Robot package: ', 'myrobots'))
    if pkg == '' then
        return
    end
    if not valid_package(pkg) then
        notify('Robocode: invalid Java package: ' .. pkg, levels.ERROR)
        return
    end
    local class = shared_util.trim(vim.fn.input('Robot class: ', 'MyRobot'))
    if class == '' then
        return
    end
    if class:match('^[%a_$][%w_$]*$') == nil then
        notify('Robocode: invalid Java class name: ' .. class, levels.ERROR)
        return
    end

    local file = robocode.dev_robots_dir() .. '/' .. pkg:gsub('%.', '/') .. '/' .. class .. '.java'
    if vim.fn.filereadable(file) == 1 then
        notify('Robocode: refusing to overwrite ' .. file, levels.ERROR)
        return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')

    local content = ROBOT_TEMPLATE:gsub('%$PACKAGE', function()
        return pkg
    end):gsub('%$CLASSNAME', function()
        return class
    end)
    local ok, err = write_file(file, content)
    if not ok then
        notify('Robocode: cannot write ' .. file .. ': ' .. tostring(err), levels.ERROR)
        return
    end
    notify('Robocode: scaffolded ' .. file, levels.INFO)
    vim.cmd.edit(vim.fn.fnameescape(file))
    compile_robot(file)
end

---Let the user accumulate combatants, then start the battle.
---@param robots string[] candidates
---@param done fun(selected: string[]?)
local function pick_robots(robots, done)
    local robocode = require('games.robocode')
    ---@type string[]
    local selected = {}
    ---@type string[]
    local remaining = {}
    for _, name in ipairs(robots) do
        remaining[#remaining + 1] = name
    end
    local function step()
        if #selected >= robocode.config.robots_max then
            done(selected)
            return
        end
        ---@type string[]
        local items = { '[start battle]' }
        for _, name in ipairs(remaining) do
            items[#items + 1] = name
        end
        local prompt = 'Add robot (' .. #selected .. ' selected):'
        vim.ui.select(items, { prompt = prompt }, function(choice)
            if choice == nil or choice == '[start battle]' then
                done(#selected > 0 and selected or nil)
                return
            end
            selected[#selected + 1] = choice
            for i, name in ipairs(remaining) do
                if name == choice then
                    table.remove(remaining, i)
                    break
                end
            end
            step()
        end)
    end
    step()
end

---@param results_file string
local function show_results(results_file)
    local robocode = require('games.robocode')
    local handle = io.open(results_file, 'r')
    if handle == nil then
        notify('Robocode: battle finished, no results file written', levels.WARN)
        return
    end
    ---@type string[]
    local shown = {}
    for line in handle:lines() do
        if #shown >= robocode.config.output_lines_max then
            break
        end
        shown[#shown + 1] = line
    end
    handle:close()
    notify('Robocode results:\n' .. table.concat(shown, '\n'), levels.INFO)
end

---@param selected string[] robot names for robocode.battle.selectedRobots
local function start_battle(selected)
    local robocode = require('games.robocode')
    local config = robocode.config
    local robots_dir = robocode.dev_robots_dir()
    local battle_dir = robocode.battle_dir()
    vim.fn.mkdir(battle_dir, 'p')

    -- .battle keys below are byte-faithful to the installer's own
    -- battles/sample.battle; only selectedRobots varies per battle.
    local stamp = os.date('%Y%m%d-%H%M%S')
    local battle_file = battle_dir .. '/battle-' .. stamp .. '.battle'
    local results_file = battle_dir .. '/results-' .. stamp .. '.txt'
    local spec = table.concat({
        '#Battle Properties',
        'robocode.battleField.width=800',
        'robocode.battleField.height=600',
        'robocode.battle.numRounds=' .. tostring(config.battle_rounds),
        'robocode.battle.gunCoolingRate=0.1',
        'robocode.battle.rules.inactivityTime=450',
        'robocode.battle.hideEnemyNames=true',
        'robocode.battle.selectedRobots=' .. table.concat(selected, ','),
        '',
    }, '\n')
    local ok, err = write_file(battle_file, spec)
    if not ok then
        notify('Robocode: cannot write ' .. battle_file .. ': ' .. tostring(err), levels.ERROR)
        return
    end

    local launch, launch_err = robocode.build_launch({
        headless = true,
        battle_file = battle_file,
        results_file = results_file,
        tps = config.battle_tps,
        robot_path = robots_dir,
    })
    if launch == nil then
        notify('Robocode: ' .. tostring(launch_err), levels.ERROR)
        return
    end
    stop_current()
    battle_job = vim.system(
        launch.argv,
        { cwd = launch.cwd, text = true, timeout = config.battle_timeout_ms },
        vim.schedule_wrap(function(completed)
            battle_job = nil
            if completed.code ~= 0 then
                notify('Robocode: battle exited with code ' .. completed.code, levels.WARN)
            end
            show_results(results_file)
        end)
    )
    notify('Robocode: battle started (' .. #selected .. ' robots)', levels.INFO)
end

---Pick combatants from compiled dev robots and run a headless battle.
function M.run_battle()
    local robocode = require('games.robocode')
    local robots = discover(robocode.dev_robots_dir(), '.class')
    if #robots == 0 then
        local dir = robocode.dev_robots_dir()
        notify('Robocode: no compiled robots in ' .. dir .. ' (run New robot first)', levels.WARN)
        return
    end
    pick_robots(robots, function(selected)
        if selected ~= nil and #selected > 0 then
            start_battle(selected)
        end
    end)
end

---Stop the running battle or GUI, if any.
function M.stop_battle()
    stop_current()
    notify('Robocode: stopped', levels.INFO)
end

---Open a developed robot's source file.
function M.open_robot_source()
    local robocode = require('games.robocode')
    local sources = discover(robocode.dev_robots_dir(), '.java')
    if #sources == 0 then
        notify('Robocode: no robot sources in ' .. robocode.dev_robots_dir(), levels.WARN)
        return
    end
    vim.ui.select(sources, { prompt = 'Open robot source:' }, function(choice)
        if choice == nil then
            return
        end
        local path = robocode.dev_robots_dir() .. '/' .. choice:gsub('%.', '/') .. '.java'
        vim.cmd.edit(vim.fn.fnameescape(path))
    end)
end

---Launch the Robocode GUI (no -nodisplay): sample robots and the
---built-in source editor live here.
function M.open_gui()
    local robocode = require('games.robocode')
    local launch, err = robocode.build_launch({ headless = false })
    if launch == nil then
        notify('Robocode: ' .. tostring(err), levels.ERROR)
        return
    end
    stop_current()
    battle_job = vim.system(launch.argv, { cwd = launch.cwd, text = true })
    notify('Robocode: GUI launched', levels.INFO)
end

function M.doctor()
    vim.cmd('checkhealth games.robocode')
end

---@return table[] action list { id, label, run }
function M.get_actions()
    return {
        { id = 'new_robot', label = 'New robot (scaffold + compile)', run = M.new_robot },
        { id = 'run_battle', label = 'Run headless battle', run = M.run_battle },
        { id = 'stop_battle', label = 'Stop battle', run = M.stop_battle },
        { id = 'open_robot_source', label = 'Open robot source', run = M.open_robot_source },
        { id = 'open_gui', label = 'Open Robocode GUI', run = M.open_gui },
        { id = 'doctor', label = 'Doctor (:checkhealth)', run = M.doctor },
    }
end

---@param action table
function M.run_action(action)
    local ok, err = pcall(action.run)
    if not ok then
        notify('Robocode action failed: ' .. tostring(err), levels.ERROR)
    end
end

---@param id string
function M.run_action_by_id(id)
    for _, action in ipairs(M.get_actions()) do
        if action.id == id then
            M.run_action(action)
            return
        end
    end
    notify('Robocode: unknown action: ' .. tostring(id), levels.ERROR)
end

function M.show_menu()
    require('games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
        prompt = 'Robocode',
    })
end

return M
