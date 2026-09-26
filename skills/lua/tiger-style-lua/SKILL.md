---
name: tiger-style-lua
description: >
  Safety-first Tiger Style engineering for Lua, LuaJIT, Neovim Lua, and embedded Lua.
  Use when writing, reviewing, debugging, refactoring, or optimizing Lua code where
  correctness, explicit invariants, bounded resource use, deterministic behavior,
  narrow data shapes, disciplined ownership, secure process execution, and verifiable
  completion matter. Especially applicable to modern Neovim 0.13+ configuration and
  Arch Linux development.
---

# Tiger Style Lua

Apply this skill directly when engineering Lua code.

This skill is an independent Lua adaptation of TigerBeetle's Tiger Style engineering
philosophy. It does not imply that Lua is Zig and is not an official TigerBeetle document.

# Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Priority

Always optimize in this order:

1. **Safety** — correctness, invariants, bounds, ownership, explicit failure behavior.
2. **Performance** — predictable resource use, batching, measured hot paths.
3. **Developer experience** — clarity, reviewability, maintainability, tooling.

When priorities conflict, do not sacrifice an invariant for convenience, do not permit
unbounded behavior for a small speedup, do not hide failure to simplify an API, and do not
optimize code whose correctness model is unclear.

## Activation

Use this skill for:

- Lua and LuaJIT implementation work;
- Neovim Lua configuration and plugin code;
- embedded Lua;
- Lua review, debugging, refactoring, performance work, and security review;
- subprocess, filesystem, async, resource-lifetime, and parser work in Lua;
- Lua code that consumes untrusted or machine-generated input;
- Arch Linux development involving Lua tooling.

For trivial edits, keep the application of this skill lightweight. Preserve the repository's
existing architecture, formatter, APIs, conventions, and scoped instructions unless the task
explicitly requires changing them.

## Core contract

A Tiger Style Lua implementation should make these questions easy to answer:

- What inputs are permitted?
- What inputs are rejected?
- What is the maximum amount of work?
- What state may change?
- Who owns each resource?
- What happens on failure?
- Which postconditions must hold on return?
- Can asynchronous state become stale?
- Is output deterministic where it needs to be?
- What privileged or external capability does the code invoke?

Working principle:

> Make invalid states hard to construct, easy to detect, and impossible to silently preserve.

## Before coding

1. Inspect the relevant code and nearby patterns before changing behavior.
2. Determine the actual runtime: Lua 5.1/5.4, LuaJIT, Neovim, OpenResty, or another host.
3. Identify project formatter and type-checking rules.
4. State material assumptions when they affect behavior.
5. Define observable success criteria.
6. Identify resource bounds, ownership, failure paths, and async lifetime hazards.
7. Prefer the simplest implementation that satisfies the task.

Do not silently copy runtime-specific assumptions between Lua implementations.

## Runtime boundaries

Lua implementations differ in:

- integer representation;
- bit operations;
- `utf8` availability;
- `table.unpack` versus `unpack`;
- `load()` signatures;
- garbage-collector behavior;
- LuaJIT FFI;
- filesystem and process APIs supplied by the host;
- coroutine scheduling;
- C-module ABI compatibility.

Put runtime-specific behavior behind a small, explicit boundary.

For Neovim code, target the runtime and APIs actually provided by the checked-out Neovim
version. Do not assume ordinary standalone Lua semantics where Neovim differs.

## Module structure

Prefer modules that read top-to-bottom in this order:

1. header and purpose;
2. frequently used host API aliases;
3. module table when needed;
4. constants and named limits;
5. LuaCATS types;
6. validation helpers;
7. private leaf helpers;
8. orchestration functions;
9. `setup()` only when required;
10. returned public module/configuration value.

Alias host APIs only when it improves clarity. Do not alias everything merely to save
characters.

```lua
local api = vim.api
local fs = vim.fs

local M = {}

local ITEM_COUNT_MAX = 4096

---@class TigerOptions
---@field root string
---@field item_count_max integer?

local function validate_options(options)
    assert(type(options) == 'table')
    assert(type(options.root) == 'string')
end

local function collect_items(options)
    -- Bounded leaf implementation.
end

function M.run(options)
    validate_options(options)

    return collect_items(options)
end

return M
```

## Assertions and validation

Use assertions for programmer errors and internal invariants.

Good assertion targets include:

- internal type assumptions;
- index bounds;
- count bounds;
- state-machine state;
- ownership assumptions;
- postconditions;
- impossible branches.

