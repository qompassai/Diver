---
name: love2d-physics
description: 2D physics in LÖVE with love.physics (Box2D) — worlds, bodies,
  shapes, fixtures, joints, and collision callbacks. Use when a LÖVE game
  needs rigid-body physics, collisions, or joints; skip it for simple
  arcade movement (use love.math + love.timer instead).
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE physics

`love.physics` wraps **Box2D**, a 2D rigid-body physics engine. It gives
you gravity, collisions, friction, and joints. It is heavier than
hand-rolled movement — only reach for it when you need real physics
(platformers with slopes, ragdolls, stacked objects, rope joints).

Reference: <https://love2d.org/wiki/love.physics>

## Core pieces

- **World** — the simulation. Has gravity, steps forward in time.
- **Body** — a thing with position/velocity. `static` (never moves:
  ground, walls), `dynamic` (fully simulated: crates, player),
  `kinematic` (moves by velocity, ignores forces: platforms).
- **Shape** — the collision outline attached to a body: rectangle,
  circle, polygon, edge, chain.
- **Fixture** — glues a shape to a body and holds friction, density,
  restitution (bounciness).
- **Joint** — constrains bodies together: revolute (hinge), distance
  (rope), prismatic (slider), and more.

```lua
local world

function love.load()
  world = love.physics.newWorld(0, 500) -- gravity: x=0, y=500 px/s^2

  local ground_body = love.physics.newBody(world, 400, 550, "static")
  local ground_shape = love.physics.newRectangleShape(800, 50)
  love.physics.newFixture(ground_body, ground_shape)

  local crate_body = love.physics.newBody(world, 400, 100, "dynamic")
  local crate_shape = love.physics.newRectangleShape(40, 40)
  love.physics.newFixture(crate_body, crate_shape, 1) -- density 1
end

function love.update(dt)
  world:update(dt)
end
```

## Step the world on a fixed timestep

Variable `dt` makes physics nondeterministic and can explode at low
frame rates. Accumulate real time and step in fixed chunks:

```lua
local accumulator, STEP = 0, 1 / 60

function love.update(dt)
  accumulator = accumulator + math.min(dt, 0.1) -- cap huge gaps
  while accumulator >= STEP do
    world:update(STEP)
    accumulator = accumulator - STEP
  end
end
```

## Collision callbacks

```lua
world:setCallbacks(begin_contact, end_contact)

local function begin_contact(a, b, contact)
  -- a and b are the two fixtures that touched.
  -- Use fixture:getUserData() to tag "player", "coin", etc.
end
```

Tag fixtures with `fixture:setUserData("player")` and branch on the tags
— the standard pattern for hit detection, pickups, and triggers.

## Units and scale

Box2D is tuned for **meters**, not pixels: it behaves best with objects
roughly 0.1–10 units in size. Common practice is a scale factor (e.g. 30
pixels = 1 meter): divide positions going in, multiply coming out. This
is community practice rather than engine law, but skipping it is the
usual cause of jittery, floaty-feeling physics.

## When NOT to use physics

Top-down shooters, puzzle games, simple jump arcs, and anything tile-
based are usually simpler, faster, and easier to tune with direct
movement (`x = x + vx * dt`) plus `love.math` for randomness and noise.
Physics shines when objects must plausibly push, stack, swing, or bounce
off each other.

## Cost on phones

Physics worlds cost CPU every step. Keep body counts modest on mobile,
cap the accumulator (as above) so backgrounding the app cannot spiral,
and consider `t.modules.physics = false` in conf.lua for games that do
not need it at all.
