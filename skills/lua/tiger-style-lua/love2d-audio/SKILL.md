---
name: love2d-audio
description: Sound and assets in LÖVE — sound effects, streaming music,
  volume control, and loading files with love.filesystem. Use when adding
  audio to a LÖVE game, organizing assets, or handling save data.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE audio and assets

## Sound effects vs music: static vs stream

`love.audio.newSource(path, type)` takes a type that decides how the
sound is loaded:

- **`"static"`** — fully decoded into memory. Use for short sound
  effects (jump, hit, click). Fast to replay, costs RAM.
- **`"stream"`** — decoded while playing. Use for music and long audio.
  Tiny memory footprint, slight CPU cost.

```lua
local jump = love.audio.newSource("assets/jump.wav", "static")
local music = love.audio.newSource("assets/theme.ogg", "stream")

function love.load()
  music:setLooping(true)
  music:play()
end

function love.keypressed(key)
  if key == "space" then
    jump:play()   -- replaying a static source restarts it
  end
end
```

Useful source methods: `play`, `stop`, `pause`, `setVolume`,
`setLooping`, `isPlaying`, `setPitch` (pitch up for variety on repeated
SFX — cheap and effective).

Master volume: `love.audio.setVolume(0.5)`. Positional 3D audio exists
via `setPosition` on sources and a listener, but most 2D games never
need it.

Reference: <https://love2d.org/wiki/love.audio>

## Keep audio light on phones

- Prefer `.ogg` (vorbis) for music: small files, streams well.
- Keep SFX short; a dozen static sources is fine, hundreds is not.
- Drop and re-create audio on `love.lowmemory()` if you cache aggressively
  (see `love2d-platforms`).

## Assets: love.filesystem

`love.filesystem` reads game files and writes save data. Two roots:

- **Game directory** (read-only): where `main.lua` lives, including
  inside a `.love` zip.
- **Save directory** (read/write): named by `t.identity` in conf.lua —
  the right place for saves and settings on every platform.

```lua
local data = love.filesystem.read("assets/levels/1.json")
love.filesystem.write("save.json", serialized)
```

`love.filesystem.mount` can mount extra zips at runtime (DLC-style
content packs). `love.image` decodes image pixel data, `love.sound`
decodes/manipulates sound data, and `love.data` handles encoding,
compression, and hashing (handy for save checksums).

Reference: <https://love2d.org/wiki/love.filesystem>

## Slim the build

Every enabled built-in module ships with your game. In conf.lua, switch
off what you do not use — it measurably shrinks mobile builds:

```lua
t.modules.physics = false
t.modules.video = false
t.modules.joystick = false
```

Only disable modules you are sure are unused; a missing module fails
loudly at the first call.
