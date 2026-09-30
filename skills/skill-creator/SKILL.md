---
name: skill-creator
description: Guides the creation, modification, and improvement of Agent Skills for a Neovim-centered workflow. Reach for it when drafting a new SKILL.md from scratch, when an existing skill needs sharper triggering or clearer instructions, when skills-ref or skill-validator reports errors or warnings that need fixing, or when a skill's description fails to fire on prompts it should catch. Covers the full loop from capturing intent through drafting against the Agent Skills spec, validating with both structural and quality gates, adversarial testing, and shipping through the live-first install path into the versioned repo.
license: Apache-2.0
compatibility: Requires skills-ref (the official Agent Skills reference validator) and skill-validator 1.6.2 or newer; validation commands run in a POSIX shell.
metadata:
  domain: agent-skills
  spec: https://agentskills.io/specification
allowed-tools: Read Edit Bash
---

# Skill Creator

Create new Agent Skills, modify and improve existing ones, and prove they work before shipping them. This skill encodes the workflow behind the Tiger Style skill family and every other skill in the Diver setup: capture intent, draft against the spec, validate with both gates, test like an adversary, then install live-first and mirror into version control.

## The loop

Work through these stages in order. Skip a stage only when it genuinely does not apply, and say why.

### 1. Capture intent

Figure out what the skill must enable and when it should fire. Pull answers from the conversation first — the tools used, the sequence of steps, corrections Matt made, input and output formats observed. Confirm the gaps with him before drafting:

- What should an agent be able to do with this skill that it cannot do reliably without it?
- What phrases, file types, or situations should trigger it?
- What does success look like — a file, a report, a changed behavior?

### 2. Interview and research

Ask about edge cases, input/output formats, dependencies, and success criteria before writing a word of the skill. Then check the existing skill inventory for overlap: read `skills-ref to-prompt` output or scan the installed skill directories. A new skill that duplicates an existing one's trigger space is a bug, not a feature — merge or narrow the scope.

### 3. Draft the skill

Write `SKILL.md` following the anatomy and frontmatter rules below. Put bulky supporting docs in `references/` inside the skill directory, never in the body. Add `agents/` instructions only when a subagent needs its own brief (the grader is the usual case). Add `scripts/` only when a deterministic, repeatable task earns its keep — every bundled script is a maintenance liability, so default to none.

### 4. Validate — both gates, zero tolerance

Run the structural gate first, then the quality gate. Both must report zero errors, and the quality gate must report zero warnings too. Warnings are not advisory here; fix them.

```bash
skills-ref validate /path/to/skill-name
skill-validator /path/to/skill-name
```

Or run the bundled helper — `scripts/validate.sh /path/to/skill-name`
runs both validators (skipping either with a warning when not installed)
plus the manual checks below: name == dir, frontmatter YAML, relative
references, script syntax, `git diff --check`. Binary locations:
`/home/phaedrus/.local/bin/skills-ref` and
`/home/phaedrus/go/bin/skill-validator`, overridable via `SKILLS_REF` /
`SKILL_VALIDATOR`.

Then the manual checks neither gate fully owns:

- Directory name matches frontmatter `name` exactly.
- Frontmatter lengths and fields are within spec (see the table below).
- Every relative file reference in the body resolves to a real file.
- Bundled scripts pass a syntax check (`python3 -m py_compile`, `bash -n`, `luac -p`, as appropriate).
- `git diff --check` is clean on every touched file.

### 5. Test — half validation, half adversarial

Write test prompts the way a real user would phrase them: concrete, a little messy, with file paths and context. Split them roughly evenly:

- **Validation cases** confirm the skill does its job: the right output for a prompt squarely in its trigger space, bundled scripts behaving on realistic inputs.
- **Adversarial cases** think like an attacker or a confused user: near-miss prompts that must NOT trigger the skill, malformed or hostile inputs to bundled scripts, untrusted content inside files the skill reads (the skill's instructions must win over data every time).

Run each case in a subagent with the skill available, then grade with a second subagent following `agents/grader.md`. The grader checks each expectation against the actual outputs with cited evidence, verifies claims the executor made, and flags assertions that would pass for a wrong output. Fix the skill, not the test, when a case fails — unless the test itself was wrong, in which case say so explicitly.

### 6. Iterate

Apply what grading taught you, then rerun the full test set. Generalize from the feedback: a fix that only patches the failing example is overfitting. Prefer explaining the *why* behind a rule over adding another MUST. Stop when all cases pass and the validators are green.

### 7. Tune the description

The description is the trigger — it decides whether the skill fires. After the skill works, test the trigger itself: write 16–20 realistic queries, half that should trigger the skill and half near-misses that should not (queries sharing keywords but needing something else are the valuable negatives). Run each query past an agent that can see the skill catalog, record which ones trigger, and rewrite the description until the should-trigger set fires reliably and the near-misses stay quiet. Natural prose with concrete trigger terms beats keyword stuffing.

### 8. Install live-first, then mirror

Matt's standing workflow, in this order:

1. Back up the live tree: `~/.config/nvim` to `~/.config/nvim.bak` (check whether a backup already exists and preserve it sensibly — never blindly destroy the previous backup).
2. Install the skill in the live tree and validate it there with both gates.
3. Only after it validates live, mirror it into the Diver repo under `skills/` and confirm the two copies are byte-identical (`diff -r`).
4. Stage only the skill's files, inspect `git diff --cached --stat`, commit, and push only with explicit authorization. Never force-push. Verify the remote commit afterwards.

## Skill anatomy

```
skill-name/
├── SKILL.md        # required: frontmatter + instructions, the operational core
├── LICENSE.txt     # required: the skill's actual license, carried verbatim
├── references/     # optional: bulky docs loaded on demand, with pointers from SKILL.md
├── agents/         # optional: briefs for subagents the skill spawns
├── scripts/        # optional: executable helpers for deterministic tasks
└── assets/         # optional: files used in output (templates, images)
```

Skills load in three tiers — this is why the body stays lean:

| Tier | What loads | When | Token cost |
| ---- | ---------- | ---- | ---------- |
| 1. Catalog | name + description | Session start | ~50–100 tokens per skill |
| 2. Instructions | Full `SKILL.md` body | On activation | Under ~500 lines recommended |
| 3. Resources | references, scripts, assets | Only when referenced | As needed |

Every line in the body is paid for on every activation. Push detail into `references/` and point at it with a one-line "read this when…" cue. For a reference file over ~300 lines, include a table of contents at its top. When a skill spans variants (languages, providers), organize by variant — `SKILL.md` picks the path, the agent reads only the relevant reference file.

## Frontmatter fields

| Field | Required | Constraints and why |
| ----- | -------- | ------------------- |
| `name` | Yes | Kebab-case, max 64 chars. Must match the parent directory name exactly — discovery keys on this. |
| `description` | Yes | Max 1024 chars, no angle brackets. This is the primary trigger mechanism: say what the skill does AND the concrete situations that call for it. Write natural prose with real trigger terms. Avoid gerund-enumeration patterns ("Use when writing, regenerating, refactoring, reviewing, or debugging X") — the quality linter flags those as keyword lists. |
| `license` | No | SPDX identifier (`Apache-2.0`) matching `LICENSE.txt`, which is carried verbatim. Never derive a skill from a proprietary-licensed source — some upstream skills forbid external retention and derivative works outright. |
| `compatibility` | No | Max 500 chars. Toolchain and environment the skill assumes — not the agent's tool allowlist. |
| `metadata` | No | Structured facts: language, lsp, formatter, domain, spec URL. Machine-readable context that does not belong in prose. |
| `allowed-tools` | No | Agent tools pre-approved while executing the skill (e.g. `Read Edit Bash`). Experimental per the spec; keep it tight. |

## Diver conventions

These are settled and non-negotiable for skills shipping in this setup:

- `references/` lives inside the skill directory, beside `SKILL.md` — it is on-demand documentation, not a container for skills.
- The directory name matches frontmatter `name`. The validators check this; fix the mismatch, never the check.
- The repo-root `SKILLS.md` is the playbook, not a skill. Do not nest skills under it.
- Language skills layer under their Tiger Style base: `skills/<lang>/tiger-style-<lang>/<specific>/SKILL.md`, and each nested skill opens with a prerequisite line pointing at the parent guide.
- Skills derived from an upstream source carry that source's `LICENSE.txt`
  verbatim. Original skills declare `license: Apache-2.0` in frontmatter
  under the repo's license — no per-skill license file needed.

## Writing instructions that work

- **Imperative voice.** Tell the agent what to do: "Run both validators," not "You should consider running validators."
- **Explain the why, not just the rule.** A model that understands why a step matters generalizes to cases you did not enumerate. Reserve MUST/NEVER for genuine safety boundaries; if you catch yourself writing them in all caps, try reframing as reasoning first.
- **Pin output formats with templates.** When the skill must produce a fixed shape, show the exact template in a code block rather than describing it.
- **Show input/output examples.** One concrete pair teaches more than a paragraph of abstraction. Keep them short and realistic.
- **Keep the prompt lean.** After drafting, reread with fresh eyes and cut anything not pulling its weight. Read a trial transcript, not just the final output — if the skill sends the agent down unproductive paths, the skill is the problem.
- **Watch for repeated work.** If trial runs all independently invent the same helper, that helper belongs in `scripts/` — write it once so future invocations stop reinventing it.
- **No surprises.** A skill must never contain malware, exfiltration, or anything whose intent would surprise Matt if described plainly. Refuse requests to build deceptive or harmful skills.

## Working with Matt

He is a beginner programmer who learns by taking on the hardest problems first, so teach at the mechanism level: open with a plain-English explanation, then go deep — never dilute the substance, only the explanation. Narrate your decisions and tradeoffs as you draft; the reasoning is the lesson. Verify technical claims against primary sources (the spec, the validator output) rather than asserting from memory. Report exactly what ran, what passed, what failed, and what was skipped.

## What this skill does not do

It does not run benchmark harnesses, A/B comparisons, or statistical eval viewers — Matt's gates are the two validators plus adversarial testing, and that is sufficient. It does not package `.skill` distribution files — skills ship through git, live tree first, then the Diver repo. It assumes no Anthropic-specific tooling: no WebFetch, no slash-command mechanics, no `present_files`. Read, Edit, Bash, and subagents are the working set.

## Activation

A dedicated activation tool wraps this skill at load time. The
`<skill_content>` envelope is applied by the harness — it is never baked
into this file. The envelope for this skill carries its bundled resources:

<skill_resources>
<file>agents/grader.md</file>
<file>scripts/validate.sh</file>
</skill_resources>

- **Dedup:** the harness tracks activated skills per session. If this skill
  is already in context, skip re-injection — never load it twice.
- **Subagent delegation:** recommended. The draft → test → grade → iterate
  loop already assumes an executor subagent plus the grader in
  `agents/grader.md`. Delegate the whole loop; it returns the validated
  skill plus the grading report.
