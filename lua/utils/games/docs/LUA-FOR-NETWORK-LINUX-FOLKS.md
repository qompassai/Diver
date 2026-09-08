# Lua for people who already know networking and Linux

This is not a general Lua tutorial. It assumes you can already read a
`traceroute`, explain why `NAT` breaks inbound connections, and debug
a flaky fiber link with an OTDR. It maps Lua's core ideas onto things
you already know cold, and points at real code in this `games/`
scaffold so every concept has a working example, not just a toy
snippet.

Every section ends with "See it in the scaffold" pointing at an
actual file/function in this plugin. Read the code alongside this
doc -- the doc explains the *why*, the code is the proof it works.

## 1. Tables are hash maps (and arrays, and structs, all at once)

Lua has exactly one composite data structure: the table. There is no
separate "array type", "dict type", "struct type", or "object type" --
they're all the same table, used differently.

- Used with integer keys `1, 2, 3, ...` → it behaves like an array
  (Lua calls this the table's "array part" internally, similar to how
  a `switch` on a small dense integer range compiles to a jump table
  instead of a hash lookup).
- Used with string keys → it behaves like a hash map, exactly like a
  Python `dict` or a JSON object. Internally it's a real hash table:
  O(1) average lookup, same complexity story as `/etc/hosts` vs. DNS
  (a flat lookup table vs. a hashed/indexed one) -- Lua just makes
  that decision for you per-table, transparently.
- Mixed usage is legal and common: `{ 'a', 'b', name = 'eth0' }` has
  both an array part (`[1]='a', [2]='b'`) and a hash part
  (`name='eth0'`) in the same table.

**Why this matters for reading this codebase:** an "options table"
like `{ cwd = root, text = true }` (passed to `vim.system` throughout
`shared/output.lua` and `shared/async_util.lua`) is doing exactly what
a keyword-argument dict does in Python, or what a struct literal does
in C -- it's just a hash-keyed table. A "list of actions" like the one
`get_actions()` returns in every `<engine>/actions.lua` is an
array-keyed table of struct-like tables:
`{ { id = 'build_project', ... }, { id = 'run_tests', ... } }`.

See it in the scaffold: `unity/actions.lua`'s `get_actions()` --
each `{ id = ..., label = ..., group = ..., run = ... }` entry is a
hash-keyed table (a "record"); the outer `{ ... }` wrapping all of
them is an array-keyed table (a "list of records").

## 2. `nil` vs `false` -- two different "no"

Lua distinguishes "this key was never set / this variable was never
assigned" (`nil`) from "this is a boolean, and it's false" (`false`).
This is the same distinction as an unset environment variable versus
one explicitly set to the empty string, or a `NULL` column versus a
`0`/`false` column in SQL -- absence is not the same as a negative
value.

Both `nil` and `false` are "falsy" in an `if` condition (everything
else, including `0` and `""`, is truthy -- unlike C, Python, or
JavaScript, where `0` and `""` are falsy). This trips up people
coming from those languages constantly. `if count then` is true when
`count == 0`, because `0` is truthy in Lua.

**Why this matters:** functions in this codebase that can legitimately
"find nothing" return `nil`, not `false` and not an error -- exactly
like a DNS lookup that returns `NXDOMAIN` isn't an error condition the
way a timeout is. Callers check `if not root then return end`, which
catches both `nil` and `false`, but the functions themselves are
careful to return `nil` for "not found" and reserve `error()`/`assert()`
for "something is actually broken" (see Section 4).

See it in the scaffold: `unreal/util.lua`'s `find_engine_root()`
returns `nil` when no engine root is configured or discoverable (a
normal, expected outcome -- like `dig` returning `NXDOMAIN`) -- as
opposed to `require_engine_root()`, which calls that function and,
if it got `nil`, treats absence as a user-facing error and notifies
loudly instead of silently continuing with a broken root path.

## 3. 1-indexing (and why it's not actually about "off by one")

Lua arrays start at index `1`, not `0`. This is a common source of
bugs when porting logic from C/Python/JS. There's no deep reason to
relitigate here -- just remember it, the way you remember that VLANs
start at 1 (0 and 4095 are reserved) or that port 0 is special on a
NIC. `#some_table` gives you the length of the array part (the
highest contiguous integer index starting from 1) -- it is undefined
behavior if the table has "holes" (e.g. keys 1, 2, 4 but not 3), so
this codebase always builds arrays by appending
(`out[#out + 1] = value`) rather than assigning to arbitrary indices,
which guarantees no holes ever exist.

