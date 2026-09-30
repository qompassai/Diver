<!-- skills/README.md — Agent Skills catalog for this setup -->

# skills/

Agent skills for this setup, in the standard `SKILL.md` format
([Agent Skills specification](https://agentskills.io/specification)).
A skill is a directory holding instructions, scripts, and references that
an agent loads on demand — procedural knowledge with a trigger, not config.

Install locations:

- `~/.config/nvim/skills/` — live tree. Skills are authored and edited here
  first, then validated, then mirrored out.
- `skills/` in the Diver repo — versioned mirror of the live tree.
- `~/.local/share/skills/` — cross-client XDG catalog (general-purpose
  skills, visible to any compliant client).
- `~/.local/share/nvim/skills/` — nvim-derived skills, under Neovim's own
  XDG data dir.

## The spec, condensed

A skill is a directory containing, at minimum, a `SKILL.md` file: YAML
frontmatter followed by Markdown instructions. Everything else in the
directory is optional. Recommended layout:

```text
skill-name/
  SKILL.md        # required: frontmatter + instructions, the operational core
  LICENSE.txt     # the skill's actual license, carried verbatim
  scripts/        # executable helpers the agent can run
  references/     # on-demand docs, loaded only when referenced
  assets/         # templates, images, data files used in output
```

Agents load skills by **progressive disclosure** — three tiers, each paying
only for what the task needs:

1. **Catalog** (~100 tokens/skill): `name` + `description`, loaded at
   session start for every skill. This is the discovery layer.
2. **Instructions** (<5000 tokens recommended): the full `SKILL.md` body,
   loaded when the skill activates. Keep it under ~500 lines; push bulk
   into `references/`.
3. **Resources** (as needed): files under `scripts/`, `references/`,
   `assets/` — loaded only when the instructions reference them.

File references inside a skill use paths relative to the skill root, kept
one level deep (`references/guide.md`, not chains of nested includes).
The description is the trigger: it decides whether the skill fires, so it
must say what the skill does *and* the concrete situations that call for
it. (Empirical backing for the tiered design:
[2609.35692](https://arxiv.org/abs/2609.35692) — progressive disclosure
improves skill-retrieval quality at marginal latency cost.)

## Activation

Two mechanisms, per the
[client-implementation guide](https://agentskills.io/client-implementation/adding-skills-support):

- **File-read activation**: the agent reads the `SKILL.md` path straight
  from the catalog. No special infrastructure.
- **Dedicated activation tool**: a tool (e.g. `activate_skill`) that takes a
  skill name and returns the content, optionally stripping frontmatter,
  wrapping it in identifying tags, listing bundled resources, and enforcing
  permissions.

### Structured wrapping (activation-time, never in SKILL.md)

When a dedicated activation tool loads a skill, it wraps the content in
identifying tags. **The wrapping is applied by the harness at load time —
it is NOT baked into `SKILL.md` files.** Format, per the
client-implementation guide:

```xml
<skill_content name="<skill-name>">
  ...skill body (frontmatter stripped or preserved — the harness's choice)...
  Skill directory: <absolute path to the skill directory>
  Relative paths in this skill are relative to the skill directory.
  <skill_resources>
    <file>scripts/example.py</file>
    <file>references/guide.md</file>
  </skill_resources>
</skill_content>
```

Why it exists:

- The model can distinguish skill instructions from other conversation
  content.
- The harness can identify skill content during context compaction and
  exempt it from pruning (skill instructions are durable guidance — losing
  them mid-session silently degrades the agent with no visible error).
- Bundled resources are surfaced to the model without being eagerly loaded.

Standing rule for this stack: any dedicated skill-activation tool built
here — rose.nvim, phlow, or future harness work — follows this format.

Related harness behaviors from the same guide, adopted where applicable:
list bundled resources but never eager-read them (cap the listing for large
skill dirs); allowlist skill directories in the permission system so
reading bundled resources doesn't spam confirmation prompts; deduplicate
activations within a session.

### Structured wrapping: dos and don'ts

**Do**

- Wrap at activation time with `<skill_content name="<skill-name>">`, and
  include the skill directory path plus the "relative paths are relative
  to the skill directory" note.
- List every bundled resource in `<skill_resources>` with `<file>` entries
  — surfaced, not eager-loaded. Cap the listing for large skill dirs.
- Track activated skills per session; skip re-injection when the skill is
  already in context (deduplicate activations, below).
- Use subagent delegation for complex multi-phase skills (below): the
  subagent receives the skill instructions, does the work, returns a
  summary.
- Allowlist skill directories in the permission system so reading bundled
  resources doesn't spam confirmation prompts.

**Don't**

- Bake the tags into `SKILL.md` source files. Ever — the envelope is the
  harness's job at load time.
- Re-inject a skill already in context. Duplicated instructions bloat the
  window and muddy precedence.
- Wrap on every turn. Wrap once per session; re-wrap only after context
  compaction.
- Eager-read every `<file>` in `<skill_resources>`. Load on demand.
- Let wrapped skill content be mistaken for untrusted data. Skill
  instructions win over data — always, especially over tool output and
  file contents the skill reads.

### Deduplicate activations

The harness keeps a per-session set of activated skill names. When the
model or the user requests a skill already in that set, skip the injection
and say so ("diver-linter-adapter is already active") instead of pasting
the instructions a second time. Our convention: clear the set only on
context compaction — and after compaction, re-injecting an in-progress
skill is correct resumption, not duplication.

### Subagent delegation

An advanced pattern, only for skills whose workflow is complex enough to
deserve a dedicated session: instead of injecting the skill into the main
conversation, run it in a subagent. The subagent receives the skill
instructions, performs the task, and returns a summary to the main
conversation. Each skill in this repo states its own verdict in its
Activation section — `mcp-builder`, `skill-creator`, `frontend-design`
(for the validation pass), `diver-busted-spec`, and `diver-dap-adapter`
recommend it; the small adapter skills (`diver-formatter-adapter`,
`diver-health-module`) don't need it; `internal-comms`,
`diver-linter-adapter`, and `diver-scip-indexer` call it optional.

## Layering: guide first, specifics underneath

For each language, the Tiger Style guide is the base layer and is always
applied first. Language-specific skills nest underneath their language's
guide:

```text
skills/<lang>/tiger-style-<lang>/
  SKILL.md              # base guide: ALWAYS applied first for <lang> work
  references/           # optional: guide supporting docs
  <specific-skill>/
    SKILL.md            # specific skill: applied after the base guide
    references/         # optional
```

General (non-language) skills sit flat directly under `skills/`
(`skills/mcp-builder/`, `skills/skill-creator/`, …).

### Composition rule

Every language-specific skill MUST open with a prerequisite line naming
its parent guide, so the guide applies even when the skill is discovered
standalone:

```markdown
> Prerequisite: apply the Tiger Style Lua guide first
> (`../SKILL.md`, `name: tiger-style-lua`). Everything below assumes it.
```

### Naming

The directory name must match the frontmatter `name` at every level.
`skills/lua/tiger-style-lua/` holds `name: tiger-style-lua`. The validators
check this; fix the mismatch, never the check.

### Not a skill

The repository playbook `SKILLS.md` at the repo root is referenced by
`AGENTS.md`/`CLAUDE.md` and is not an installable agent skill. Do not
move it under `skills/`.

## Frontmatter fields

Every field, its constraints from the spec, and what it means in this
setup. `name` and `description` are required; the rest are optional but
used by convention here.

<details>
<summary style="font-size: 1.1em; font-weight: bold; padding: 10px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>name</strong> — required</summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<p>Spec: 1–64 characters; lowercase letters, numbers, and hyphens only;
must not start or end with a hyphen; no consecutive hyphens
(<code>--</code>); <strong>must match the parent directory name</strong>.</p>
<p>Here: kebab-case, always. Discovery keys on this string — a mismatch
between directory and <code>name</code> is a validation error, not a
warning.</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.1em; font-weight: bold; padding: 10px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>description</strong> — required</summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<p>Spec: 1–1024 characters, non-empty. Must describe both what the skill
does and when to use it; should include specific keywords that help
agents identify relevant tasks.</p>
<p>Here: this is the <em>trigger</em> — the primary mechanism deciding
whether the skill fires. Write natural prose with concrete trigger terms
(file types, error names, task phrases), not keyword stuffing. Learned
the hard way: <code>skill-validator</code> flags gerund-enumeration
patterns like "Use when writing, regenerating, refactoring, reviewing, or
debugging X" as keyword lists — phrase it as "Applies whenever X is
written…" instead. Tune it with should-trigger / near-miss queries (see
the <code>skill-creator</code> skill).</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.1em; font-weight: bold; padding: 10px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>license</strong> — optional</summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<p>Spec: license name or reference to a bundled license file; keep it
short.</p>
<p>Here: always set, always SPDX (<code>Apache-2.0</code>), always backed
by a <code>LICENSE.txt</code> carried byte-verbatim in the skill
directory. Hard rule: never derive a skill from a proprietary-licensed
source — some upstream skills forbid external retention and derivative
works outright.</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.1em; font-weight: bold; padding: 10px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>compatibility</strong> — optional</summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<p>Spec: 1–500 characters if present. Environment requirements only —
intended product, system packages, network access. Include it only when
the skill genuinely has requirements.</p>
<p>Here: toolchain and environment the skill assumes (compilers, LSP
servers, network access to registries). This is <em>not</em> the agent's
tool allowlist — that is <code>allowed-tools</code>. State honestly when
there are no requirements.</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.1em; font-weight: bold; padding: 10px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>metadata</strong> — optional</summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<p>Spec: arbitrary map from string keys to string values. Keep key names
reasonably unique to avoid collisions across clients.</p>
<p>Here: machine-readable context that does not belong in prose.
Language skills use <code>language</code>, <code>lsp</code>,
<code>formatter</code>, <code>dap</code>, <code>scip_indexer</code>.
General skills use domain keys (<code>domain</code>,
<code>spec_target</code>, <code>test_split</code>, …).</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.1em; font-weight: bold; padding: 10px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>allowed-tools</strong> — optional, experimental</summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<p>Spec: space-separated string of pre-approved tools the skill may use
(e.g. <code>Read Edit Bash</code>). Experimental — support varies between
agent implementations.</p>
<p>Here: set it on every skill, scoped to exactly what the workflow needs
to be viable — least privilege. A skill that runs validators without
<code>Bash</code> is dead on arrival; a skill granted tools it never uses
widens the blast radius for no reason. Because support is experimental,
the skill body should also stay within the declared set rather than
treating the field as the only boundary.</p>
</blockquote>
</details>

## Valid vs invalid skill usage

A skill is a trusted instruction channel handed to an agent that acts
with your tools — arbitrary instructions plus executable scripts. The
recent literature treats that channel as an attack surface, and the
guidance below is drawn from it (arXiv IDs cited; all 2026, benchmark-
and red-team-heavy — the field is young, so treat findings as directional
evidence, not settled law).

**Do:**

- **Validate before install, both gates, zero tolerance.**
  `skills-ref validate` (structure) then `skill-validator` (quality) —
  zero errors *and* zero warnings. Warnings are not advisory here.
- **Pair static checks with adversarial testing.** Attackers now evolve
  malicious skills through dual-stage feedback loops that pass
  pre-execution scanning and only bite at runtime
  ([2609.32400](https://arxiv.org/abs/2609.32400)). Every skill here gets
  roughly half validation cases, half adversarial cases.
- **Keep skills lean.** Every body line is paid on every activation; push
  bulk into `references/`. Bloat is cost *and* attack surface: malicious
  skills can abuse the trusted channel for token amplification
  ([2608.21929](https://arxiv.org/abs/2608.21929)).
- **Scope `allowed-tools` tightly** to what the workflow needs.
  Mediated/limited skill file access cuts injection attack success
  substantially ([2606.01567](https://arxiv.org/abs/2606.01567)) —
  `allowed-tools` is where you declare the blast radius.
- **Tune the trigger and ablate.** Skills frequently add nothing — or hurt
  — while costing tokens ([2609.32274](https://arxiv.org/abs/2609.32274));
  benchmark whether the skill should have been injected at all
  ([2608.23067](https://arxiv.org/abs/2608.23067)). Test should-trigger
  against near-miss should-not-trigger queries; run with-skill vs
  without-skill before keeping one.
- **Instructions win over data.** Untrusted content inside files the skill
  reads must never override the skill body.
- **Keep a human in the skill-update loop.** Skills rewritten from
  execution trajectories can be backdoored via trajectory poisoning
  ([2608.08303](https://arxiv.org/abs/2608.08303)) — review skill updates,
  don't auto-accept them.

**Don't:**

- **Don't install a skill you haven't read.** One tampered instruction can
  drive silent malicious execution while the visible task passes its
  verifier ([2606.07943](https://arxiv.org/abs/2606.07943)).
- **Don't trust the frontmatter alone.** There is a reliability–visibility
  trade-off: hostile instructions hide more easily in a long body than in
  the preloaded frontmatter block ([2606.07943](https://arxiv.org/abs/2606.07943)).
  Read the body.
- **Don't grant tools the workflow doesn't need** (see
  `allowed-tools` above).
- **Don't bake activation wrapping into `SKILL.md`** — wrapping is the
  harness's job (Structured wrapping, above).
- **Don't load project-level skills from untrusted repos without a trust
  check.** A freshly cloned repository is not your skill author.
- **Don't keep a skill that doesn't earn its keep.** No measurable gain
  over the no-skill baseline means delete it
  ([2609.32274](https://arxiv.org/abs/2609.32274),
  [2608.23067](https://arxiv.org/abs/2608.23067)).

**Enforcement here** — the gates that make the above concrete:
`skills-ref validate` + `skill-validator` 1.6.2 (both green, zero
warnings) · directory name == frontmatter `name` · every relative file
reference resolves · bundled scripts pass syntax checks
(`python3 -m py_compile`, `bash -n`, `luac -p`) · `git diff --check` clean
· live tree and repo copies byte-identical before commit.

## Skills

### Language guides (Tiger Style)

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-c</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/c/tiger-style-c/SKILL.md"><code>skills/c/tiger-style-c/SKILL.md</code></a></li></ul>
<p>Safety-first C: explicit contracts, assertions, bounded work, disciplined manual memory ownership. Hardens against buffer overflows, use-after-free, integer overflow.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=clangd, formatter=clang-format, dap=lldb-dap, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-cpp</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/cpp/tiger-style-cpp/SKILL.md"><code>skills/cpp/tiger-style-cpp/SKILL.md</code></a></li></ul>
<p>Safety-first C++23: contract-first design, <code>std::expected</code> error handling, no exceptions across boundaries, bounded containers, RAII ownership.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=clangd, formatter=clang-format, dap=lldb-dap, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-go</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/go/tiger-style-go/SKILL.md"><code>skills/go/tiger-style-go/SKILL.md</code></a></li></ul>
<p>Safety-first Go: errors-as-values with <code>%w</code> wrapping, bounded goroutines and retries, context discipline.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=gopls, formatter=gofmt, dap=delve, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-lua</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/lua/tiger-style-lua/SKILL.md"><code>skills/lua/tiger-style-lua/SKILL.md</code></a></li></ul>
<p>Tiger Style for Lua, LuaJIT, Neovim Lua, and embedded Lua — the original skill in this tree (predates the current frontmatter conventions, so it carries no <code>license</code>/<code>allowed-tools</code> fields). Nests the <code>love2d-*</code> skills underneath it.</p>
<p><strong>allowed-tools:</strong> not declared ·
<strong>metadata:</strong> not declared</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-nix</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/nix/tiger-style-nix/SKILL.md"><code>skills/nix/tiger-style-nix/SKILL.md</code></a></li></ul>
<p>Safety-first Nix: pure evaluation discipline, explicit inputs, pinned sources — flakes, packages, NixOS/Home Manager modules, dev shells.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=nil,nixd, formatter=alejandra, dap=nix-debug-adapter, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-python</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/python/tiger-style-python/SKILL.md"><code>skills/python/tiger-style-python/SKILL.md</code></a></li></ul>
<p>Safety-first Python: contract-first design, typed signatures, exception discipline, bounded I/O and retries.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=ruff, formatter=black, dap=debugpy, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-scala</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/scala/tiger-style-scala/SKILL.md"><code>skills/scala/tiger-style-scala/SKILL.md</code></a></li></ul>
<p>Safety-first Scala: effect discipline, total functions, functional-core / imperative-shell designs.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=metals, formatter=scalafmt, dap=metals, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-typescript</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/typescript/tiger-style-typescript/SKILL.md"><code>skills/typescript/tiger-style-typescript/SKILL.md</code></a></li></ul>
<p>Safety-first TypeScript 5.9+ (strict): contract-first design, explicit error paths, bounded async work.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=ts_ls, formatter=prettier, dap=node, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>tiger-style-zig</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><a href="skills/zig/tiger-style-zig/SKILL.md"><code>skills/zig/tiger-style-zig/SKILL.md</code></a></li></ul>
<p>Safety-first Zig: explicit allocators, error-union discipline, bounded comptime work.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> lsp=zls, formatter=zig fmt, dap=lldb-dap, scip_indexer=not-configured</p>
<p>Validated: skills-ref ✓ · skill-validator 1.6.2 ✓ (0 errors, 0 warnings)</p>
</blockquote>
</details>

### General skills

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>mcp-builder</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/mcp-builder/SKILL.md</code></li></ul>
<p>Build and harden MCP servers and clients for the Neovim-first stack: phlow's MCP server (Python now, Rust nightly port), the rose.nvim Lua stdio client, new servers in Rust/TypeScript/Python. Protocol-first against the current spec; adversarial security review as a first-class phase (RCE via tool args, command injection, credential leakage, prompt injection in tool output, zombie processes, supply-chain poisoning). 50/50 validation/adversarial tests.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> spec_target=2025-11-25, primary_sdk=rmcp 3.x, test_split=50/50</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>skill-creator</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/skill-creator/SKILL.md</code></li></ul>
<p>The workflow for creating, modifying, and improving Agent Skills in this setup: capture intent → interview → draft against the spec → both validators (zero warnings) → adversarial testing → description tuning → live-first install → versioned mirror. This README's conventions live here in executable form.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=agent-skills, spec=https://agentskills.io/specification</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>frontend-design</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/frontend-design/SKILL.md</code></li></ul>
<p>Distinctive visual design for HTML report briefs, review packs, and rose.nvim UI surfaces — the artifacts read on a phone. Replaces templated AI-slop defaults with deliberate, opinionated palette/typography/layout choices; phone-first, self-contained offline single-file HTML, dark-mode sensibility.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=visual-design, surfaces=html-artifacts/rose-nvim-ui, audience=phone-review</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>internal-comms</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/internal-comms/SKILL.md</code></li></ul>
<p>Qompass AI communications in Matt's plain, evidence-based voice: 3P updates, project status reports, incident reports, program briefs, FAQs. Gathers evidence from Gmail, Calendar, repo state, and memory before drafting; every claim attributed, no invented numbers.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=communications, org=Qompass AI, formats=3p-updates/status-report/incident-report/…</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

### Diver-mined skills

Mined from the live Neovim config's recurring workflows. Installed in the
live tree at `~/.config/nvim/skills/<name>/`, mirrored to Diver under
`skills/<name>/` and to `~/.local/share/nvim/skills/<name>/`.

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>diver-busted-spec</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/diver-busted-spec/SKILL.md</code></li></ul>
<p>Write headless busted unit specs for diver Lua modules with the mandated half-validation / half-adversarial split — spec headers stating coverage and the run command, the shared <code>_G.vim</code> stub helper (never a file-local vim global), and the <code>.busted</code> task set including order-dependence shuffling.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=testing, area=tests/busted, runner=busted</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>diver-dap-adapter</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/diver-dap-adapter/SKILL.md</code></li></ul>
<p>Wire a new native DAP debug adapter into diver: vet the candidate package against its own upstream source under the adapter-verdicts protocol, implement the DebugModule contract in <code>lua/dap/</code>, register it in the MODULES catalog, and promote it through the readiness registry from discovered to validated.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=debugging, area=lua/dap, registry=lua/dap/init.lua</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>diver-formatter-adapter</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/diver-formatter-adapter/SKILL.md</code></li></ul>
<p>Teach a new external formatter to diver: verify its real CLI flags against upstream docs, choose the stdin-vs-tempfile I/O mode, write the adapter in <code>lua/formatters/</code> with an ELI5 header per flag, and register it — never a one-off BufWritePre autocmd.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=formatters, area=lua/formatters, registry=lua/formatters/init.lua</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>diver-health-module</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/diver-health-module/SKILL.md</code></li></ul>
<p>Author a <code>:checkhealth</code> health module for a diver subsystem: probe its external executables, introspect its registry nil-safely, and report ok/warn/error through vim.health with the concrete consequence on every warning.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=diagnostics, area=lua/&lt;domain&gt;/health.lua, interface=vim.health</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>diver-linter-adapter</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/diver-linter-adapter/SKILL.md</code></li></ul>
<p>Wire a new native linter into diver (no nvim-lint): pick the tool's machine-parseable output mode from upstream docs, defensive line parsing with explicit bounds, source-stamped diagnostics for virtual-text attribution, the self-contained-config decision, registration with the orphan check, and the LintValidate gates.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=linters, area=lua/linters, registry=lua/linters/init.lua</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>diver-scip-indexer</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/diver-scip-indexer/SKILL.md</code></li></ul>
<p>Register a new SCIP code-intelligence indexer in diver: verify the install method against primary sources (sourcegraph→scip-code org move, npm-not-pip for scip-python), write the ScipIndexer module, register it in config and the README inventory, and prove it with ScipHealth plus a real index.scip on a fixture project.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> domain=code-intelligence, area=lua/dev/scip, registry=lua/dev/scip/config.lua</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

### Dotfiles-mined skills

Mined from Matt's dotfiles' recurring workflows (system administration,
desktop session, incident response, PQC networking). Installed in the live
tree at `~/.config/nvim/skills/<name>/`, mirrored to Diver under
`skills/<name>/` and to `$XDG_DATA_HOME/skills/<name>/` (also tracked in the
Dotfiles repo at `.local/share/skills/<name>/`).

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>arch-provision</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/arch-provision/SKILL.md</code></li></ul>
<p>Provisions a fresh Arch Linux machine end-to-end: full system update, bootstraps the AUR helper, configures snapper BTRFS snapshots, enables multilib, installs the display manager and KDE Plasma, installs the NVIDIA driver, applies the curated package list from packages.yml across pacman/yay/flatpak/npm, and finishes with a reboot prompt. Never run the update-ritual logic here — that is a separate skill.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> managers=pacman/yay/paru/flatpak/npm, package_list=packages.yml, prereq_fs=btrfs, source_repo=dotfiles/arch</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>arch-system-update</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/arch-system-update/SKILL.md</code></li></ul>
<p>Matt's full Arch Linux system update ritual: snapper pre/post BTRFS snapshots (pre-snapshot failure is a hard stop), pacman repo refresh and system upgrade, AUR updates via paru, flatpak updates, conditional bun/dotnet/uv tool upgrades, orphan removal, snapshot pruning to the newest 100, and a reboot prompt when the kernel changed. Ordered and gated — never reorder or skip past a failed step.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> managers=pacman/paru/flatpak/bun/dotnet/uv, snapshot_tool=snapper, prune_keep=100, source=dotfiles/arch/scripts/update.sh</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>aur-malware-scan</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/aur-malware-scan/SKILL.md</code></li></ul>
<p>Incident-response scan for the June 2026 atomic-lockfile AUR supply-chain attack (1600+ compromised packages shipping an infostealer + eBPF rootkit). Uses Matt's local copy of the lenucksi/aur-malware-check detection toolkit (aur_check-v2.sh or the Python 3.14+ stdlib port): quick-triage one-liner, date-windowed scan, bun/npm cache checks, cross-campaign --all-time sweep, and live list refresh from the Arch HedgeDoc. Infected verdict means rotating all credentials.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> campaign=atomic-lockfile-2026-06, tool_dir=~/.GH/aur-malware-check, payload=infostealer+ebpf-rootkit</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>hyprland-session</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/hyprland-session/SKILL.md</code></li></ul>
<p>Hyprland session operations on Matt's workstation: wake monitors after sleep (DP-1 2560x1440@143.97, DP-2 1920x1080@59.94), reload Hyprland with the quickshell bar (reload without restarting the bar leaves it dead), toggle tile/free layout mode, and diagnose compositor state. monitors.conf is nwg-displays-generated — never hand-edit it.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> app=hyprland, compositor=/usr/bin/hyprctl, bar=quickshell/noctalia-shell, monitors=DP-1/DP-2</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<details>
<summary style="font-size: 1.2em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 8px; cursor: pointer; margin: 8px 0;"><strong>rosenpass-pqc-vpn</strong></summary>
<blockquote style="font-size: 1em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 12px 0;">
<ul><li><code>skills/rosenpass-pqc-vpn/SKILL.md</code></li></ul>
<p>Post-quantum-secure WireGuard tunnel setup with Rosenpass. Adds a post-quantum key exchange in front of WireGuard so a future quantum computer cannot retroactively break recorded handshakes (harvest-now-decrypt-later). Covers installing rosenpass and wireguard-tools, generating the keypair with <code>rosenpass gen-keys</code>, writing the TOML config with [[peers]] entries, feeding the exchanged PSK into <code>wg set</code>, and running the daemon with <code>rosenpass exchange-config</code>. Never commit secret keys.</p>
<p><strong>license:</strong> Apache-2.0 ·
<strong>allowed-tools:</strong> Read Edit Bash ·
<strong>metadata:</strong> pqc_kex=rosenpass, vpn=wireguard, keygen=rosenpass gen-keys, daemon=rosenpass exchange-config</p>
<p>Validated: skills-ref ✓ · skill-validator ✓ (0 errors)</p>
</blockquote>
</details>

<!-- APPEND NEW SKILL DROPDOWNS BELOW THIS LINE -->

## Adding a new skill

Use the `skill-creator` skill — it encodes this whole workflow. The
checklist, in order:

1. **Capture intent**: what must an agent do with this skill that it can't
   reliably do without it? What phrases/situations trigger it? What does
   success look like?
2. **Check overlap**: scan this README and `skills-ref to-prompt` output.
   A new skill duplicating an existing trigger space is a bug — merge or
   narrow.
3. **Draft** `SKILL.md` against the spec (fields above); keep it under
   ~500 lines, bulk in `references/`; carry the upstream `LICENSE.txt`
   verbatim when derived from another source.
4. **Validate**: `skills-ref validate` then `skill-validator` — zero
   errors, zero warnings. Then the manual checks: name == dir, relative
   refs resolve, scripts syntax-check, `git diff --check` clean.
5. **Test**: half validation, half adversarial. With-skill vs without-skill
   ablation before keeping it.
6. **Install live-first**: back up `~/.config/nvim` → `~/.config/nvim.bak`
   (preserving any existing backup), install in the live tree, validate
   there, then mirror byte-identical into Diver (`skills/`) and, for
   general skills, `~/.local/share/skills/`.
7. **Document**: append a dropdown for the new skill below the marker
   above, mirroring the existing entries.
8. **Commit & push** only with explicit authorization. Never force-push.