Use normal validation and returned errors for expected operating failures and external input.

Prefer separate assertions when they expose distinct invariants:

```lua
assert(index >= 1)
assert(index <= count)
```

Do not use assertions as the only protection for untrusted input.

```lua
local function validate_path(path)
    if type(path) ~= 'string' then
        return nil, 'path must be a string'
    end

    if path == '' then
        return nil, 'path must not be empty'
    end

    if path:find('%z') ~= nil then
        return nil, 'path contains NUL'
    end

    return true, nil
end
```

## Bound everything

Every externally influenced or potentially growing operation must have an explicit bound or a
clear external termination invariant.

Bound where applicable:

- loops;
- retries;
- queues;
- caches;
- diagnostics;
- files;
- captured stdout/stderr;
- request bodies;
- concurrent jobs;
- timers;
- pending callbacks;
- nested parsing depth;
- histories;
- log retention;
- subprocess runtime.

Name limits with units and purpose:

```lua
local RETRY_COUNT_MAX = 4
local OUTPUT_SIZE_BYTES_MAX = 8 * 1024 * 1024
local TIMEOUT_MS = 60000
local DIAGNOSTIC_COUNT_MAX = 512
```

Avoid unexplained `while true do` loops. Long-lived services still need lifecycle invariants,
cancellation, or another explicit termination contract.

## Control flow

Prefer control flow that can be verified locally.

- Push branch decisions upward.
- Push loops downward into focused leaf functions.
- Keep hot loops branch-light.
- Prefer positive conditions.
- Avoid clever short-circuit side effects.
- Do not use boolean operators as statement syntax.
- Avoid recursion for attacker-controlled or deeply nested input.
- Make impossible states explicit.

Prefer:

```lua
if ready then
    start()
end
```

over:

```lua
ready and start()
```

## Error handling

Every fallible operation needs a deliberate failure path.

Use explicit result conventions such as:

```lua
return value, nil
```

or:

```lua
return nil, 'descriptive error'
```

Do not silently discard `pcall()` failures.

```lua
local ok, result = pcall(do_work)

if not ok then
    return nil, 'do_work failed: ' .. tostring(result)
end

return result, nil
```

Preserve operation context in errors. Do not reduce a useful failure to an ambiguous generic
message.

## Nil, false, and optional values

`nil` and `false` are different states even though both are falsey.

Never use `or` to apply a default when `false` is a valid explicit value.

Bad:

```lua
local enabled = options.enabled or true
```

Good:

```lua
local enabled

if options.enabled == nil then
    enabled = true
else
    enabled = options.enabled
end
```

Give `nil` one documented meaning in each API. If several meanings are required, use a richer
state representation instead of overloading `nil`.

## Numbers, integers, counts, and units

Do not let one numeric type erase semantic distinctions.

Prefer names such as:

- `item_index`;
- `item_count`;
- `buffer_size_bytes`;
- `offset_bytes`;
- `capacity`;
- `timeout_ms`;
- `retry_count`;
- `generation_id`.

Name units last, for example `timeout_ms`, `payload_size_bytes`, and
`cache_size_bytes_max`.

Validate integer requirements explicitly when the runtime or API does not guarantee them.

## Tables and data shapes

Lua tables can represent arrays, maps, records, sets, objects, and namespaces. Keep those roles
explicit.

- Do not mix array and map semantics accidentally.
- Do not rely on `#table` for sparse arrays.
- Do not rely on `pairs()` iteration order.
- Avoid fields that change type over time.
- Prefer constructors for stateful structures.
- Document invariants for long-lived tables.
- Use metatables only when they provide substantial semantic value.
- Prefer precise LuaCATS shapes for structured data.

For deterministic map traversal, collect and sort keys before processing them.

## State and mutation

Mutable state must have a clear owner.

Prefer this flow:

```text
input
  |
  v
validate
  |
  v
control function
  |
  +----> bounded leaf work
  |
  v
validate delta
  |
  v
single commit point
```

Rules:

- mutate at a small number of obvious points;
- separate computation from mutation;
- document valid state transitions;
- copy caller-owned configuration when later mutation could surprise the caller;
- avoid shared module state as a hidden message bus;
- avoid implicitly coupled globals.

## Function design

Ordinary functions should usually stay near or below **70 physical lines**. Treat this as a
review threshold, not a reason to fragment cohesive logic.

Prefer named option tables over long positional argument lists.

Bad:

```lua
copy_range(source, target, 10, 20, true, false)
```

Better:

