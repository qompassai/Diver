---
name: love2d-distribute
description: Package and ship a LÖVE game — .love files, fused Windows
  executables, macOS app bundles, Linux builds, Android APK/AAB, and iOS
  via Xcode. Use when turning a finished LÖVE project into something
  players can download and run on a specific platform.
---

> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.

# Distributing a LÖVE game

Run-time platform behavior is `love2d-platforms`. This skill is the
packaging side: turning your project folder into downloadable artifacts
per target.

## The .love file: the universal starting point

A `.love` file is a **ZIP** of your game's files with `main.lua` at the
archive root. Zip the *contents* of the project folder, not the folder
itself:

```text
cd my-game && zip -9 -r ../my-game.love . -x ".*"
```

`love my-game.love` runs anywhere LÖVE is installed. Every platform
recipe below starts from this file.

Reference: <https://love2d.org/wiki/Game_Distribution>

## Windows: fused executable

Fuse the game into `love.exe` so players need no separate install:

```text
copy /b love.exe+my-game.love my-game.exe
```

Ship alongside it: the LÖVE DLLs, `license.txt`, and your game's
assets. The LÖVE binaries' architecture (32/64-bit) must match the
target machines. `t.console = true` in conf.lua opens a debug console —
useful for testing, off for release.

## macOS: app bundle

1. Take the official `love.app`.
2. Copy `my-game.love` into `love.app/Contents/Resources/`.
3. Rename the app, edit `Info.plist`: `CFBundleIdentifier` (your unique
   id, e.g. `com.example.mygame`), `CFBundleName`, and set your icon.
4. For distribution outside your own machine: code-sign and notarize
   with Apple, or Gatekeeper will block it.

## Linux

Options, simplest first:

- Ship the `.love` file and depend on the player's installed LÖVE.
- Ship an **AppImage** bundling LÖVE + your `.love` for one-file runs.
- Distro packages (`.deb`, etc.) for repository distribution.

## Android: APK / AAB via love-android

Official route is the **`love-android`** repository:

1. Put your project (or `my-game.love`) into `app/src/embed/assets`.
2. Gradle flavors build the artifacts, e.g. `assembleEmbedNoRecordRelease`
   produces a release **APK**, `bundle…Release` produces an **AAB** for
   the Play Store.
3. Orientation, permissions, and icons live in the gradle/manifest side
   — there is no conf.lua orientation key (see `love2d-platforms`).
4. Sign the release build with your keystore before publishing.

## iOS: Xcode project

Requires macOS + Xcode:

1. Use the LÖVE iOS source with Apple's dependency libraries in an
   Xcode project.
2. Copy `my-game.love` into the app bundle's resources.
3. Configure the target: bundle identifier, display name, supported
   orientations, icons, signing team.
4. Build for simulator (testing) or device, then archive to a signed
   `.ipa` for TestFlight / the App Store.

## Checklist before you ship

- Target LÖVE **11.5** and test the exact binaries you ship — fused and
  store builds can behave differently from `love my-game/`.
- Disable unused modules in conf.lua (`t.modules.* = false`) to slim
  mobile builds.
- Test on a real phone: touch targets, safe area, rotation, low-memory
  behavior (`love.lowmemory`), and battery/thermal throttling over a
  long session.
- Include licenses: LÖVE's license files ship with fused/bundled builds.