See it in the scaffold: nearly every action that builds up a result
list -- e.g. `shared/godot_engine.lua`'s `scan_export_relevant_files`
appending to `out_files`, or `unity/actions.lua`'s `build_target_matrix`
appending to `per_target_results` -- uses the `t[#t + 1] = x` append
idiom for exactly this reason.

## 4. `pcall`/`error`/`assert` are exit codes and `try`/`catch`, fused

Lua has no exceptions in the C++/Python sense, and no multi-value
return-code convention like Go's `(result, err)` either. Instead:

- `error(message)` immediately unwinds the current call stack --
  think of it as a `panic()`, or as a shell script hitting
  `set -e` on a failing command and immediately exiting the script.
- `pcall(fn, ...)` calls `fn` and catches any `error()` raised inside
  it, returning `true, result...` on success or `false, error_message`
  on failure -- this is the moment you get an "exit code" back instead
  of the failure tearing down everything above you. It's the direct
  analogue of wrapping a risky command in a shell function and
  checking `$?` afterward, instead of letting `set -e` kill your whole
  script.
- `assert(condition, message)` is `if not condition then error(message)
  end` in one call -- a precondition check, exactly like a Tiger Style
  assertion or a network daemon validating a config file before it
  will `bind()` a socket. This codebase uses `assert()` heavily and
  deliberately (see the "Tiger Style" section of the main README) for
  preconditions that should NEVER be false in correct usage -- if one
  fires, that's a bug in this plugin, not a normal "file not found"
  situation (those use `notify(..., levels.ERROR); return`, not
  `assert`, because they're expected, recoverable user-facing
  conditions, not programmer errors).

**Rule of thumb used throughout this codebase:** `assert()` for "this
should be structurally impossible, and if it happens something is
deeply wrong" (a fixed bound violated, a required module missing);
`notify(..., ERROR); return` for "this is a normal, expected failure
a user will hit" (no engine installed, no project found, a build
that failed). Same distinction as a kernel `BUG_ON()` versus an
application logging "connection refused" and retrying.

See it in the scaffold: `shared/async_util.lua`'s `wrapped_system()`
`assert()`s that `vim.async` exists before ever calling it (a
structural precondition -- Neovim 0.13+ or nothing) versus
`unity/util.lua`'s root-finding helpers, which `notify()` and return
`nil` when a project simply isn't found (an expected, recoverable
outcome, not a bug).

## 5. `vim.system` is `fork()`+`exec()` with the pipes pre-wired

`vim.system(cmd, opts, on_exit)` starts `cmd` (an argv list, exactly
like the array you'd pass to `execve(2)` -- never a shell string, so
there is no shell-quoting/injection risk to reason about) as a child
process. `opts.cwd` is the working directory the child is `fork()`ed
into; `opts.env` behaves like `execve`'s environment array;
`opts.stdout`/`opts.stderr` are callbacks invoked with each chunk of
output, i.e., you're reading the child's stdout/stderr pipes
asynchronously, the same shape as a non-blocking `read(2)` loop on a
socket. `on_exit` fires once, with the exit code -- your `waitpid(2)`
equivalent.

Because it's callback-based, chaining several `vim.system` calls in
sequence ("run A, and when it succeeds run B") means nesting callback
inside callback -- the Lua version of chained `ssh host1 "cmd && ssh
host2 'cmd && ...'"`: it works, but every added step adds another
level of indentation.

See it in the scaffold: `shared/output.lua`'s `run_with_progress()`
is the plain callback-based wrapper (one command, one `on_exit`) used
by simple one-shot actions like `unity/actions.lua`'s `build_project()`.

## 6. Coroutines are cooperative scheduling -- and `vim.async` (0.13) is epoll for Lua