```lua
copy_range({
    source = source,
    target = target,
    first_index = 10,
    item_count = 20,
    overwrite = true,
    preserve_metadata = false,
})
```

Keep variables close to first use, derived values close to consumption, and closure captures
small.

## Resource lifetime

Every resource should have one clear owner and should be released exactly once on every
termination path.

Examples include:

- files;
- sockets;
- `vim.uv` handles;
- subprocesses;
- timers;
- temporary directories;
- temporary files;
- FFI allocations;
- registrations and autocmds with lifecycle semantics.

Prefer idempotent teardown.

```lua
local function close_handle(state)
    if state.handle == nil then
        return
    end

    if not state.handle:is_closing() then
        state.handle:close()
    end

    state.handle = nil
end
```

## Memory and allocation

Lua is garbage-collected, so do not pretend that managed Lua is allocation-free.

Translate Tiger Style's memory intent into:

> Memory use should be predictable, bounded, and visible.

- Cap caches, histories, and queues.
- Drop references to large completed objects.
- Avoid accidental closure retention.
- Avoid repeated large table copies.
- Prefer `table.concat()` over repeated giant string concatenation.
- Treat LuaJIT FFI allocations as manually owned resources.
- Do not force garbage collection in hot paths without measurement.

## Performance

Performance starts with resource modeling, then measurement.

Consider the dominant contribution to total work:

```text
network + disk + memory + cpu + coordination
```

Optimize the largest meaningful term first.

Rules:

- batch system calls;
- batch RPC;
- batch diagnostics and redraw work;
- avoid repeated filesystem probing;
- separate control-plane work from data-plane work;
- keep hot loops simple;
- avoid avoidable allocation in measured hot paths;
- benchmark before claiming a speedup;
- do not defer basic capacity modeling until profiling.

## Determinism

Determinism improves testing, reproducibility, and debugging.

- Sort map keys before serialization when order matters.
- Never rely on `pairs()` ordering.
- Normalize platform-sensitive output where needed.
- Pass explicit options.
- Seed pseudo-random tests.
- Make locale and timezone assumptions explicit.
- Pin or verify external tool behavior when parsing depends on versions.

## Security boundaries

Treat the following as privileged capabilities:

- `os.execute`;
- `io.popen`;
- `load`;
- `loadfile`;
- `dofile`;
- `require` from writable or untrusted search paths;
- `package.loadlib`;
- LuaJIT FFI;
- `vim.system`;
- filesystem writes;
- shell command construction;
- dynamic plugin loading.

Never concatenate untrusted values into a shell command.

For Neovim, prefer argv-safe direct execution:

```lua
local result = vim.system({
    'git',
    'status',
    '--porcelain=v1',
    '--',
    user_path,
}, {
    text = true,
}):wait()

if result.code ~= 0 then
    return nil, result.stderr
end

return result.stdout, nil
```

An empty environment passed to `load()` is not a complete security sandbox.

## Filesystem safety

Before privileged filesystem use:

- validate path type and non-empty state;
- reject NUL bytes;
- normalize paths before policy checks;
- define symlink behavior;
- do not implement containment using naive string prefixes;
- use controlled temporary directories;
- prefer write-temp plus atomic rename for important replacement;
- avoid accidental overwrite of sensitive files;
- use exclusive creation where appropriate.

## Processes and shells

Prefer direct process execution over shell construction.

For Neovim:

```lua
vim.system({
    'clang-tidy',
    '--quiet',
    '--',
    filename,
}, {
    cwd = root,
    text = true,
})
```

Process checklist:

- executable is explicit;
- each argv element is separate;
- user paths are behind `--` when supported;
- cwd is explicit where relevant;
- timeout is defined where hangs matter;
- captured output is bounded where possible;
- exit code is checked;
- signal is checked where exposed;
- stderr is not automatically treated as failure;
- machine-readable output is preferred when stable.

## Coroutines and async work

A precondition can become false after a yield or callback delay.

Use generation tokens or equivalent ownership/lifetime checks for stale work.

```lua
local generation = 0

local function refresh()
    generation = generation + 1

    local request_generation = generation

    start_async(function(result)
        if request_generation ~= generation then
            return
        end

        apply_result(result)
    end)
end
```

Async rules:

- bound outstanding work;
- reject stale callbacks;
- cancel owned work during teardown where supported;
- revalidate buffers, windows, files, and handles after asynchronous delay;
- minimize callback captures;
- do not mutate deleted Neovim resources.

## Naming

