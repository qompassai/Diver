---
name: frontend-design
description: Distinctive visual design for Matt's HTML report briefs, review packs, and rose.nvim UI surfaces — the artifacts he reads on his phone. Replaces templated AI-slop defaults (purple gradients, stock Inter, identical rounded cards, centered-everything layouts) with deliberate, opinionated choices in palette, typography, and layout grounded in the subject matter. Covers typefaces with personality, phone-first readability, self-contained offline single-file HTML, dark-mode sensibility, and a restraint-and-self-critique pass. Reach for it whenever an HTML artifact or UI surface needs aesthetic direction, a generated page looks generic, or type and layout choices need a second opinion.
license: Apache-2.0
compatibility: No toolchain required. Review the result in any browser or on a phone — a screenshot is enough to critique it. If the artifact must open offline (email attachment, zip, phone), keep it fully self-contained.
metadata:
  domain: visual-design
  surfaces: html-artifacts, rose-nvim-ui
  audience: phone-review
allowed-tools: Read Edit Bash
---

# Frontend Design

Matt's visual surface is small but real: single-file HTML report briefs and
review packs generated as files and reviewed on his phone, plus rose.nvim
in-editor UI surfaces, plus possible future web interfaces. He is usually his
own reviewer, so the bar is simple: **distinctive, not templated.** These
artifacts represent Qompass AI work; they should never read as generated.

## Principles

**Ground every choice in the subject matter.** A PQC benchmark report and a
game release brief should not look like each other. The subject's materials,
vernacular, and audience are where distinctive choices come from. Where the
brief pins a visual direction, follow its words exactly; where it leaves an
axis free, don't spend that freedom on a default.

**Hero first.** Open with the most characteristic thing in the subject's
world. For a report artifact that means the verdict or key finding up top —
not navigation chrome, not a decorative banner. Be deliberate about the
treatment: a big number with a small label plus a gradient accent is the
default, so only use it when it's truly the best option.

**Typography carries the personality.** One family or two; if two, clearly
distinct. Choose deliberately — never the default face you'd reach for on any
other project. Set a clear type scale with intentional weights and spacing.
Default to line lengths under 80 characters. Avoid the commonest tells of a
generated page: accenting a single word in a headline, ALL CAPS labels,
decorative eyebrow labels above content.

**Structure is information.** Borders, numbering, dividers, and labels encode
content; they don't decorate it. Numbered markers (01 / 02 / 03) are only for
real sequences — a stepped process, a timeline. Check the content actually is
a sequence before numbering it.

**No AI slop.** Current generated design clusters around defaults — cream
background with terracotta accent, near-black with acid green, broadsheet
hairlines, the SaaS kit of identical rounded cards with one soft shadow,
tracked-out ALL-CAPS eyebrows, middle-dot meta strings, `→` on every link.
Each is legitimate for some brief; none is a choice when it appears regardless
of subject. Spend boldness in one place: one memorable element, everything
around it quiet and disciplined.

## Built for his artifacts

- **Phone-first.** Readable at 360px wide, real contrast, tap targets at least
  44px, nothing that depends on hover — phones don't hover.
- **Self-contained single HTML.** Inline CSS, no CDN or webfont fetches. It
  must open offline from a zip or an email attachment.
- **Dark-mode sensibility.** Respect `prefers-color-scheme`, or commit to one
  deliberate scheme — don't land in unreadable middle ground.
- **Screenshot-robust.** His review loop is screenshots on a phone. Nothing
  that breaks outside a live viewport: no motion-dependent reveals, no
  viewport-height hero that hides the content.
- **Copy is design.** Plain verbs, sentence case, active voice. Name things by
  what the user understands, not how the system is built. Errors explain what
  went wrong and how to fix it, in the interface's voice.

## TUI transfer (rose.nvim)

The same principles apply in the terminal with a smaller palette. One
memorable element, quiet surroundings. "Typography" becomes discipline in
weight, color, and spacing. Structural devices encode state. No decoration
without a job — in a TUI every stray border is noise.

## Process: plan, then critique

Before writing code, sketch a compact token plan in a few lines: palette as
4–6 named hex values, typefaces and their roles, layout in one sentence.
Check the plan against the brief — if any part reads like the generic default
you'd produce for any similar page, revise it and say why. Then build.

Critique your own work before shipping: run
`scripts/check-self-contained.sh artifact.html` first — it fails the build
on external fetches or a missing viewport meta. Then take a screenshot and
review it like someone else's page. Responsive down to mobile, reduced motion respected,
visible keyboard focus, accessible contrast. Remove one accessory before you
leave the house.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. The envelope for this skill carries its bundled resources:

<skill_resources>
<file>scripts/check-self-contained.sh</file>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended for the validation pass. Draft the
  design in-session; delegate the build → screenshot → critique → revise
  loop to a focused session. It returns the final artifact plus a note on
  what the critique pass changed.
