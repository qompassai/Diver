<!--
===============================================================================
TIGER_STYLE_LUA.md
Tiger Style for Lua
===============================================================================

A safety-first Lua coding standard, written as Markdown.

Priority:
    1. Safety
    2. Performance
    3. Developer Experience

This document is an independent Lua adaptation of TigerBeetle's Tiger Style
engineering philosophy. It is not an official TigerBeetle document.

Rendering layers used by this file:
    - CommonMark/GFM Markdown
    - Markdown images
    - Raw HTML
    - HTML5 video
    - Inline SVG
    - Optional CSS
    - Optional JavaScript
    - LaTeX/MathJax-compatible mathematics

Renderer note:
    Markdown renderers differ. GitHub intentionally sanitizes active content,
    including JavaScript and much custom CSS. The Markdown, images, links,
    <details>, many HTML elements, and supported math remain useful there.
    For the complete HTML/CSS/JS/video experience, use a trusted local Markdown
    renderer that permits raw HTML and scripts.

===============================================================================
-->

<style>
:root {
  --tiger-bg: #07111f;
  --tiger-panel: #0b1728;
  --tiger-panel-2: #10233b;
  --tiger-line: #244764;
  --tiger-text: #e7f2ff;
  --tiger-muted: #9eb6ca;
  --tiger-blue: #33ccff;
  --tiger-blue-2: #7ee7ff;
  --tiger-warning: #ffd580;
  --tiger-danger: #ff7f93;
}

.tiger-card {
  border: 1px solid var(--tiger-line);
  border-radius: 12px;
  padding: 1rem 1.2rem;
  margin: 1rem 0;
  background: var(--tiger-panel);
  color: var(--tiger-text);
}

.tiger-priority {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: .75rem;
}

.tiger-priority > div {
  border: 1px solid var(--tiger-line);
  border-radius: 10px;
  padding: 1rem;
  text-align: center;
  background: var(--tiger-panel-2);
}

.tiger-accent {
  color: var(--tiger-blue);
}

.tiger-muted {
  color: var(--tiger-muted);
}

.tiger-warning {
  border-left: 4px solid var(--tiger-warning);
  padding-left: 1rem;
}

.tiger-danger {
  border-left: 4px solid var(--tiger-danger);
  padding-left: 1rem;
}

.tiger-media {
  max-width: 100%;
  border: 1px solid var(--tiger-line);
  border-radius: 12px;
}