Use `snake_case` unless the surrounding repository has a different established convention.

Prefer domain language over opaque abbreviations.

Good examples:

```text
request_count
diagnostic_count
buffer_size_bytes
timeout_ms_max
retry_count
generation_id
source_path
target_path
```

Short names are acceptable only for tiny, conventional local roles where meaning is obvious.

## Formatting

Unless the repository specifies otherwise, prefer:

- 4-space indentation;
- maximum 100 columns;
- one statement per line;
- trailing commas in multiline structures;
- blank lines between conceptual phases;
- deterministic formatter output.

Example StyLua policy:

```toml
column_width = 100
indent_type = 'Spaces'
indent_width = 4
line_endings = 'Unix'
quote_style = 'AutoPreferSingle'
call_parentheses = 'Always'
```

Do not reformat unrelated code merely to satisfy this skill. Existing repository formatting is
a stronger local contract.

## Comments and LuaCATS

Comments should explain intent, constraints, invariants, and ownership rather than restating
syntax.

Use LuaCATS annotations where they improve precision and tooling.

```lua
---@class TigerConfig
---@field root string
---@field timeout_ms integer
---@field notify boolean

---@param config TigerConfig
---@return boolean? ok
---@return string? error
local function validate_config(config)
    -- ...
end
```

Prefer precise annotations and runtime validation over blanket `any`, blind casts, diagnostic
suppression, or fabricated fallback values.

## Dependencies

Every dependency expands supply-chain, compatibility, startup, installation, update, and
transitive-risk surfaces.

Prefer, in order:

1. Lua standard library;
2. trusted host APIs;
3. small audited internal code;
4. mature external dependencies.

Add a dependency only when it earns its cost. Pin versions or commits when reproducibility
matters. Do not download executable dependencies at runtime in trusted paths unless the product
explicitly requires and secures that behavior.

## Neovim 0.13+ guidance

For modern Neovim Lua:

- prefer `vim.api`;
- prefer `vim.fs`;
- prefer `vim.system`;
- prefer `vim.uv`;
- prefer current native Neovim facilities over avoidable plugin dependencies;
- avoid deprecated APIs;
- keep `setup()` idempotent;
- group owned autocmds;
- clear and recreate owned augroups intentionally;
- validate asynchronous buffer, window, client, and handle lifetimes;
- keep `require()` focused on loading definitions rather than surprising global side effects;
- prefer structured machine-readable output for external-tool integrations;
- pass subprocess arguments as arrays, never interpolated shell strings;
- preserve unsaved-buffer behavior when stdin-based tooling supports it.

When implementing native Neovim linters, LSP helpers, DAP utilities, or parser integrations:

- use explicit `LintContext`/buffer context where the repository provides it;
- return complete `vim.Diagnostic` shapes;
- preserve rule IDs and exact ranges when upstream output provides them;
- bound diagnostics, messages, parser depth, and captured subprocess output;
- assign a subprocess timeout;
- detect project root explicitly;
- validate decoded JSON before indexing fields;
- prefer stdin for unsaved buffers when the CLI supports it;
- avoid shell interpolation and temporary files unless the tool requires them.

## Strict Lua/LuaLS expectations

When LuaLS is part of the repository's verification path:

- use LuaJIT semantics when that is the declared runtime;
- keep `weakNilCheck = false`;
- keep `weakUnionCheck = false`;
- keep `checkTableShape = true`;
- keep `castNumberToInteger = false`;
- keep `inferParamType = true`;
- keep type checking enabled;
- keep `undefined-field` at Error when that is repository policy;
- model optional values honestly;
- narrow `io.open`, `loadfile`, uv handles/stat results, optional config, and decoded input before
  access;
- recheck async lifetimes after yields/callback delays;
- do not suppress diagnostics merely to make the checker green.

For headless checking, verify that all intended files were actually checked. An empty diagnostic
list is not sufficient evidence if the checker skipped the files.

## Arch Linux development

On Arch Linux:

- prefer `pacman` for suitable system packages;
- review AUR `PKGBUILD` files for security-sensitive tooling;
- never run project language package managers with `sudo`;
- do not build ordinary project dependencies as root;
- keep repository tooling reproducible;
- prefer direct argv-safe invocation over shell pipelines in application code.

Typical Lua checks may include:

```bash
stylua --check .
luacheck .
lua tests/run.lua
```

Use the repository's actual commands when they differ.

## Testing

Test boundaries before spending effort on happy-path permutations.

