---
name: love2d-graphics
description: Draw with LÖVE — shapes, images, text, transforms, canvases,
  and resolution/DPI handling for desktop and phones. Use when drawing
  anything in a LÖVE game, handling window resizing or rotation, supporting
  high-DPI and phone screens, or working with shaders and video.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE graphics

All drawing goes through **`love.graphics`** and happens inside
`love.draw()`. Colors are numbers from 0 to 1, not 0 to 255.

Reference: <https://love2d.org/wiki/love.graphics>

## Drawing basics

```lua
love.graphics.setColor(1, 1, 1)          -- white; stays until changed
love.graphics.rectangle("fill", 10, 10, 100, 50)
love.graphics.circle("line", 200, 200, 30)
love.graphics.line(0, 0, 100, 100)
love.graphics.print("Score: 10", 20, 20) -- text, needs a font (default ok)
```

Images:

```lua
local sprite = love.graphics.newImage("assets/hero.png")
function love.draw()
  love.graphics.draw(sprite, 100, 150)   -- draw at x, y
end
```

For crisp pixel art, turn off smoothing:

```lua
sprite:setFilter("nearest", "nearest")
```

## Transforms: move, rotate, zoom the canvas

```lua
love.graphics.push()          -- save the current transform
love.graphics.translate(400, 300)
love.graphics.rotate(angle)
love.graphics.scale(2, 2)
-- draw here, affected by the transform above
love.graphics.pop()           -- restore
```

Camera systems are just translate/scale math. Always pair push/pop.

## Canvases: draw offscreen, then reuse

A canvas is a drawable image you render into once and reuse — good for
static backgrounds and post-processing:

```lua
local canvas = love.graphics.newCanvas(960, 640)
love.graphics.setCanvas(canvas)
-- draw the static scene here
love.graphics.setCanvas()     -- back to the screen
-- later: love.graphics.draw(canvas, 0, 0)
```

Size canvases from **pixel** dimensions on high-DPI screens (below).

## Text and fonts

```lua
local font = love.graphics.newFont("assets/font.ttf", 24)
love.graphics.setFont(font)
```

`love.font` handles rasterization; `love.graphics.newFont` is the usual
entry point.

## One resolution for every screen

Phones and desktops have wildly different screen sizes. The standard
community practice (see the `lovesize` library README — community
practice, not official wiki canon):

1. Pick a fixed **virtual resolution** for your game, e.g. 960x640.
2. On `love.resize(w, h)`, compute a uniform scale to fit the real
   window, letterboxing/pillarboxing the leftover bars.
3. `love.graphics.scale(s, s)` at the start of `love.draw()`.
4. Convert pointer/touch positions back by dividing by `s` and
   subtracting the bar offset.

Write all game logic in virtual coordinates; only the final transform
knows about the real screen. For pixel art, use integer scales with
nearest-neighbor filtering.

`love.resize(w, h)` fires on desktop window resizes **and** phone
rotations. `love.displayrotated(orientation)` also fires on rotation
(since 11.3).

## High-DPI and phone screens

- `t.window.highdpi = true` and `t.window.usedpiscale = true` in
  conf.lua let LÖVE use the full pixel density.
- `love.window.getDPIScale()` returns the scale factor.
- `love.window.toPixels(x)` / `fromPixels(x)` convert between logical
  units and real pixels.
- Rule: game logic in logical coordinates; pixel-sized resources
  (canvases) allocated from pixel dimensions.

## Notches and safe areas

On phones, `love.window.getSafeArea()` returns the rectangle not covered
by notches or cutouts — keep HUD and buttons inside it. See
`love2d-platforms` for the known Android fullscreen caveat.

## Shaders and video, briefly

- `love.graphics.newShader(code)` — GLSL pixel/vertex shaders for
  effects. One shader is usually enough to start.
- `love.video` plays video files as drawable objects. Disable with
  `t.modules.video = false` if unused.

## Performance notes

- Batch draws: fewer `draw` calls and fewer state changes
  (`setColor`, `setShader`) is faster than micro-optimizing Lua.
- Do not create images, fonts, or canvases inside `love.draw` — create
  once in `love.load`.
- On phones, prefer `vsync = 1` and avoid per-frame allocations; see
  `love2d-platforms`.