.tiger-code-note {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

@media (max-width: 780px) {
  .tiger-priority {
    grid-template-columns: 1fr;
  }
}

@media print {
  .tiger-no-print {
    display: none;
  }
}
</style>

# Tiger Style for Lua

> **Safety first. Performance second. Developer experience third.**

**Version:** 1.0  
**Primary targets:** Lua 5.4+, LuaJIT, Neovim Lua, embedded Lua  
**Recommended maximum line width:** 100 columns  
**Recommended ordinary function review threshold:** 70 lines

<div class="tiger-card">

This guide applies Tiger Style engineering ideas to Lua without pretending that
Lua is Zig. Lua is dynamically typed, garbage-collected, highly embeddable, and
intentionally permissive. Tiger Style Lua therefore emphasizes explicit runtime
contracts, bounded work, narrow data shapes, disciplined resource ownership,
predictable mutation, direct process APIs, deterministic behavior, and testing
at boundaries.

</div>

<div class="tiger-priority">
  <div><strong>1. Safety</strong><br><span class="tiger-muted">Correctness, invariants, bounds, ownership.</span></div>
  <div><strong>2. Performance</strong><br><span class="tiger-muted">Predictable resource use, batching, measured hot paths.</span></div>
  <div><strong>3. Developer Experience</strong><br><span class="tiger-muted">Clarity, reviewability, maintainability, tooling.</span></div>
</div>

---

## Table of Contents

1. [The Tiger Style Contract](#1-the-tiger-style-contract)
2. [Lua Runtime Assumptions](#2-lua-runtime-assumptions)
3. [File and Module Layout](#3-file-and-module-layout)
4. [Assertions, Preconditions, and Postconditions](#4-assertions-preconditions-and-postconditions)
5. [Bound Everything](#5-bound-everything)
6. [Control Flow](#6-control-flow)
7. [Error Handling](#7-error-handling)
8. [Nil, False, and Defaults](#8-nil-false-and-defaults)
9. [Numbers, Integers, Counts, and Units](#9-numbers-integers-counts-and-units)
10. [Tables](#10-tables)
11. [State and Mutation](#11-state-and-mutation)
12. [Function Design](#12-function-design)
13. [Scope](#13-scope)
14. [Resource Lifetime](#14-resource-lifetime)
15. [Memory and Allocation](#15-memory-and-allocation)
16. [Performance](#16-performance)
17. [Determinism](#17-determinism)
18. [Security](#18-security)
19. [Filesystem Safety](#19-filesystem-safety)
20. [Processes and Shells](#20-processes-and-shells)
21. [Coroutines and Async Work](#21-coroutines-and-async-work)
22. [Naming](#22-naming)
23. [Formatting](#23-formatting)
24. [Comments and Documentation](#24-comments-and-documentation)
25. [Dependencies](#25-dependencies)
26. [Neovim Lua](#26-neovim-lua)
27. [Arch Linux Development](#27-arch-linux-development)
28. [Testing](#28-testing)
29. [Review Checklist](#29-review-checklist)
30. [Anti-Patterns](#30-anti-patterns)
31. [Reference Module](#31-reference-module)
32. [Images](#32-images)
33. [HTML](#33-html)
34. [CSS](#34-css)
35. [SVG Diagrams](#35-svg-diagrams)
36. [Video](#36-video)
37. [JavaScript](#37-javascript)
38. [LaTeX and Mathematics](#38-latex-and-mathematics)
39. [Renderer Compatibility](#39-renderer-compatibility)
40. [Suggested Repository Layout](#40-suggested-repository-layout)
41. [Sources](#41-sources)

---

## 1. The Tiger Style Contract

Tiger Style is not merely formatting. It is a hierarchy of engineering
priorities.

\[
\boxed{\text{Safety} \;>\; \text{Performance} \;>\; \text{Developer Experience}}
\]

When goals conflict:

1. Do not sacrifice an invariant for convenience.
2. Do not permit unbounded behavior for a small performance improvement.
3. Do not hide failure merely to make an API look simpler.
4. Do not optimize code whose correctness model is unclear.
5. Do not add abstraction when explicit code is safer to audit.

### The working principle

> Make invalid states hard to construct, easy to detect, and impossible to
> silently preserve.

### A Tiger Style Lua function should make these questions easy to answer

- What inputs are permitted?
- What inputs are rejected?
- What is the maximum amount of work?
- What state may change?
- Who owns each resource?
- What happens on failure?
- Which postconditions must be true when the function returns?
- Can asynchronous state become stale?
- Is output deterministic?
- What external capability does this code invoke?

---

## 2. Lua Runtime Assumptions

Lua implementations differ.

Do not write a module that silently assumes one of these unless the project
declares it:

- Lua 5.1
- Lua 5.2
- Lua 5.3
- Lua 5.4+
- LuaJIT
- Neovim's Lua environment
- OpenResty
- an embedded Lua runtime

```lua
local M = {}

M.runtime = {
    lua_version = _VERSION,
    has_jit = type(jit) == "table",
    has_neovim = type(vim) == "table",
}

return M
```

### Runtime-sensitive areas

- integer representation;
- bit operations;
- `utf8`;
- `table.unpack` versus `unpack`;
- `load()` signatures;
- garbage-collector behavior;
- LuaJIT FFI;
- filesystem/process APIs supplied by the host;
- coroutine scheduling;
- C-module ABI compatibility.

Tiger Style rule:

> Put runtime-specific behavior behind a small, explicit boundary.

---

## 3. File and Module Layout

A Lua module should read top-to-bottom.

Recommended order:

1. header and purpose;
2. standard/host API aliases;
3. module table;
4. constants;
5. LuaCATS types;
6. validation helpers;
7. private leaf helpers;
8. orchestration functions;
9. `setup()` when required;
10. `return M`.

```lua
-- /project/lua/tiger/example.lua
local api = vim.api
local fs = vim.fs

local M = {}

local ITEM_COUNT_MAX = 4096

---@class TigerOptions
---@field root string
---@field item_count_max integer?

local function validate_options(options)
    assert(type(options) == "table")
    assert(type(options.root) == "string")
end

local function collect_items(options)
    -- Leaf implementation.
end

function M.run(options)
    validate_options(options)

    return collect_items(options)
end

return M
```

### Avoid import clutter

Alias frequently used APIs only when it improves clarity:

```lua
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
```

Do not alias everything merely to save characters.

---

## 4. Assertions, Preconditions, and Postconditions

Assertions are executable design documentation.

Use assertions for programmer errors and violated internal invariants.

Use normal error returns for expected operating failures.

### Good assertion targets

- type assumptions;
- index bounds;
- count bounds;
- state-machine state;
- internal ownership assumptions;
- postconditions;
- impossible branches.

```lua
local function copy_slice(values, first_index, item_count)
    assert(type(values) == "table")
    assert(type(first_index) == "number")
    assert(type(item_count) == "number")
    assert(first_index % 1 == 0)
    assert(item_count % 1 == 0)
    assert(first_index >= 1)
    assert(item_count >= 0)

    local final_index = first_index + item_count - 1

    if item_count > 0 then
        assert(final_index <= #values)
    end

    local result = {}

    for offset = 0, item_count - 1 do
        result[#result + 1] = values[first_index + offset]
    end

    assert(#result == item_count)

    return result
end
```

### Split compound assertions

Prefer:

```lua
assert(index >= 1)
assert(index <= count)
```

over:

```lua
assert(index >= 1 and index <= count)
```

The first form identifies the violated invariant more precisely.

### Do not misuse assertions for external input

Bad:

```lua
assert(user_path ~= "")
```

Better:

```lua
if type(user_path) ~= "string" then
    return nil, "path must be a string"
end

if user_path == "" then
    return nil, "path must not be empty"
end
```

---

## 5. Bound Everything

Every system has finite resources.

Encode those limits deliberately.

### Bound

- loops;
- retries;
- recursion;
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
- history;
- log retention.

```lua
local RETRY_COUNT_MAX = 4

local function run_with_retry(operation)
    assert(type(operation) == "function")

    for attempt = 1, RETRY_COUNT_MAX do
        local ok, result = operation(attempt)

        if ok then
            return result, nil
        end

        if attempt == RETRY_COUNT_MAX then
            return nil, "retry budget exhausted"
        end
    end

    error("unreachable")
end
```

### Explicit infinite loops

If a process genuinely runs forever, the lifecycle still needs a bound or an
external termination invariant.

```lua
while service.running do
    assert(service.generation == generation)

    service_step(service)
end
```

Do not write an unexplained:

```lua
while true do
end
```

---

## 6. Control Flow

Prefer control flow that can be verified locally.

### Rules

- push `if` decisions upward;
- push `for` loops downward;
- keep leaf loops branch-light;
- avoid clever short-circuit side effects;
- avoid recursion for attacker-controlled/deep structures;
- prefer positive conditions;
- make impossible states explicit.

```lua
local function process_input(config, input)
    validate_config(config)
    validate_input(input)

    if input.kind == "file" then
        return process_file(config, input)
    end

    if input.kind == "buffer" then
        return process_buffer(config, input)
    end

    return nil, "unsupported input kind"
end
```

### Do not use boolean operators as statement syntax

Avoid:

```lua
ready and start()
```

Prefer:

```lua
if ready then
    start()
end
```

---

## 7. Error Handling

Every fallible operation must have a deliberate failure path.

### Simple leaf convention

```lua
return value, nil
```

or:

```lua
return nil, "descriptive error"
```

### Never silently discard `pcall`

Bad:

```lua
pcall(do_work)
```

Better:

```lua
local ok, result = pcall(do_work)

if not ok then
    return nil, "do_work failed: " .. tostring(result)
end

return result, nil
```

### Preserve context

A good error describes the failed operation, not merely the low-level symptom.

```lua
local file, open_error = io.open(path, "rb")

if file == nil then
    return nil, "failed to open configuration: " .. tostring(open_error)
end
```

---

## 8. Nil, False, and Defaults

`nil` and `false` are both falsey.

That makes this dangerous when `false` is a valid setting:

```lua
local enabled = options.enabled or true
```

Use:

```lua
local enabled

if options.enabled == nil then
    enabled = true
else
    enabled = options.enabled
end
```

### Give `nil` one documented meaning

Do not let `nil` ambiguously mean all of:

- absent;
- unknown;
- disabled;
- error;
- default;
- not initialized.

Use a richer state representation when multiple meanings are required.

---

## 9. Numbers, Integers, Counts, and Units

The runtime may use the same numeric type for semantically different values.

Your code should not.

### Distinguish

- `item_index`
- `item_count`
- `buffer_size_bytes`
- `offset_bytes`
- `capacity`
- `timeout_ms`
- `retry_count`
- `generation_id`

```lua
local function is_integer(value)
    if type(value) ~= "number" then
        return false
    end

    if value ~= value then
        return false
    end

    if value == math.huge or value == -math.huge then
        return false
    end

    return value % 1 == 0
end
```

### Name units last

Prefer:

```text
timeout_ms
timeout_ms_max
payload_size_bytes
cache_size_bytes_max
```

over ambiguous names such as:

```text
timeout
size
max
len
```

---

## 10. Tables

Lua tables are arrays, maps, records, sets, objects, and namespaces.

That flexibility needs discipline.

### Rules

- do not mix array/map semantics accidentally;
- do not rely on `#table` for sparse arrays;
- do not rely on `pairs()` ordering;
- avoid fields that change type over time;
- prefer constructors;
- keep table invariants documented;
- use metatables only when the semantic gain is substantial.

```lua
local function new_queue(capacity)
    assert(type(capacity) == "number")
    assert(capacity % 1 == 0)
    assert(capacity > 0)

    return {
        capacity = capacity,
        count = 0,
        first_index = 1,
        values = {},
    }
end
```

### Deterministic map traversal

```lua
local function sorted_keys(values)
    local keys = {}

    for key in pairs(values) do
        keys[#keys + 1] = key
    end

    table.sort(keys)

    return keys
end
```

---

## 11. State and Mutation

Mutable state should have a clear owner.

### Prefer this model

```text
input
  │
  ▼
validate
  │
  ▼
control function
  │
  ├────> pure/bounded leaf work
  │
  ▼
validate delta
  │
  ▼
single commit point
```

### Rules

- mutate at a small number of obvious points;
- separate computation from mutation;
- document valid state transitions;
- copy caller-owned configuration if later mutation is possible;
- avoid shared module state as a hidden message bus;
- avoid implicitly coupled globals.

---

## 12. Function Design

Ordinary functions should be small enough to understand without scrolling
through multiple conceptual phases.

### Recommended threshold

\[
L_{\text{function}} \le 70
\]

where \(L_{\text{function}}\) is the function's physical source-line count.

This is a review threshold, not an excuse to fragment cohesive logic into dozens
of trivial functions.

### Prefer named option tables

Risky:

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

---

## 13. Scope

Make variable lifetime visually obvious.

```lua
for index = 1, #items do
    local item = items[index]
    assert(item ~= nil)

    local normalized = normalize_item(item)
    emit(normalized)
end
```

### Rules

- declare locals near first use;
- compute derived values near consumption;
- do not carry mutable derived values across async boundaries;
- minimize closure captures;
- avoid shadowing when it harms reviewability.

---

## 14. Resource Lifetime

Every resource should have one clear owner.

Examples:

- files;
- sockets;
- `vim.uv` handles;
- subprocesses;
- timers;
- temporary directories;
- temporary files;
- FFI allocations;
- registrations/autocmds with lifecycle semantics.

```lua
local file, open_error = io.open(path, "rb")

if file == nil then
    return nil, open_error
end

local data, read_error = file:read("*a")
file:close()

if data == nil then
    return nil, read_error
end

return data, nil
```

### Prefer idempotent teardown

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

---

## 15. Memory and Allocation

Lua is garbage-collected, so the original static-allocation idea cannot be
translated literally.

Translate the intent:

> Memory use should be predictable, bounded, and visible.

### Rules

- cap caches;
- cap histories;
- cap queues;
- remove references to large finished objects;
- avoid accidental closure retention;
- avoid repeated giant table copies;
- avoid repeated giant string concatenation;
- treat LuaJIT FFI allocations as manual resources;
- do not force GC in hot paths without measurements.

For large string generation:

```lua
local fragments = {}

for index = 1, #items do
    fragments[index] = render_item(items[index])
end

local output = table.concat(fragments, "\n")
```

---

## 16. Performance

Performance starts with design.

### Consider

\[
T_{\text{total}}
=
T_{\text{network}}
+
T_{\text{disk}}
+
T_{\text{memory}}
+
T_{\text{cpu}}
+
T_{\text{coordination}}
\]

The largest meaningful term deserves attention first.

### Rules

- batch system calls;
- batch RPC;
- batch diagnostics;
- batch redraw work;
- avoid repeated filesystem probing;
- separate control plane from data plane;
- make hot loops simple;
- avoid unnecessary allocations in measured hot loops;
- profile after implementation;
- do not postpone basic capacity/resource modeling until profiling.

---

## 17. Determinism

Determinism improves testing, reproducibility, and debugging.

### Rules

- sort map keys before serialization;
- never rely on `pairs()` order;
- normalize platform-sensitive output;
- pass explicit options;
- seed pseudo-random tests;
- make locale/timezone assumptions explicit;
- pin external tool behavior when output parsing depends on versions.

```lua
local function stable_pairs(values)
    local keys = sorted_keys(values)
    local index = 0

    return function()
        index = index + 1

        local key = keys[index]

        if key == nil then
            return nil
        end

        return key, values[key]
    end
end
```

---

## 18. Security

Lua can invoke highly privileged capabilities.

Treat these as security boundaries:

- `os.execute`;
- `io.popen`;
- `load`;
- `loadfile`;
- `dofile`;
- `require` from writable/untrusted search paths;
- `package.loadlib`;
- LuaJIT FFI;
- Neovim `vim.system`;
- filesystem writes;
- shell command construction;
- dynamic plugin loading.

### Never concatenate untrusted values into a shell command

Bad:

```lua
os.execute("git status -- " .. user_path)
```

Good in Neovim:

```lua
local result = vim.system({
    "git",
    "status",
    "--porcelain=v1",
    "--",
    user_path,
}, {
    text = true,
}):wait()

if result.code ~= 0 then
    return nil, result.stderr
end

return result.stdout, nil
```

### Capability rule

Untrusted Lua should not receive arbitrary access to:

```text
os
io
debug
package
ffi
vim.system
vim.uv
```

An empty environment passed to `load()` is **not** a complete security sandbox.

---

## 19. Filesystem Safety

Validate filesystem paths before privileged use.

```lua
local function validate_path(path)
    if type(path) ~= "string" then
        return nil, "path must be a string"
    end

    if path == "" then
        return nil, "path must not be empty"
    end

    if path:find("%z") ~= nil then
        return nil, "path contains NUL"
    end

    return true, nil
end
```

### Rules

- normalize paths before policy checks;
- define symlink behavior;
- do not implement containment with naive string prefixes;
- use controlled temporary directories;
- prefer write-temp + atomic rename for important file replacement;
- avoid overwriting sensitive files accidentally;
- use exclusive creation where appropriate.

---

## 20. Processes and Shells

Prefer direct process execution.

### Good model

```lua
vim.system({
    "clang-tidy",
    "--quiet",
    "--",
    filename,
}, {
    cwd = root,
    text = true,
})
```

### Process checklist

- executable is explicit;
- each argv element is separate;
- user path is behind `--` if supported;
- cwd is explicit;
- timeout is defined where hangs matter;
- output is bounded where possible;
- exit code is checked;
- signal is checked where exposed;
- stderr is not mistaken for failure by itself;
- machine-readable output is preferred.

---

## 21. Coroutines and Async Work

A precondition can become false after a yield or callback delay.

Use generation tokens.

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

### Async rules

- bound outstanding work;
- reject stale callbacks;
- cancel owned work during teardown;
- revalidate buffers/windows/files after asynchronous delay;
- minimize callback captures;
- avoid mutation of deleted Neovim resources.

---

## 22. Naming

Use `snake_case`.

Prefer domain language over abbreviations.

### Good

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

### Avoid

```text
n
sz
tm
x
tmp2
data2
stuff
obj
```

Short names are acceptable for tiny conventional local roles such as a compact
loop index, but the surrounding code must remain obvious.

---

## 23. Formatting

Recommended:

- 4-space indentation;
- maximum 100 columns;
- one statement per line;
- trailing commas in multiline structures;
- blank lines between conceptual phases;
- deterministic formatter output.

Example `stylua.toml`:

```toml
column_width = 100
indent_type = "Spaces"
indent_width = 4
line_endings = "Unix"
quote_style = "AutoPreferSingle"
call_parentheses = "Always"
```

### Formatting invariant

\[
C_{\text{line}} \le 100
\]

for ordinary source lines.

---

## 24. Comments and Documentation

Comments explain **why**, **how**, constraints, and invariants.

Bad:

```lua
-- Increment count.
count = count + 1
```

Better:

```lua
-- Increment only after insertion succeeds so count remains a committed-item count.
count = count + 1
```

### LuaCATS

Use structured annotations where supported:

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

---

## 25. Dependencies

Every dependency increases:

- supply-chain surface;
- compatibility surface;
- startup work;
- installation complexity;
- update burden;
- transitive risk.

### Add a dependency only when it earns its cost

Prefer:

1. Lua standard library;
2. trusted host APIs;
3. small audited internal code;
4. mature external dependency.

Pin versions or commits when reproducibility matters.

Do not download executable dependencies at runtime in trusted paths unless that
behavior is explicitly part of the product's security design.

---

## 26. Neovim Lua

For modern Neovim configurations:

- prefer `vim.api`;
- prefer `vim.fs`;
- prefer `vim.system`;
- prefer `vim.uv`;
- avoid deprecated APIs;
- keep `setup()` idempotent;
- group autocmds;
- clear/recreate owned groups intentionally;
- validate asynchronous buffer/window handles.

```lua
local group = vim.api.nvim_create_augroup("TigerLua", {
    clear = true,
})

vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.lua",
    callback = function(event)
        assert(type(event) == "table")
        assert(type(event.buf) == "number")

        if not vim.api.nvim_buf_is_valid(event.buf) then
            return
        end

        validate_buffer(event.buf)
    end,
})
```

### Module rule

`require("module")` should preferably load definitions rather than unexpectedly
perform large global side effects.

---

## 27. Arch Linux Development

For an Arch Linux development environment:

```bash
stylua --check .
luacheck .
lua tests/run.lua
```

### Rules

- use `pacman` for system packages when suitable;
- review AUR `PKGBUILD` files for security-sensitive tooling;
- never run project language package managers with `sudo`;
- do not build ordinary project dependencies as root;
- keep repository tooling reproducible;
- prefer argv-safe direct invocation over shell pipelines in application code.

---

## 28. Testing

Test boundaries before happy-path permutations.

For a maximum \(M\), test:

\[
\{0,\;1,\;M-1,\;M,\;M+1\}
\]

when those values are meaningful.

### Test

- zero;
- one;
- maximum;
- maximum plus one;
- `nil`;
- `false`;
- malformed input;
- cancellation;
- retry exhaustion;
- stale callbacks;
- cleanup after failure;
- invalid state transitions;
- deterministic ordering;
- partial external output.

```lua
local function test_capacity_boundary()
    local queue = new_queue(2)

    assert(queue_push(queue, "a"))
    assert(queue_push(queue, "b"))

    local ok, push_error = queue_push(queue, "c")

    assert(ok == nil)
    assert(push_error == "queue capacity exhausted")
    assert(queue.count == 2)
end
```

---

## 29. Review Checklist

- [ ] Safety outranks performance and developer convenience.
- [ ] External input is validated before privileged use.
- [ ] Internal invariants use meaningful assertions.
- [ ] Loops over externally influenced data are bounded.
- [ ] Retries have a maximum.
- [ ] Queues/caches/histories have capacity limits.
- [ ] `nil` and `false` semantics are deliberate.
- [ ] Index/count/size/unit semantics are explicit.
- [ ] Every resource has one clear owner.
- [ ] Cleanup paths exist for failure.
- [ ] Errors are not discarded.
- [ ] Shell command strings do not contain interpolated untrusted input.
- [ ] External commands use argv arrays where possible.
- [ ] State mutation is centralized.
- [ ] Async callbacks reject stale results.
- [ ] Output is deterministic where persistence/testing requires it.
- [ ] Dependencies are justified.
- [ ] Ordinary functions stay near or below 70 lines.
- [ ] Ordinary lines stay at or below 100 columns.
- [ ] Comments explain intent rather than syntax.
- [ ] Tests cover boundaries and failure cleanup.

---

## 30. Anti-Patterns

```lua
-- Hidden global mutation.
state = state or {}

-- Shell injection surface.
os.execute("tool " .. user_input)

-- Swallowed failure.
pcall(do_work)

-- Unbounded retry.
while true do
    if try_again() then
        break
    end
end

-- False is accidentally replaced by true.
local enabled = options.enabled or true

-- Sparse-table length assumption.
local count = #possibly_sparse

-- Untrusted code execution.
local chunk = load(user_text)
chunk()
```

---

## 31. Reference Module

```lua
local M = {}

local ITEM_COUNT_MAX = 1024

local function validate_items(items)
    if type(items) ~= "table" then
        return nil, "items must be a table"
    end

    if #items > ITEM_COUNT_MAX then
        return nil, "item limit exceeded"
    end

    return true, nil
end

local function transform_items(items)
    assert(type(items) == "table")
    assert(#items <= ITEM_COUNT_MAX)

    local transformed = {}

    for index = 1, #items do
        local item = items[index]

        assert(type(item) == "string")

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

---

# Multimedia and Rich Markdown

The following sections make this file useful as both a coding standard and a
rendering test document.

---

## 32. Images

### Standard Markdown image

```markdown
![Tiger Style Lua architecture](assets/tiger-style-lua.webp)
```

Rendered form:

![Tiger Style Lua architecture](assets/tiger-style-lua.webp)

### HTML image with explicit dimensions

```html
<img
  src="assets/tiger-style-lua.webp"
  alt="Tiger Style Lua architecture"
  width="960"
  loading="lazy"
  decoding="async">
```

<img
  class="tiger-media"
  src="assets/tiger-style-lua.webp"
  alt="Tiger Style Lua architecture"
  width="960"
  loading="lazy"
  decoding="async">

### Responsive `<picture>`

```html
<picture>
  <source srcset="assets/tiger-style-lua.avif" type="image/avif">
  <source srcset="assets/tiger-style-lua.webp" type="image/webp">
  <img
    src="assets/tiger-style-lua.png"
    alt="Tiger Style Lua architecture"
    loading="lazy">
</picture>
```

<picture>
  <source srcset="assets/tiger-style-lua.avif" type="image/avif">
  <source srcset="assets/tiger-style-lua.webp" type="image/webp">
  <img
    class="tiger-media"
    src="assets/tiger-style-lua.png"
    alt="Tiger Style Lua architecture"
    loading="lazy">
</picture>

---

## 33. HTML

Markdown can contain raw HTML when the renderer permits it.

```html
<details>
  <summary>Tiger Style invariant</summary>

  A successful operation must leave state internally consistent.
</details>
```

<details>
  <summary><strong>Tiger Style invariant</strong></summary>

  A successful operation must leave state internally consistent.

</details>

### HTML table

<table>
  <thead>
    <tr>
      <th>Priority</th>
      <th>Question</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Safety</td>
      <td>Can this state become invalid or unbounded?</td>
    </tr>
    <tr>
      <td>Performance</td>
      <td>What resource dominates the workload?</td>
    </tr>
    <tr>
      <td>Developer Experience</td>
      <td>Can a reviewer understand the contract quickly?</td>
    </tr>
  </tbody>
</table>

---

## 34. CSS

This Markdown document already contains a `<style>` block near its top.

A renderer that allows raw CSS can use classes such as:

```html
<div class="tiger-card">
  Styled content.
</div>
```

<div class="tiger-card">
<strong>Tiger Style:</strong> styling is progressive enhancement. The underlying
documentation must remain understandable if custom CSS is stripped.
</div>

### Security rule for documentation CSS

Do not depend on remote CSS from an untrusted origin merely to make technical
documentation readable.

Documentation should remain semantically useful without styling.

---

## 35. SVG Diagrams

Inline SVG is useful for diagrams because it is:

- vector-based;
- text-searchable;
- resolution-independent;
- embeddable directly in Markdown/HTML;
- script-free when used carefully.

### Tiger Style priority diagram

<svg
  class="tiger-media"
  viewBox="0 0 1000 260"
  role="img"
  aria-labelledby="tiger-priority-title tiger-priority-desc"
  xmlns="http://www.w3.org/2000/svg">

  <title id="tiger-priority-title">Tiger Style priority order</title>
  <desc id="tiger-priority-desc">
    Safety precedes performance, which precedes developer experience.
  </desc>

  <defs>
    <marker
      id="tiger-arrow"
      markerWidth="10"
      markerHeight="10"
      refX="8"
      refY="3"
      orient="auto"
      markerUnits="strokeWidth">
      <path d="M0,0 L0,6 L9,3 z" fill="#7ee7ff"/>
    </marker>
  </defs>

  <rect x="40" y="70" width="250" height="100" rx="16"
        fill="#10233b" stroke="#33ccff" stroke-width="3"/>
  <text x="165" y="113" text-anchor="middle"
        fill="#e7f2ff" font-size="26" font-weight="700">1. Safety</text>
  <text x="165" y="145" text-anchor="middle"
        fill="#9eb6ca" font-size="16">Correctness and bounds</text>

  <rect x="375" y="70" width="250" height="100" rx="16"
        fill="#10233b" stroke="#33ccff" stroke-width="3"/>
  <text x="500" y="113" text-anchor="middle"
        fill="#e7f2ff" font-size="26" font-weight="700">2. Performance</text>
  <text x="500" y="145" text-anchor="middle"
        fill="#9eb6ca" font-size="16">Predictable resource use</text>

  <rect x="710" y="70" width="250" height="100" rx="16"
        fill="#10233b" stroke="#33ccff" stroke-width="3"/>
  <text x="835" y="108" text-anchor="middle"
        fill="#e7f2ff" font-size="24" font-weight="700">3. Developer</text>
  <text x="835" y="137" text-anchor="middle"
        fill="#e7f2ff" font-size="24" font-weight="700">Experience</text>

  <line x1="290" y1="120" x2="365" y2="120"
        stroke="#7ee7ff" stroke-width="4"
        marker-end="url(#tiger-arrow)"/>

  <line x1="625" y1="120" x2="700" y2="120"
        stroke="#7ee7ff" stroke-width="4"
        marker-end="url(#tiger-arrow)"/>
</svg>

### State flow diagram

<svg
  class="tiger-media"
  viewBox="0 0 1000 440"
  role="img"
  aria-labelledby="state-flow-title"
  xmlns="http://www.w3.org/2000/svg">

  <title id="state-flow-title">Tiger Style Lua state flow</title>

  <defs>
    <marker
      id="state-arrow"
      markerWidth="10"
      markerHeight="10"
      refX="8"
      refY="3"
      orient="auto"
      markerUnits="strokeWidth">
      <path d="M0,0 L0,6 L9,3 z" fill="#33ccff"/>
    </marker>
  </defs>

  <g fill="#10233b" stroke="#33ccff" stroke-width="3">
    <rect x="60" y="70" width="210" height="75" rx="12"/>
    <rect x="395" y="70" width="210" height="75" rx="12"/>
    <rect x="730" y="70" width="210" height="75" rx="12"/>
    <rect x="395" y="250" width="210" height="75" rx="12"/>
  </g>

  <g fill="#e7f2ff" font-size="22" text-anchor="middle">
    <text x="165" y="116">Validated input</text>
    <text x="500" y="116">Control function</text>
    <text x="835" y="116">Pure leaf work</text>
    <text x="500" y="296">Commit mutation</text>
  </g>

  <g stroke="#33ccff" stroke-width="4" marker-end="url(#state-arrow)">
    <line x1="270" y1="108" x2="385" y2="108"/>
    <line x1="605" y1="108" x2="720" y2="108"/>
    <line x1="835" y1="145" x2="585" y2="245"/>
    <line x1="500" y1="145" x2="500" y2="240"/>
  </g>
</svg>

### External SVG image

```markdown
![State flow](assets/state-flow.svg)
```

---

## 36. Video

Markdown has no universal native video syntax, so use HTML5.

```html
<video
  controls
  preload="metadata"
  width="960"
  poster="assets/tiger-style-demo-poster.webp">
  <source src="assets/tiger-style-demo.webm" type="video/webm">
  <source src="assets/tiger-style-demo.mp4" type="video/mp4">
  Your renderer cannot play this video.
</video>
```

<video
  class="tiger-media"
  controls
  preload="metadata"
  width="960"
  poster="assets/tiger-style-demo-poster.webp">
  <source src="assets/tiger-style-demo.webm" type="video/webm">
  <source src="assets/tiger-style-demo.mp4" type="video/mp4">
  Your renderer cannot play this video.
</video>

### Recommended video policy

- default to `controls`;
- default to `preload="metadata"`;
- do not autoplay documentation videos;
- provide WebM and MP4 when broad browser compatibility matters;
- include a poster image;
- include explanatory text next to the video;
- never make video the only place where important documentation exists.

### Optional direct link fallback

```markdown
[Open the Tiger Style demo video](assets/tiger-style-demo.webm)
```

[Open the Tiger Style demo video](assets/tiger-style-demo.webm)

---

## 37. JavaScript

<div class="tiger-warning">

**Important:** GitHub and many secure Markdown renderers remove or disable
`<script>` elements. JavaScript in documentation should therefore be optional
progressive enhancement, never a requirement for understanding the guide.

</div>

A trusted local renderer that permits scripts can use:

```html
<button id="tiger-toggle">Toggle Tiger Style note</button>

<div id="tiger-js-note">
  JavaScript is optional. The documentation remains readable without it.
</div>

<script>
(() => {
  "use strict";

  const button = document.getElementById("tiger-toggle");
  const note = document.getElementById("tiger-js-note");

  if (!(button instanceof HTMLButtonElement)) {
    return;
  }

  if (!(note instanceof HTMLElement)) {
    return;
  }

  button.addEventListener("click", () => {
    note.hidden = !note.hidden;
  });
})();
</script>
```

<div class="tiger-no-print">
  <button id="tiger-toggle" type="button">Toggle Tiger Style note</button>
  <div id="tiger-js-note" class="tiger-card">
    JavaScript is optional. The documentation remains readable without it.
  </div>
</div>

<script>
(() => {
  "use strict";

  const button = document.getElementById("tiger-toggle");
  const note = document.getElementById("tiger-js-note");

  if (!(button instanceof HTMLButtonElement)) {
    return;
  }

  if (!(note instanceof HTMLElement)) {
    return;
  }

  button.addEventListener("click", () => {
    note.hidden = !note.hidden;
  });
})();
</script>

### JavaScript documentation rules

1. Do not load arbitrary third-party scripts.
2. Prefer no JavaScript when native HTML solves the problem.
3. Use `<details>` and `<summary>` for disclosure widgets.
4. Keep JavaScript isolated from the content model.
5. Validate queried DOM elements before use.
6. Avoid inline event attributes such as `onclick="..."`.
7. Use event listeners.
8. Do not insert untrusted strings with `innerHTML`.
9. Prefer `textContent` for text.
10. Keep documentation useful when scripting is disabled.

---

## 38. LaTeX and Mathematics

Many Markdown environments support LaTeX-style mathematics.

### Inline math

Tiger Style priorities may be represented as
\(S > P > D\), where \(S\) is safety, \(P\) performance, and \(D\) developer
experience.

### Display math

\[
\text{Priority}(S) > \text{Priority}(P) > \text{Priority}(D)
\]

### Capacity invariant

For a bounded queue:

\[
0 \leq q_{\text{count}} \leq q_{\text{capacity}}
\]

A push operation is permitted only when:

\[
q_{\text{count}} < q_{\text{capacity}}
\]

After a successful push:

\[
q'_{\text{count}} = q_{\text{count}} + 1
\]

### Slice invariant

For Lua's conventional one-based indexing:

\[
1 \leq i_{\text{first}}
\]

\[
0 \leq n_{\text{items}}
\]

For a non-empty slice:

\[
i_{\text{first}} + n_{\text{items}} - 1 \leq n_{\text{array}}
\]

### Performance model

\[
T_{\text{request}}
=
T_{\text{queue}}
+
T_{\text{I/O}}
+
T_{\text{compute}}
+
T_{\text{serialization}}
\]

### Bounded memory model

\[
M_{\text{retained}}
\leq
M_{\text{cache,max}}
+
M_{\text{queue,max}}
+
M_{\text{active,max}}
\]

The point is not mathematical decoration. The equations make invariants and
capacity assumptions explicit.

---

## 39. Renderer Compatibility

No single Markdown engine supports every rich feature identically.

| Feature | Plain Markdown | GitHub/GFM | Trusted HTML-capable renderer |
|---|---:|---:|---:|
| Headings/lists/code | Yes | Yes | Yes |
| Markdown images | Yes | Yes | Yes |
| Raw HTML | Renderer-dependent | Limited/sanitized | Usually |
| `<details>` | No | Yes | Usually |
| Inline SVG | Renderer-dependent | Sanitized/limited | Usually |
| HTML5 `<video>` | No | Limited | Usually |
| `<style>` | No | Sanitized/removed | Usually |
| `<script>` | No | Removed | Optional |
| LaTeX math | Extension | Supported contexts | Math extension/MathJax/KaTeX |
| Mermaid | Extension | Supported by some hosts | Plugin-dependent |

### Best portability strategy

Use this hierarchy:

1. semantic Markdown;
2. standard links and images;
3. accessible HTML;
4. inline SVG;
5. CSS as progressive enhancement;
6. video with a link fallback;
7. JavaScript only for optional behavior.

---

## 40. Suggested Repository Layout

```text
docs/
├── TIGER_STYLE_LUA.md
└── assets/
    ├── tiger-style-lua.avif
    ├── tiger-style-lua.webp
    ├── tiger-style-lua.png
    ├── state-flow.svg
    ├── tiger-style-demo-poster.webp
    ├── tiger-style-demo.webm
    └── tiger-style-demo.mp4
```

### Arch Linux media conversion examples

Image:

```bash
magick input.png -strip -quality 82 docs/assets/tiger-style-lua.webp
```

Video:

```bash
ffmpeg \
  -i input.mkv \
  -map_metadata -1 \
  -c:v libvpx-vp9 \
  -crf 31 \
  -b:v 0 \
  -c:a libopus \
  docs/assets/tiger-style-demo.webm
```

MP4 fallback:

```bash
ffmpeg \
  -i input.mkv \
  -map_metadata -1 \
  -c:v libx264 \
  -crf 22 \
  -preset medium \
  -pix_fmt yuv420p \
  -c:a aac \
  -movflags +faststart \
  docs/assets/tiger-style-demo.mp4
```

Poster:

```bash
ffmpeg \
  -ss 00:00:01 \
  -i docs/assets/tiger-style-demo.mp4 \
  -frames:v 1 \
  docs/assets/tiger-style-demo-poster.webp
```

---

## 41. Sources

Primary conceptual source:

- TigerBeetle, **Tiger Style**  
  <https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md>

Lua language reference:

- Lua Reference Manuals  
  <https://www.lua.org/manual/>

Neovim API reference:

- Neovim Documentation  
  <https://neovim.io/doc/>

---

# Compact Tiger Style Lua Card

<details>
<summary><strong>Open the condensed rules</strong></summary>

### Safety

- Assert internal invariants.
- Validate external input.
- Bound loops, retries, queues, caches, and files.
- Keep resource ownership explicit.
- Centralize mutation.
- Reject stale asynchronous results.
- Never interpolate untrusted input into shell commands.
- Treat dynamic code loading and FFI as privileged.

### Performance

- Design resource use before optimizing.
- Batch expensive work.
- Keep hot loops simple.
- Avoid unnecessary allocation in measured hot paths.
- Prefer deterministic, predictable algorithms.
- Measure the dominant resource.

### Developer Experience

- Use consistent names.
- Use 4-space indentation.
- Keep lines at or below 100 columns.
- Keep ordinary functions near or below 70 lines.
- Use LuaCATS annotations where useful.
- Keep modules top-down and explicit.
- Make comments explain why.
- Keep documentation readable without CSS or JavaScript.

</details>

---

<div class="tiger-card">

## Final Rule

A Tiger Style Lua codebase should make correctness visible.

The reader should be able to identify the program's limits, invariants, state
transitions, resource owners, failure behavior, and privileged operations
without reconstructing them from hidden conventions.

</div>
