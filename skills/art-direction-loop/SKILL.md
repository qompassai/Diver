---
name: art-direction-loop
description: "Iteratively art-direct AI-generated artwork to a keeper: establish style-authority references, chain focused edits via media.generate_image snapshot resumption, keep a recorded keeper chain (path + snapshot ID + SHA-256), and present every version phone-readable. Trigger when Matt asks to create, refine, or iterate on title art, key art, or any generated image."
license: Apache-2.0
compatibility: The `media.generate_image` tool with snapshot resumption; image review via muse.read. No repo writes — deliverables live in ~/workspace/<topic>/.
metadata:
  domain: game-art
  toolchain: media.generate_image
allowed-tools: Read Write Bash
---

# Art-Direction Loop

Turn a vague "make me title art" into a converged keeper through tight,
recorded iteration. The loop exists because unguided regeneration drifts:
every edit must chain from the last accepted snapshot, change one thing,
and be recorded — otherwise you redo rejected experiments forever.

Plain-English version: you agree on the style first, then make one small
change at a time, keep a written record of every version that worked, show
each one so it reads on a phone, and stop when the user says keeper.

## 1. Establish style authority first

Before generating anything, collect the reference images that define the
look (user-supplied art, prior keepers, style refs). Record for each:

- File path
- `snapshot_id` (if it came from `media.generate_image`)
- SHA-256 hash (so a later session can verify it is the same bytes)

These references outrank your taste. When an edit drifts from them, the
references win.

## 2. Iterate with snapshot chaining

- Every edit call passes `resume_from_snapshot_id` pointing at the last
  **accepted** snapshot — never at a rejected one.
- **One focused change per edit.** "Make the streams terminate at the
  frame corners" is one change; "…and also change the sky" is two — split
  them. Single-change edits are reviewable; multi-change edits are not.
- Name each generation (`name` param) for the change it makes, and save
  under `~/workspace/<topic>/`.

## 3. Keep the keeper chain

Every accepted version gets one line in your notes (and in the final
report):

```
<file path> | snapshot <id> | SHA-256 <hash> | what changed
```

The latest keeper is the only resume point. Rejected versions are kept on
disk but never resumed from.

## 4. Present phone-readable

Matt reviews on his phone. Every version is shown inline (sandbox link)
with a one-line note of what changed — no walls of text between him and
the image.

## 5. Convergence rules (learned the hard way)

- **Lock typography/logo before composition.** Typeface and logo treatment
  settle first; background and effects iterate around them.
- **Effects terminate at frame boundaries.** Beams, streams, and circuit
  traces plug into the logo's frame and stop there — nothing crosses into
  the title interior. The title area stays clean and dark so the lettering
  reads at a glance.
- **Character consistency is a contract.** Once the user approves a detail
  (a hairstyle, an outfit, a palette), every subsequent edit preserves it —
  restate it in each prompt.
- **Density vs. readability is the eternal tradeoff.** When the user asks
  for more density, add it *around* the focal elements, never *through*
  them.
- **Report misses honestly.** If the edit did not do what was asked (e.g.
  traces still cross the letters), say so, show it, and run a corrective
  pass — never present a miss as a hit.

## 6. Rejected experiments

Note each rejection briefly — what was tried, why it was rejected — so a
later session does not re-propose it. Example: "fiber-orb moon replacement
— rejected, read as a sci-fi planet, not telecom"; "glass-prism moon —
rejected, spectrum beams washed across the title."

## 7. Never touch a repo

Artwork deliverables live in `~/workspace/<topic>/` only. Promoting art
into a game repo (or committing/pushing it) needs its own explicit
authorization — it is never part of this loop.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. This skill ships no bundled resources, so the envelope
carries an empty manifest:

<skill_resources>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** not recommended. The loop is a tight
  user-feedback cycle; each iteration needs the user's eyes. Keep it in the
  main session.