A Lua coroutine is a resumable function: it can `yield` control back
to whoever resumed it, and later be `resume`d again picking up right
where it left off. Nothing preempts it -- it only ever yields when it
explicitly chooses to. This is precisely cooperative multitasking, the
same model as a single-threaded `select(2)`/`epoll(2)` event loop
where each "task" only gives up the CPU at an explicit blocking call,
never in the middle of a computation. There is no thread, no
preemption, no data race to reason about between two coroutines that
haven't yielded to each other -- the same reason a single-threaded
`epoll` server doesn't need mutexes around its per-connection state.

Neovim 0.13's `vim.async` module (see `:h lua-async`) is a structured
concurrency layer built on top of coroutines. A `vim.async.Task` is
like a process group leader in job control: it can own child tasks
(started inside it via `vim.async.run`), and closing/cancelling the
parent is expected to bring down its children too -- "structured
concurrency" is just "no orphaned background jobs", the same property
`setsid`/process groups give you for shell jobs.

- `vim.async.run(fn)` starts `fn` as a task -- like backgrounding a
  shell job with `&`.
- `vim.async.await(awaitable)` (only callable from inside a task)
  suspends the current task until `awaitable` resolves, and returns
  its result directly instead of via a callback -- like `wait` on a
  specific backgrounded job.
- `vim.async.pawait(awaitable)` is `await`, but pcall-wrapped: it
  returns `(ok, result_or_err)` instead of raising -- combine the
  mental models of Section 4's `pcall` and the `await` above.
- `vim.async.wrap(argc, callback_fn)` adapts an existing
  callback-taking function (like `vim.system`) into one that returns
  an awaitable when called from inside a task -- this is the fix for
  the "chained `ssh` calls" indentation problem from Section 5: each
  ordered step becomes one `await`ed line instead of one more nested
  callback.
- `vim.async.iter(tasks)` lets you consume several child tasks in
  COMPLETION order (fastest-first) -- the direct analogue of reading
  responses off an `epoll_wait()` loop as they arrive, instead of
  blocking on each socket in a fixed order.

