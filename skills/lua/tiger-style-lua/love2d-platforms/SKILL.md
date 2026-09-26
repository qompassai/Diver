---
name: love2d-platforms
description: Run-time platform alignment in LÖVE — Windows, macOS, Linux
  desktop vs Android and iOS phones. OS detection with love.system.getOS,
  safe areas and notches, rotation, memory pressure, and per-platform
  config. Use when a game must behave correctly across desktop and phone,
  or when branching logic per operating system.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# LÖVE platforms: desktop vs phone

One LÖVE codebase runs on five targets, but desktop and phones differ in
input, screen, performance budget, and OS services. This skill is the
run-time side (what the game does while running). Packaging each target
is `love2d-distribute`.

## Which OS am I on?

```lua
local os = love.system.getOS()
-- 11.5 return values:
--   "Windows"   "OS X"   "Linux"   "Android"   "iOS"
```

Note: on 11.5 macOS reports as **`"OS X"`**, not `"macOS"`. Write the
check exactly:

```lua
local OS = love.system.getOS()
local on_phone = OS == "Android" or OS == "iOS"
local on_desktop = not on_phone
```

Branch sparingly — prefer capability checks (touch available? gamepad
connected?) over OS checks. Use OS checks for things that truly differ
per platform: file paths, store links, platform-specific settings
screens.

## Desktop vs phone architecture

| Concern | Desktop (Win/Mac/Linux) | Phone (Android/iOS) |
|---|---|---|
| Input | keyboard, mouse, gamepad | touch first; gamepad sometimes |
| Hover | exists | does not exist |
| Screen | resizable window, many sizes | fixed-ish, notch, rotation |
| Performance | generous | budget thermals/battery; fewer bodies, fewer draw calls |
| Interruptions | rare | calls, app switching — handle suspend |
| Storage | save dir on disk | save dir, may be cleared; `t.externalstorage` (Android) |

Performance habits that matter most on phones:

- `vsync = 1` and let the display pace the loop; do not busy-wait.
- Cap `dt` (`math.min(dt, 0.1)`) so a hitch cannot spiral the simulation.
- Do not allocate per frame — reuse tables, create assets in
  `love.load`.
- Keep physics body counts modest; disable unused modules in conf.lua.

(The wiki does not publish official battery guidance; the above is
standard mobile practice, not quoted official advice.)

## Phone screens: safe area, rotation, DPI

```lua
-- Rectangle not covered by notch/cutout: keep HUD and buttons inside it.
local x, y, w, h = love.window.getSafeArea()
```

- `love.resize(w, h)` fires on rotation and window resize — recompute
  your virtual-resolution scale there (see `love2d-graphics`).
- `love.displayrotated(orientation)` fires on device rotation (11.3+).
- High-DPI: `love.window.getDPIScale()`, `toPixels`/`fromPixels`; keep
  logic in logical coordinates (see `love2d-graphics`).
- Known issue (flag, not settled fact): an open love-android issue
  reports `getSafeArea()` crashing with fullscreen on some Android
  devices on 11.4/11.5; the observed workaround is querying the safe
  area before entering fullscreen.

## Memory pressure and interruptions

```lua
function love.lowmemory()
  -- Mobile OS is asking for memory back. Drop caches you can rebuild:
  -- image caches, decoded audio, generated canvases.
end
```

`love.lowmemory` fires on mobile memory pressure — implement it if you
cache aggressively. Also handle `love.focus(false)` (app backgrounded):
pause the game and mute audio; resume on `love.focus(true)`.

## OS services: love.system

- `love.system.openURL("https://...")` — open store page / help in browser.
- `getClipboardText` / `setClipboardText` — desktop-centric; mostly
  absent on phones.
- `love.system.getPowerInfo()` — charging/battery state; consider
  lowering effects when unplugged on phones.
- `love.system.vibrate(seconds)` — phones only, guarded by capability.
- `love.system.getLocale()` — for language selection.

Reference: <https://love2d.org/wiki/love.system>

## Per-platform conf.lua notes

- `t.console` — Windows only.
- `t.accelerometerjoystick` — mobile only (tilt as joystick).
- `t.externalstorage` — Android only (save to external storage where
  supported).
- **Orientation has no conf.lua key.** Set it in the Android
  manifest/gradle config (love-android side) and in the iOS Xcode
  project. Do not invent a `t.window.orientation`.
- `t.window.highdpi` / `usedpiscale` matter most on phones and Retina
  Macs.

Full option list: <https://love2d.org/wiki/Config_Files>
