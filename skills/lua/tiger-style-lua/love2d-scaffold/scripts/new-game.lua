-- new-game.lua -- Interactive LOVE project scaffolder.
--
-- Usage: lua new-game.lua
--
-- Asks a few plain-language questions, then creates a ready-to-run LOVE
-- game project: conf.lua, main.lua and README.md.
--
-- Plain Lua, no dependencies. Works with Lua 5.1 and newer.

local SEP = package.config:sub(1, 1) -- "\" on Windows, "/" elsewhere

----------------------------------------------------------------------
-- small prompt helpers
----------------------------------------------------------------------

local function trim(s)
    return (s:gsub('^%s*(.-)%s*$', '%1'))
end

local function ask(prompt, default)
    if default and default ~= '' then
        io.write(prompt .. ' [' .. default .. ']: ')
    else
        io.write(prompt .. ': ')
    end
    local answer = trim(io.read('*l') or '')
    if answer == '' then
        return default or ''
    end
    return answer
end

local function ask_choice(prompt, options, default_index)
    print(prompt)
    for i, option in ipairs(options) do
        print(string.format('  %d) %s', i, option))
    end
    while true do
        local n = tonumber(ask('Pick a number', tostring(default_index)))
        if n and n >= 1 and n <= #options and n == math.floor(n) then
            return n
        end
        print('Please pick a number from 1 to ' .. #options .. '.')
    end
end

local function ask_yes_no(prompt, default_yes)
    local hint = default_yes and 'Y/n' or 'y/N'
    while true do
        local raw = ask(prompt .. ' (' .. hint .. ')', ''):lower()
        if raw == '' then
            return default_yes
        elseif raw == 'y' or raw == 'yes' then
            return true
        elseif raw == 'n' or raw == 'no' then
            return false
        end
        print('Please answer y or n.')
    end
end

----------------------------------------------------------------------
-- filesystem helpers
----------------------------------------------------------------------

local function sanitize(name)
    local slug = name:lower():gsub('[^%w]+', '-')
    slug = slug:gsub('^%-+', ''):gsub('%-+$', '')
    if slug == '' then
        slug = 'my-love-game'
    end
    return slug
end

local function make_dir(path)
    local cmd
    if SEP == '\\' then
        cmd = 'mkdir "' .. path .. '" 2>nul'
    else
        cmd = 'mkdir -p "' .. path .. '"'
    end
    os.execute(cmd)
end

local function exists(path)
    local f = io.open(path, 'r')
    if f then
        f:close()
        return true
    end
    return false
end

local function write_file(path, content)
    local f, err = io.open(path, 'w')
    assert(f, 'cannot write ' .. path .. ': ' .. tostring(err))
    f:write(content)
    f:close()
end

----------------------------------------------------------------------
-- the questionnaire
----------------------------------------------------------------------

local function questionnaire()
    print('=== New LOVE game ===')
    print('A few questions; defaults are in [brackets].')
    print()

    local game = {}
    game.title = ask('Game name', 'My Love Game')
    game.safe_title = game.title:gsub('"', '\\"')
    game.slug = sanitize(game.title)

    local templates = {
        'Empty -- just the game loop, a starting point',
        'Side view -- a character that runs and jumps',
        'Top down -- a character that moves around',
    }
    game.template = ask_choice('What kind of game?', templates, 1)

    local platforms = {
        'Desktop -- Windows, Mac, Linux (keyboard, mouse, gamepad)',
        'Phone -- Android, iOS (touch screen)',
        'Both -- desktop and phone',
    }
    game.platform = ask_choice('Where will people play it?', platforms, 3)

    game.desktop_targets = {}
    if game.platform ~= 2 then
        local raw = ask('Which desktop systems? (comma-separated: windows, mac, linux)', 'windows, mac, linux')
        for word in raw:lower():gmatch('[%w]+') do
            if word == 'windows' or word == 'mac' or word == 'linux' then
                game.desktop_targets[#game.desktop_targets + 1] = word
            end
        end
        if #game.desktop_targets == 0 then
            game.desktop_targets = { 'windows', 'mac', 'linux' }
        end
    end

    if game.platform ~= 1 then
        local orientations = { 'Landscape (wide)', 'Portrait (tall)' }
        local n = ask_choice('Phone orientation? (set in the Android/iOS project files)', orientations, 1)
        game.orientation = n == 1 and 'landscape' or 'portrait'
    end

    game.dir = ask('Project folder name', game.slug)
    local function has_project(dir)
        return exists(dir .. SEP .. 'conf.lua') or exists(dir .. SEP .. 'main.lua')
    end
    if game.dir ~= '' and has_project(game.dir) then
        local overwrite = ask_yes_no('That folder already has a LOVE project. Overwrite it?', false)
        if not overwrite then
            print('Cancelled. Nothing was written.')
            os.exit(0)
        end
    end
    return game
end

----------------------------------------------------------------------
-- file generators
----------------------------------------------------------------------

local function conf_lua(game)
    local lines = {
        '-- conf.lua -- LOVE configuration. Runs before the window opens.',
        '-- Docs: https://love2d.org/wiki/Config_Files',
        '',
        'function love.conf(t)',
        string.format('  t.identity = "%s"  -- save-data folder name', game.slug),
        '  t.version = "11.5"   -- LOVE version this game targets',
        '  t.console = false    -- Windows only: debug console',
        '',
        string.format('  t.window.title = "%s"', game.safe_title),
        '  t.window.width = 960',
        '  t.window.height = 640',
        '  t.window.resizable = true',
        '  t.window.vsync = 1',
        '  t.window.highdpi = true',
        '',
        '  -- Switch off modules you do not use (smaller on phones):',
        '  -- t.modules.physics = false',
        '  -- t.modules.video = false',
        'end',
        '',
    }
    return table.concat(lines, '\n')
end

local function main_empty(game)
    local lines = {
        '-- main.lua -- ' .. game.safe_title,
        '-- love.load runs once; love.update and love.draw run every frame.',
        '',
        'function love.load()',
        '  love.graphics.setBackgroundColor(0.1, 0.1, 0.15)',
        'end',
        '',
        'function love.update(dt)',
        'end',
        '',
        'function love.draw()',
        '  love.graphics.setColor(1, 1, 1)',
        string.format('  love.graphics.print("Hello from %s!", 20, 20)', game.safe_title),
        'end',
        '',
        'function love.keypressed(key)',
        '  if key == "escape" then',
        '    love.event.quit()',
        '  end',
        'end',
        '',
    }
    return table.concat(lines, '\n')
end

local function main_sideview(game)
    local lines = {
        '-- main.lua -- ' .. game.safe_title .. ' (side view)',
        '-- A character that runs and jumps. Keyboard AND touch wired',
        '-- to the same movement through one shared state.',
        '',
        'local SPEED, GRAVITY, JUMP = 260, 1400, 560',
        'local GROUND_Y = 500 -- feet rest here',
        '',
        'local player = { x = 60, feet_y = GROUND_Y, w = 32, h = 48, vy = 0 }',
        'local touch = { left = false, right = false, jump = false }',
        '',
        '-- On-screen buttons, drawn so touch players can see them.',
        'local buttons = {',
        '  left = { x = 20, y = 556, w = 80, h = 68 },',
        '  right = { x = 110, y = 556, w = 80, h = 68 },',
        '  jump = { x = 860, y = 556, w = 80, h = 68 },',
        '}',
        '',
        'local function inside(b, x, y)',
        '  return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h',
        'end',
        '',
        'function love.load()',
        '  love.graphics.setBackgroundColor(0.1, 0.1, 0.15)',
        'end',
        '',
        'function love.update(dt)',
        '  local move = 0',
        '  if love.keyboard.isDown("left", "a") or touch.left then',
        '    move = move - 1',
        '  end',
        '  if love.keyboard.isDown("right", "d") or touch.right then',
        '    move = move + 1',
        '  end',
        '',
        '  local want_jump = love.keyboard.isDown("space", "w", "up")',
        '    or touch.jump',
        '  player.vy = player.vy + GRAVITY * dt',
        '  if want_jump and player.feet_y >= GROUND_Y then',
        '    player.vy = -JUMP',
        '  end',
        '',
        '  player.x = player.x + move * SPEED * dt',
        '  player.feet_y = player.feet_y + player.vy * dt',
        '  if player.feet_y > GROUND_Y then',
        '    player.feet_y = GROUND_Y',
        '    player.vy = 0',
        '  end',
        'end',
        '',
        'function love.touchpressed(id, x, y)',
        '  if inside(buttons.left, x, y) then touch.left = true end',
        '  if inside(buttons.right, x, y) then touch.right = true end',
        '  if inside(buttons.jump, x, y) then touch.jump = true end',
        'end',
        '',
        'function love.touchreleased(id, x, y)',
        '  -- Simple version: any release clears all buttons.',
        '  -- Per-finger tracking is covered in the love2d-input skill.',
        '  touch.left, touch.right, touch.jump = false, false, false',
        'end',
        '',
        '-- A phone tap also arrives here as a mouse press with istouch.',
        'function love.mousepressed(x, y, button, istouch)',
        '  if istouch then love.touchpressed("mouse", x, y) end',
        'end',
        '',
        'function love.mousereleased(x, y, button, istouch)',
        '  if istouch then love.touchreleased("mouse", x, y) end',
        'end',
        '',
        'function love.draw()',
        '  love.graphics.setColor(0.25, 0.25, 0.3)',
        '  love.graphics.rectangle("fill", 0, GROUND_Y, 960, 140)',
        '',
        '  love.graphics.setColor(0.9, 0.4, 0.3)',
        '  love.graphics.rectangle(',
        '    "fill", player.x, player.feet_y - player.h, player.w, player.h)',
        '',
        '  love.graphics.setColor(1, 1, 1, 0.25)',
        '  for name, b in pairs(buttons) do',
        '    love.graphics.rectangle("line", b.x, b.y, b.w, b.h)',
        '    love.graphics.print(name, b.x + 10, b.y + 24)',
        '  end',
        'end',
        '',
        'function love.keypressed(key)',
        '  if key == "escape" then',
        '    love.event.quit()',
        '  end',
        'end',
        '',
    }
    return table.concat(lines, '\n')
end

local function main_topdown(game)
    local lines = {
        '-- main.lua -- ' .. game.safe_title .. ' (top down)',
        '-- A character that moves around. Arrows/WASD on desktop,',
        '-- drag on touch screens.',
        '',
        'local SPEED = 260',
        'local player = { x = 480, y = 320, r = 16 }',
        'local target = nil -- touch target while a finger is down',
        '',
        'function love.load()',
        '  love.graphics.setBackgroundColor(0.1, 0.1, 0.15)',
        'end',
        '',
        'function love.update(dt)',
        '  local dx, dy = 0, 0',
        '  if love.keyboard.isDown("left", "a") then dx = dx - 1 end',
        '  if love.keyboard.isDown("right", "d") then dx = dx + 1 end',
        '  if love.keyboard.isDown("up", "w") then dy = dy - 1 end',
        '  if love.keyboard.isDown("down", "s") then dy = dy + 1 end',
        '  if target then',
        '    local tx, ty = target.x - player.x, target.y - player.y',
        '    local dist = math.sqrt(tx * tx + ty * ty)',
        '    if dist > 4 then',
        '      dx, dy = tx / dist, ty / dist -- walk toward the finger',
        '    end',
        '  end',
        '  player.x = player.x + dx * SPEED * dt',
        '  player.y = player.y + dy * SPEED * dt',
        'end',
        '',
        'function love.touchpressed(id, x, y)',
        '  target = { x = x, y = y }',
        'end',
        '',
        'function love.touchmoved(id, x, y)',
        '  target = { x = x, y = y }',
        'end',
        '',
        'function love.touchreleased(id, x, y)',
        '  target = nil',
        'end',
        '',
        '-- A phone tap also arrives here as a mouse press with istouch.',
        'function love.mousepressed(x, y, button, istouch)',
        '  if istouch then love.touchpressed("mouse", x, y) end',
        'end',
        '',
        'function love.mousemoved(x, y, dx, dy, istouch)',
        '  if istouch then love.touchmoved("mouse", x, y) end',
        'end',
        '',
        'function love.mousereleased(x, y, button, istouch)',
        '  if istouch then love.touchreleased("mouse", x, y) end',
        'end',
        '',
        'function love.draw()',
        '  love.graphics.setColor(0.3, 0.7, 0.4)',
        '  love.graphics.circle("fill", player.x, player.y, player.r)',
        '  love.graphics.setColor(1, 1, 1)',
        '  love.graphics.print("Arrows/WASD or drag to move", 20, 20)',
        'end',
        '',
        'function love.keypressed(key)',
        '  if key == "escape" then',
        '    love.event.quit()',
        '  end',
        'end',
        '',
    }
    return table.concat(lines, '\n')
end

local function readme(game)
    local lines = {
        '# ' .. game.title,
        '',
        'A LOVE 2D game (LOVE 11.5). Made with the love2d-scaffold skill.',
        '',
        '## Run it',
        '',
        'Install LOVE from https://love2d.org, then:',
        '',
        '    love ' .. game.dir,
        '',
        '## Controls',
        '',
    }

    if game.template == 1 then
        lines[#lines + 1] = 'Escape quits. Everything else is yours to add.'
    elseif game.template == 2 then
        lines[#lines + 1] = '- Move: left/right arrows or A/D'
        lines[#lines + 1] = '- Jump: space, W, or up arrow'
        lines[#lines + 1] = '- Touch: on-screen left/right/jump buttons'
        lines[#lines + 1] = '- Escape quits'
    else
        lines[#lines + 1] = '- Move: arrow keys or WASD'
        lines[#lines + 1] = '- Touch: press and drag toward where you want to go'
        lines[#lines + 1] = '- Escape quits'
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = '## Package it'
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Make a `.love` file: zip the *contents* of this'
    lines[#lines + 1] = 'folder so `main.lua` sits at the archive root:'
    lines[#lines + 1] = ''
    lines[#lines + 1] = '    cd ' .. game.dir
    lines[#lines + 1] = '    zip -9 -r ../' .. game.slug .. ".love . -x '.*'"
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Then per platform (see the love2d-distribute skill):'
    lines[#lines + 1] = ''

    for _, target in ipairs(game.desktop_targets) do
        if target == 'windows' then
            lines[#lines + 1] = '- Windows: fuse with `copy /b love.exe+'
                .. game.slug
                .. '.love '
                .. game.slug
                .. '.exe`, ship the DLLs.'
        elseif target == 'mac' then
            lines[#lines + 1] = '- macOS: copy the `.love` into `love.app`,' .. ' edit Info.plist, sign and notarize.'
        elseif target == 'linux' then
            lines[#lines + 1] = '- Linux: ship the `.love` file or build an' .. ' AppImage.'
        end
    end
    if game.platform ~= 1 then
        lines[#lines + 1] = '- Android ('
            .. game.orientation
            .. '): build an'
            .. ' APK/AAB with the love-android repo; orientation goes in the'
            .. ' manifest, not conf.lua.'
        lines[#lines + 1] = '- iOS ('
            .. game.orientation
            .. '): Xcode'
            .. ' project, orientation in the target settings, sign for'
            .. ' TestFlight / the App Store.'
    end

    lines[#lines + 1] = ''
    return table.concat(lines, '\n')
end

----------------------------------------------------------------------
-- main
----------------------------------------------------------------------

local function main()
    local game = questionnaire()
    make_dir(game.dir)

    local mains = { main_empty, main_sideview, main_topdown }
    write_file(game.dir .. SEP .. 'conf.lua', conf_lua(game))
    write_file(game.dir .. SEP .. 'main.lua', mains[game.template](game))
    write_file(game.dir .. SEP .. 'README.md', readme(game))

    print()
    print('Created ' .. game.dir .. '/ with conf.lua, main.lua, README.md.')
    print('Run it: love ' .. game.dir)
end

main()