For a maximum `M`, test meaningful values from:

```text
0, 1, M-1, M, M+1
```

Also test where applicable:

- `nil`;
- `false`;
- malformed input;
- cancellation;
- timeout;
- retry exhaustion;
- stale callbacks;
- cleanup after failure;
- invalid state transitions;
- deterministic ordering;
- partial external output;
- missing files and tools;
- oversized output;
- maximum diagnostics or queue capacity.

## Review checklist

Before finishing, verify:

- [ ] Safety outranks performance and developer convenience.
- [ ] External input is validated before privileged use.
- [ ] Internal invariants have meaningful assertions.
- [ ] Externally influenced loops and collections are bounded.
- [ ] Retries have a maximum.
- [ ] Queues, caches, histories, and captured output have limits where growth is possible.
- [ ] `nil` and `false` semantics are deliberate.
- [ ] Index, count, size, offset, timeout, and unit semantics are explicit.
- [ ] Every owned resource has a single clear owner.
- [ ] Cleanup exists for failure and cancellation paths.
- [ ] Errors are not silently discarded.
- [ ] Untrusted input is never interpolated into shell command strings.
- [ ] External commands use argv arrays where possible.
- [ ] State mutation is centralized and reviewable.
- [ ] Async callbacks reject stale state.
- [ ] Persistent/test-sensitive output is deterministic.
- [ ] Dependencies are justified.
- [ ] Ordinary functions remain near or below 70 lines unless cohesion justifies an exception.
- [ ] Ordinary lines remain near or below 100 columns unless repository formatting differs.
- [ ] Comments explain intent and invariants rather than syntax.
- [ ] Tests cover boundaries and failure cleanup.

## Anti-patterns

Reject patterns like:

```lua
-- Hidden global mutation.
state = state or {}

-- Shell injection surface.
os.execute('tool ' .. user_input)

-- Swallowed failure.
pcall(do_work)

-- Unbounded retry.
while true do
    if try_again() then
        break
    end
end

-- False accidentally replaced by true.
local enabled = options.enabled or true

-- Sparse-table length assumption.
local count = #possibly_sparse

-- Untrusted code execution.
local chunk = load(user_text)
chunk()
```

## Documentation outputs

When this skill is used to produce Lua documentation:

- keep semantic Markdown as the primary content layer;
- treat raw HTML, SVG, CSS, video, and JavaScript as optional progressive enhancement;
- keep documentation understandable if custom CSS or JavaScript is stripped;
- prefer `<details>`/`<summary>` over custom JavaScript disclosure widgets;
- do not load arbitrary third-party scripts;
- do not insert untrusted content with `innerHTML`;
- provide text/link fallbacks for media;
- never make video the sole location of important technical information.

## Verification and finish

For substantive changes:

1. Run the focused regression or reproduce the original failure.
2. Run boundary and failure cases relevant to the change.
3. Run the affected formatter.
4. Run the affected static/type checker.
5. Run relevant integration tests.
6. Review the final diff for scope creep, ownership mistakes, unbounded work, and unrelated edits.
7. Report exact commands, tool versions when relevant, scope, exit results, and skipped or
   unavailable checks.

Do not claim a full pass from partial verification. Re-run affected checks after the final edit.

## Reference implementation shape

A small Tiger Style function generally follows this pattern:

```lua
local M = {}

local ITEM_COUNT_MAX = 1024

local function validate_items(items)
    if type(items) ~= 'table' then
        return nil, 'items must be a table'
    end

    if #items > ITEM_COUNT_MAX then
        return nil, 'item limit exceeded'
    end

    return true, nil
end

local function transform_items(items)
    assert(type(items) == 'table')
    assert(#items <= ITEM_COUNT_MAX)

    local transformed = {}

    for index = 1, #items do
        local item = items[index]

        assert(type(item) == 'string')

        transformed[index] = string.upper(item)
    end

    assert(#transformed == #items)

    return transformed
end

function M.run(items)
    local valid, validation_error = validate_items(items)

    if not valid then
        return nil, validation_error
    end

    return transform_items(items), nil
end

return M
```

## Final rule

A Tiger Style Lua codebase should make correctness visible.

A reviewer should be able to identify limits, invariants, state transitions, resource owners,
failure behavior, and privileged operations without reconstructing them from hidden conventions.

## Sources

- TigerBeetle Tiger Style:
  <https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md>
- Lua Reference Manuals:
  <https://www.lua.org/manual/>
- Neovim documentation:
  <https://neovim.io/doc/>
