---
name: love2d-basics
description: Start a LÖVE game from zero — project folder layout, conf.lua
  options, and the love.load / love.update / love.draw game loop. Use when
  creating a new LÖVE project, explaining how a LÖVE game fits together, or
  fixing startup and configuration problems. Targets LÖVE 11.5.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE basics

LÖVE (love2d.org) is a free, open-source framework for making 2D games in
Lua. You write Lua files; LÖVE runs them as a game on Windows, macOS,
Linux, Android, and iOS. This skill covers version **11.5** (the current
stable release; 12.0 is still in development).

Full API reference: <https://love2d.org/wiki/love>

## A game is a folder

A LÖVE game is a folder whose root contains **`main.lua`**. That file is
required. An optional **`conf.lua`** in the same folder configures the
game before the window opens.

```text
my-game/
  main.lua   -- required: your game
  conf.lua   -- optional: configuration
```

Run it with the `love` executable pointed at the folder:

```text
love my-game/
```

## The game loop: three functions

LÖVE calls three functions you define. That is the whole loop:

```lua
function love.load(args)
  -- Runs ONCE when the game starts. Load images, sounds, set up state.
end

function love.update(dt)
  -- Runs every frame BEFORE drawing. dt = seconds since last frame.
  -- Move things here: x = x + speed * dt
end

function love.draw()
  -- Runs every frame AFTER update. Draw everything here.
  love.graphics.print("Hello!", 20, 20)
end
```

Behind the scenes `love.run` owns the real loop (event pumping, timing,
clearing, presenting). You almost never override it; if you need a fixed
timestep for physics, see `love2d-physics`.

Two helpers you will use constantly:

- `love.event.quit()` — quit the game (bind it to Escape, see below).
- `love.timer.getFPS()` — current frames per second, for debugging.

## conf.lua: configure before the window opens

```lua
-- conf.lua
function love.conf(t)
  t.identity = "my-game"   -- name of the save-data folder
  t.version = "11.5"       -- LÖVE version this game targets
  t.console = false        -- Windows only: open a debug console

  t.window.title = "My Game"
  t.window.width = 960
  t.window.height = 640
  t.window.resizable = true
  t.window.vsync = 1
  t.window.highdpi = true

  -- Turn off modules you do not use. Smaller footprint, matters on phones:
  -- t.modules.physics = false
  -- t.modules.video = false
end
```

Key facts:

- `t.identity` decides where `love.filesystem` writes saves.
- `t.console` only does anything on **Windows**.
- `t.accelerometerjoystick` and `t.externalstorage` are **mobile only**.
- There is **no orientation key** in conf.lua. Screen orientation is set
  per platform: Android manifest/gradle config, iOS Xcode project. See
  `love2d-platforms`.
- Full option list: <https://love2d.org/wiki/Config_Files>

## Sharing a game: the .love file

A `.love` file is a **ZIP** of your game's files. Zip the *contents* of
the folder, not the folder itself, so `main.lua` sits at the archive
root. Then `love game.love` runs it anywhere LÖVE is installed.
Packaging per platform (fused executables, app bundles, APKs) is covered
in `love2d-distribute`.

## Minimal complete example

```lua
-- main.lua
function love.load()
  love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
end

function love.update(dt)
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Hello from LÖVE!", 20, 20)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
```

## Where to go next

- Drawing things: `love2d-graphics`
- Sound and assets: `love2d-audio`
- Keyboard, mouse, touch, gamepad: `love2d-input`
- Desktop vs phone differences: `love2d-platforms`
- Shipping the game: `love2d-distribute`
- Interactive new-game questionnaire: `love2d-scaffold`
