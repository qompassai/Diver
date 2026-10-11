---
name: mature-avatar-pipeline
description: "Build mature-appearance full-body sprite variants with Aseprite-native Lua: write and gate the Lua helpers first, trial on one character with pixel-identical round-trip and adversarial cases, compare honestly against the reference implementation with pixel-diff stats, and run the fleet only after explicit user approval. Trigger when Matt asks for mature variants of the Light Show companions or to run/extend the mature pipeline."
license: Apache-2.0
compatibility: Aseprite 1.3+ CLI on the build machine (probed at runtime, never assumed); Lua 5.3 for script gating. Art and batch work runs on primo via ~/workspace/bin/primo-ssh.
metadata:
  domain: game-art
  toolchain: aseprite
  spec: https://www.aseprite.org/docs/cli/
allowed-tools: Read Write Bash
---

# Mature-Avatar Pipeline

Produce drop-in mature-appearance variants of the companion sprite sheets
— same outfits, accessories, palettes, hairstyles, and atlas grid; adult
proportions and faces — using Aseprite-native Lua instead of an external
pixel pipeline. The pipeline exists because a variant that is 99% right
but shifts one pixel row breaks the game's atlas indexing; helpers are
proven on one character before the fleet ever runs.

> **Prerequisites:** `tiger-style-aseprite` first (batch contract, CLI flag
> order, Lua script contract), then `tiger-style-lua` for the helpers.

> **Status 2026-09-30:** the helper script and the Séraphine trial are
> complete and verified. The fleet run on lattice, linka, and ondine is
> **still pending Matt's explicit go-ahead** — do not start it on your own
> authority.

Plain-English version: you write the pixel-morphing scripts first and
prove they are safe, test them end to end on one character, measure exactly
how close the result is to the old pipeline's output, show a comparison the
user can read on his phone — and only then, with his word, run the rest.

## 1. Write the Lua helpers first

No character is touched until the helpers exist. Every helper script must
satisfy the `tiger-style-aseprite` Lua script contract (batch mode, no UI,
`app.params` input, transactions, version guards).

- **Gate:** `luac5.3 -p` (Lua 5.3, matching Aseprite's embedded runtime)
  must be clean on every script before it ever runs under Aseprite.
- **Known platform finding (Aseprite 1.3.18.6-dev, API 41):**
  `Image:resize()` behaved as nearest-neighbor regardless of the method
  string passed. Do not trust the method parameter — if you need bicubic or
  Lanczos-3, implement the filter in Lua and verify the output against a
  reference. Re-probe on newer Aseprite before assuming this is fixed.

## 2. Trial on ONE character in scratch space

Pick one character (Séraphine was the trial subject). Run headless:

```
aseprite -b <input.aseprite> --script mature_variant.lua --script-param ...
```

Verify the full contract before anything else:

- **Tags:** exactly the 6 expected tags — `idle`, `blush`, `wink`,
  `pout`, `celebrate`, `alarmed`.
- **Frames:** 24 frames, correct durations (0.18 s each in the trial).
- **Round-trip:** export PNG → reimport → compare against the `.aseprite`
  render. Must be **pixel-identical**. Any difference is a pipeline bug,
  not noise.

## 3. Adversarial cases

Feed the script malformed inputs (missing sprite, wrong color mode,
missing params, out-of-range values) and verify each is rejected with a
**precise error message** and **no stray output files**. A script that
fails messily in batch mode will poison a fleet run silently.

## 4. Compare against the reference — honestly

If a reference implementation exists (the Python pipeline in the trial),
diff its output against the Aseprite output over **all** pixels and
report:

- % of pixels exactly equal
- maximum absolute channel difference
- mean absolute difference
- count of pixels differing by more than 5

Trial numbers (Séraphine, 442,368 px): 53.813% exact, max abs diff 10,
mean diff 0.238, 190 px differed by more than 5, none by more than 10.
Report the numbers you get — never claim parity the numbers do not
support. Small systematic differences (resampling kernels, rounding) are
expected; unexplained large ones are not.

## 5. Phone-readable comparison, then fleet approval

Build a side-by-side montage (standard vs. reference-mature vs.
Aseprite-mature) the user can read on his phone. The fleet run on the
remaining characters happens **only after explicit user approval** of the
trial — and the script is committed/pushed only with its own
authorization.

## 6. Atlas contract is sacred

Variant sheets keep the identical grid as the base sheets (light-show:
96x192 cells, 4 frames/row, 6 mood rows) so they stay drop-in compatible.
PNG and the game's Rust constants are authoritative; JSON sidecars are
documentation only. Never add a runtime variant selector without new
authorization.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended. The trial is one bounded
  deliverable; each fleet character is one bounded deliverable per worker.
  Keep the atlas contract and the approval gate in every brief.
