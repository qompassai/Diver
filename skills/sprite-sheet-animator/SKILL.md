---
name: sprite-sheet-animator
description: "Animate 2D character sprite sheets: derive visually consistent animation frames (idle loops, mood variants) with the vs-lightshow VoidSprite plugin or pixel editing, pack cell-grid sheets with aseprite's batch CLI, and keep the game's TextureAtlas mood-row indexing intact. Trigger when Matt asks to animate sprites, add character emotions or idle animations, or build sprite sheets for a game."
license: Apache-2.0
compatibility: Aseprite 1.3+ CLI and VoidSprite (with the vs-lightshow plugin installed) on the build machine — probed at runtime, never assumed. Art and export work runs on primo via ~/workspace/bin/primo-ssh.
metadata:
  domain: game-art
  toolchain: aseprite, voidsprite
  spec: https://www.aseprite.org/docs/cli/
allowed-tools: Read Edit Bash
---

# Sprite-Sheet Animator

> **Prerequisite:** `tiger-style-aseprite` (sibling skill) — apply it first.
> Every aseprite invocation below follows its batch contract: probe the
> binary, argv arrays, `-b`, correct option ordering, bounded timeouts,
> exit-code checks, output verification, temp-file hygiene.

Turn a static character portrait into an animated sprite sheet the game can
actually index. The pipeline exists because a sheet that looks right but
breaks the game's frame indexing is worse than no sheet at all: art and
atlas layout are designed together, never separately.

Plain-English version: you take the game's companion portrait, figure out
which emotions the game actually triggers (from its code, not your
imagination), draw a few frames for each emotion where only the animated
parts move, and pack them into the exact grid the game expects — then prove
the game still indexes every frame correctly.

## 1. Learn the game's real conventions first

Read the game's sprite-loading code before touching any art. You need four
facts, all from source:

1. The atlas layout: cell size, grid dimensions, and what each row/column means.
2. The mood/emotion enum and its exact row mapping.
3. The animation timing (frame duration, loop mode).
4. The asset path convention (one sheet per character, shared layout or per-character).

Worked example — light-show, verified 2026-09-30 (atlas code in
`game/src/waifu/sprite.rs`; per-character sheet notes in
`game/assets/sprites/<name>/README.md`):

- One 384x1152 sheet per companion (`<name>_sheet_fullbody.png`): **6 mood
  rows x 4 frames**, 96x192 cells. The original 256x384 bust sheets (64x64
  cells) are legacy — still in the tree, no longer the pipeline.
- `Mood` enum to sheet row: Idle=0, Blush=1, Wink=2, Pout=3, Celebrate=4, Alarmed=5.
- Companion mapping: Fiber->seraphine, Coax->ondine, Mobile->linka, Ethernet->lattice.
- Frame timer 180ms repeating; full-body sprites drawn at 3.0x scale.
- Visual convention (observed in the shipped PNGs): dark background, a
  mood-colored bar along the bottom of each cell (6px on lattice's sheet,
  blue `#4cc9f0`; the alarmed row uses red), color identity per character.
- Variant sets keep the identical grid so they stay drop-in compatible
  (e.g. `<name>_sheet_fullbody_mature.png` — same outfits/accessories/
  palettes, adult proportions and faces).

If the game has no such code yet, define the layout with Matt first and
write it down in the repo's art-style doc — the layout is a contract, not
an accident.

## 2. Design the emotion set from the game's triggers

The emotion set comes from the game's mood enum and its dialogue/emotion
triggers, never invented in a vacuum. For light-show's companions the
mapping is:

| Game mood (row) | Animation | Trigger source |
| --- | --- | --- |
| Idle (0) | Breathing bob + blink, 4 frames | default state |
| Blush (1) | Idle + cheek blush overlay, 4 frames | reserved (affectionate dialogue) |
| Wink (2) | Wink + sparkle, 4 frames | outage resolved; playful/teasing lines |
| Pout (3) | Frown + half-lidded eyes, 4 frames | high attenuation (bad termination); messy-splice lines |
| Celebrate (4) | Personality celebrate, 4 frames | level win, clean punch-down; level-win lines |
| Alarmed (5) | Red wash + wide eyes + `o` mouth, 4 frames | outage start; high-attenuation lines |

Personality celebrates (landed 2026-09-30 — keep them stable across variant
sets): Séraphine wink+spin (a flipped frame reads as a twirl), Ondine a
single modest hop, Linka a rapid double bounce, Lattice a fist-pump.

Dialogue lives in `game/assets/dialogue/<name>_en.json` with compiled banks
in `dialogue.rs` (8 event keys x 3 in-voice lines per companion) — read
both when designing mood beats.

For a new game: enumerate its actual states first, then assign one
animation per state. One row per emotion, every row the same frame count —
uniform grids are what `TextureAtlasLayout::from_grid` expects.

## 3. Derive frames — consistency is the hard requirement

Frames come from the vs-lightshow VoidSprite plugin (see §7), pixel
editing, or AI-assisted generation. The method is your judgement call; the
requirement is not: **frames within one character must stay visually
consistent** — same face, same hair, same outfit. Only the animated parts
move (eyes for a blink, mouth for a smile, whole-body offset for a hop). A
Celebrate frame where the character's hair color drifts is a failed frame,
not a variant.

Plugin workflows that already work:

- **Blink:** duplicate the idle base frame, run the filter
  "Light-show: blink eyes" with `blink amount %` across the copies
  (e.g. 0 → 60 → 100 → 60), setting the two eye boxes to the character's
  eye rects. Works for visor characters too — it squashes existing pixels,
  never fills skin.
- **Breathing:** run the filter "Light-show: breathing shift" with
  `shift px` of +2 / 0 / -2 / 0 across four frame copies for the idle bob.

Rules:

- Keep every design original. OSP/fiber-optic motifs (hair like fiber
  strands, connector hairpins, light motifs) are welcome; copying existing
  characters or IP is never acceptable.
- Work at the game's native cell size (96x192 full-body for light-show).
  Do not draw big and downscale unless the game's pipeline already does —
  resampling changes pixel art.
- Keep the established per-sheet visual conventions (dark background,
  bottom mood bar per row) so new sheets sit beside old ones without a
  visible seam.
- Ship the editable `.aseprite` project beside the PNG: 24 frames, one tag
  per mood row, tag name == mood name, frames in tag order == playback
  order. The project's export must round-trip pixel-identical to the
  shipped PNG (verified for the landed set).
- Name frames so the pipeline stays auditable:
  `<character>_<mood>_<nn>.png`, e.g. `seraphine_celebrate_02.png`.

## 4. Aseprite batch pipeline