**When this codebase reaches for `vim.async` vs. a plain callback:**
plain `vim.system`/`run_with_progress` callbacks are used for simple
"fire one command, react to its single result" actions. `vim.async`
is used specifically where there's a genuinely ORDERED multi-step
sequence (do A, then B, only if A succeeded) or genuinely CONCURRENT
independent probes (query 5 engines' versions at once) -- the same
line network engineers already draw between "just run this one
command" and "orchestrate a sequence/fan-out of commands".

See it in the scaffold:
- Ordered sequence: `unreal/actions.lua`'s `bootstrap_engine_checkout()`
  awaits `Setup.sh` to fully finish before even checking that
  `GenerateProjectFiles.sh` exists, let alone running it -- exactly
  `./Setup.sh && ./GenerateProjectFiles.sh`, expressed as two `await`s
  instead of a shell `&&` or a nested callback.
- Ordered sequence (same pattern, different engine): `unity/actions.lua`'s
  `build_target_matrix()` awaits each per-target batchmode build in
  turn (documented there as sequential ON PURPOSE -- concurrent
  writes to the same Unity project directory corrupt its asset
  database, the same way two concurrent `dpkg` invocations fighting
  over `/var/lib/dpkg/lock` corrupt package state).
- Concurrent fan-out: `shared/async_util.lua`'s `run_concurrent()` plus
  `health.lua`'s `collect_rows()`, which probes all five engines
  (Aseprite, Godot, Redot, Unity, Unreal) as sibling child tasks and
  collects results as they complete -- the `:GamesDoctor` health
  check this powers is genuinely "fire N independent probes, don't
  make each one wait for the last one to finish".

## 7. `require()` is sourcing a file, with a cache

`require('utils.games.unity.actions')` maps the dotted path onto a
file path (`lua/utils/games/unity/actions.lua`, found via
`package.path`, conceptually your `$PATH` for Lua modules), runs it
ONCE, and caches whatever it `return`s in `package.loaded`. Every
subsequent `require()` of the same module returns the SAME cached
table -- it does not re-run the file. This is precisely `source
script.sh` (runs in the current context, side effects persist) rather
than `./script.sh` (a fresh subprocess each time) -- and the caching
means two different files that both `require('utils.games.shared.util')`
get the exact same table instance, the same way two processes that
both `dlopen()` the same shared library get the same in-memory code,
not two independent copies.

**Why this matters:** module state set by one file (e.g. the `window`
local variable inside `shared/output.lua`'s `M.new()` closure) is
shared by every caller that received that same module instance --
which is exactly why each engine calls `output_factory.new(filetype)`
to get its OWN independent output-window state instead of all five
engines sharing one global output window and stepping on each other's
scrollback.

See it in the scaffold: every `<engine>/actions.lua` file's top-of-file
`require()` block, and `shared/output.lua`'s `M.new(filetype)` factory
itself (Section 8 explains the factory pattern in depth).

## 8. Closures as the factory pattern (no `class`, no problem)

Lua has no `class` keyword. Object-like behavior with private state is
built from two ingredients you already understand from shell/network
tooling:

- A closure: a function that "remembers" the local variables in scope
  where it was defined, even after that outer function returns. This
  is the same idea as a per-connection state machine capturing its
  socket file descriptor in its enclosing scope -- the state travels
  with the function, invisible to outside callers, exactly like
  private instance state in an object.
- A factory function that creates and returns a table of such
  closures, all sharing the same private locals. Calling the factory
  twice gives you two independent instances with independent private
  state -- the same relationship two independently `listen()`ing
  sockets on different ports have to each other: same code, disjoint
  state.

**Why this matters:** this is EXACTLY how "one output window per
engine, with no shared global state" is implemented in this codebase,
without any class system.

See it in the scaffold: `shared/output.lua`'s `M.new(filetype)` --
call it, and `window` (a local variable) is captured by every closure
returned inside `self` (`create_window`, `close_window`,
`run_with_progress`, etc.). `unity/actions.lua` and `unreal/actions.lua`
each call `output_factory.new(config.output_filetype)` once at the top
of the file, giving each engine its own private `window` variable that
the other engine's functions can never see or accidentally clobber --
the moral equivalent of each engine getting its own file descriptor
table instead of sharing one.

The same pattern, one level fancier, powers Godot and Redot sharing
ALL of their logic: `shared/godot_engine.lua`'s `M.new(opts)` is a
factory that takes engine-specific config (binary names, keymap
prefix) and returns a full `actions`/`commands` module -- Godot's and
Redot's `init.lua` each call it with their own `opts`, producing two
independent engine modules from one shared implementation, the same
way you'd write one `dhcpd.conf`-parsing function and call it once
per interface rather than duplicating the parser per-NIC.

## 9. Multiple return values are not a tuple -- they're positional, not boxed

`local ok, result = pcall(fn)` looks like Python's tuple unpacking, but
Lua doesn't create an intermediate tuple object at all -- the callee
just leaves multiple values on the stack, and the caller decides how
many to keep. Call the same function in a context that only wants one
value (e.g. as a table-constructor entry that isn't the last one, or
as an argument that isn't the last one) and every value after the
first is silently discarded. This is closer to how a shell function
can `return` one exit code but ALSO leave things on stdout for the
caller to optionally capture with `$(...)` -- what the caller actually
receives depends on how it calls, not just what the callee provides.

**Why this matters for reading this codebase:** `async_util.run_bounded`
consistently returns exactly `(ok, result_or_err)` -- two values,
always, by convention (Tiger Style: consistent, explicit contracts) --
not because Lua enforces that shape, but because this codebase chose
to and documents it, the same way a well-behaved daemon always uses a
consistent, documented meaning for its exit codes.

See it in the scaffold: every call site of `async_util.run_bounded`
(e.g. `unreal/actions.lua`'s `bootstrap_engine_checkout()`,
`unity/actions.lua`'s `build_target_matrix()`) destructures exactly
`local ok, result = async_util.run_bounded(...)`, matching that
two-value contract.

## Where to go from here

- `:help lua-guide` -- Neovim's own Lua primer, written for Vimscript
  users rather than networking folks, but a solid second pass once
  the analogies above have given you a foothold.
- `:help lua-async` -- the full `vim.async` reference for Section 6.
- The main [`games/README.md`](../README.md) -- lists every engine
  action this scaffold provides, and which Neovim 0.13 features back
  which action.
- [TigerBeetle's TIGER_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) --
  the assertion-heavy, fixed-bounds coding discipline this whole
  `games/` scaffold follows; Section 4 above is that philosophy
  applied to Lua's `assert`/`error`/`pcall` specifically.
</content>
