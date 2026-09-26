---
name: love2d-input
description: Input in LÖVE — keyboard, mouse, gamepad, and phone touch,
  unified behind semantic game actions. Use when handling any player input,
  supporting both desktop and touch, or adding multitouch and gamepads.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE input

LÖVE has four input families. Design rule for cross-platform games:
**game code reads semantic actions** (`jump`, `confirm`, `move_left`);
thin adapters translate each device into those actions. Never hard-code
one device family into gameplay logic.

## Keyboard

```lua
-- polling (good in love.update):
if love.keyboard.isDown("left", "a") then move_left() end

-- events (good for single presses):
function love.keypressed(key)
  if key == "space" then jump() end
end

function love.textinput(text)
  -- text entry for name fields, chat; handles OS input methods
end
```

Key names are strings like `"space"`, `"escape"`, `"return"`, `"a"`.
Reference: <https://love2d.org/wiki/love.keyboard>

## Mouse — and free single-touch

```lua
function love.mousepressed(x, y, button, istouch)
  -- istouch is true when this "click" came from a finger.
  -- Mouse callbacks double as single-touch handlers via istouch.
end
```

Polling: `love.mouse.getPosition()`, `love.mouse.isDown(1)`.
`love.mousemoved` and `love.wheelmoved` cover motion and scroll.

## Touch: phones and tablets

```lua
function love.touchpressed(id, x, y, dx, dy, pressure)
  touches[id] = { x = x, y = y }   -- id is per-finger; track it
end

function love.touchmoved(id, x, y, dx, dy, pressure)
  if touches[id] then touches[id].x, touches[id].y = x, y end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
  touches[id] = nil
end
```

- `love.touch.getTouches()` lists currently active touch ids.
- `id` is light userdata, unique per contact — a table keyed by `id`
  is the standard multitouch pattern.
- `love.touch.getPosition(id)` / `getPressure(id)` for polling.

Reference: <https://love2d.org/wiki/love.touch>

## Gamepad / joystick

```lua
local sticks = love.joystick.getJoysticks()
for _, s in ipairs(sticks) do
  if s:isGamepad() then
    local x = s:getGamepadAxis("leftx")
  end
end

function love.gamepadpressed(joystick, button)
  if button == "a" then jump() end   -- "a","b","x","y","start",...
end
```

Works with standard controllers on desktop; many Android controllers
too. Reference: <https://love2d.org/wiki/love.joystick>

## The semantic-action pattern

One table of actions, many devices feeding it:

```lua
local actions = { left = false, right = false, jump = false }

local function bind()
  actions.left = love.keyboard.isDown("left", "a")
  actions.right = love.keyboard.isDown("right", "d")
  -- touch buttons and gamepad set the same fields in their callbacks
end

function love.update(dt)
  bind()
  if actions.jump then player:jump() end
  player:move((actions.right and 1 or 0) - (actions.left and 1 or 0))
end

function love.touchpressed(id, x, y)
  if on_screen_button("jump", x, y) then actions.jump = true end
end
function love.touchreleased(id, x, y)
  actions.jump = false
end
```

Gameplay reads `actions` only. Adding a new device means writing one
adapter, not touching game logic.

## Phone vs desktop input notes

- Phones have **no hover** and no right-click — every control must be a
  tap, drag, or on-screen button.
- Make touch targets big (at least ~44 logical pixels) and keep them
  inside the safe area (`love.window.getSafeArea()`; see
  `love2d-platforms`).
- On desktop, mouse position is always known; on touch, position only
  exists while a finger is down — design UI accordingly.
- Keyboard shortcuts do not exist on phones: every action needs a
  touch path if you ship to Android/iOS.