All aseprite work follows the tiger-style-aseprite contract. The shape that
is established in this setup (diver's `games/aseprite` wiring):

```bash
# probe — record the winning binary and version, never assume
aseprite --version
```

```bash
# pack one mood tag's frames into the sheet grid (argv array, one element
# per argument; selection options BEFORE the input file, sheet/export
# options AFTER it — order is load-bearing)
aseprite -b --tag celebrate frames.aseprite \
  --sheet seraphine_sheet_fullbody.png --data seraphine_sheet_fullbody.json \
  --format json-array --sheet-type rows \
  --sheet-columns 4 --sheet-rows 6
```

- `--sheet` **overwrites** its output — never point it at an original.
- `--split-tags` exports each mood tag to its own file when you want
  per-emotion sheets instead of one grid.
- Integer `--scale` only; fractional scale factors are unverified upstream.
- Bounded timeout (default 120 s for exports), check the exit code, verify
  the PNG and JSON exist after exit 0, clean up temp scripts on both paths.

Frame tags in the `.aseprite` source are the source of truth for mood
boundaries: one tag per emotion, tag name == mood name, frames in tag
order == playback order. The sheet is a build artifact of the tagged
source, not the other way around.

## 5. Sheet conventions

- Fixed cell size across every character in the game (96x192 full-body in
  light-show; the 64x64 bust sheets are legacy).
- One sheet per character, identical grid for all characters — the game
  builds a single shared `TextureAtlasLayout`.
- Dark background + bottom mood bar per row (light-show convention);
  document any new game's conventions in its art-style doc.
- Ship the `--data` JSON beside the PNG so frame metadata stays with the
  art. (The vs-lightshow exporter's JSON sidecar documents the same
  contract — see §7.)
- Variant sets (`_mature`, future others) reuse the identical grid so they
  are drop-in compatible.

## 6. Atlas compatibility — never break indexing silently

Before changing any frame layout, re-read the game's atlas construction
(light-show: `game/src/waifu/sprite.rs`,
`TextureAtlasLayout::from_grid`). The checklist:

1. Grid dimensions unchanged (4 cols x 6 rows of 96x192) unless the layout
   constructor is updated in the same change.
2. Row order matches the mood enum exactly — reordering rows without
   updating the row mapping silently shows the wrong emotion.
3. Frame count per row matches what the animation timer cycles through.
4. New sheet loads in-game (or in a headless atlas-index smoke test)
   before the old file is replaced.

Honest boundary: light-show builds its atlas purely from Rust constants —
no JSON is parsed at runtime. Exported JSON sidecars document the contract
for tooling and humans; the code is the authority.

If the layout must change, the code change and the art change ship
together, and the art-style doc is updated in the same pass.

## 7. Tools

- **VoidSprite + vs-lightshow plugin** (`/usr/bin/voidsprite` on primo,
  package `voidsprite-git`, verified 2026-09-30; plugin at
  `~/.config/voidsprite/plugins/vs_lightshow.so`, source at
  `/home/phaedrus/vs-lightshow/` on primo). Use for pixel-level frame
  editing, blink/breathing generation, and animation preview. The plugin
  adds:
  - Filter "Light-show: blink eyes" — eye-box squash with real dialog
    parameters (`left/right eye x/y/w/h`, `blink amount %`).
  - Filter "Light-show: breathing shift" — vertical shift with edge
    replication (`shift px`).
  - Editor action "Light-show: export sheet + JSON" — packs session frames
    into `<basename>.png` plus a JSON sidecar documenting the pipeline
    contract; layout from `~/.config/voidsprite/lightshow_export.cfg`
    (defaults = the landed 96x192, 4x6, 180ms,
    idle/blush/wink/pout/celebrate/alarmed contract; missing file =
    defaults, any parse error aborts with a notification).
- **Aseprite** (`/usr/bin/aseprite` on primo, verified 2026-09-30) — the
  batch packing/export workhorse: headless Lua sheet assembly, `--sheet`
  export, tag-driven mood boundaries. Probe at runtime per the contract —
  paths drift.
- **LibreSprite** is not API-compatible with Aseprite 1.3 scripts/flags;
  consult the divergence table in
  `tiger-style-aseprite/references/aseprite-scripting-api.md` before
  running this pipeline against it.

## 8. Delivery

- Write **new** files (`<name>_sheet_fullbody_mature.png`, never overwrite
  the shipped `<name>_sheet_fullbody.png`) so the game keeps working while
  Matt reviews.
- No commit, no push without Matt's explicit one-time go-ahead naming the
  files. Delivery is files for review, not a silent replacement.
- Report per character: animations built, frame counts and layout, how
  frames were derived, the exact export commands, and what the game needs
  to consume the new sheets.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended. Animating one character end to end
  (emotion mapping → frame derivation → aseprite packing → atlas check) is
  a bounded deliverable per character; delegate one character per worker
  and keep the shared layout contract in every brief.
