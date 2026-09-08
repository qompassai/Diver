# Native lint completion API

The native runner in [`lua/linters/init.lua`](../lua/linters/init.lua) exposes
`completion_api_version = 1` for callers that need structured completion instead
of fire-and-forget linting. These additions do not require a plugin or change
existing `require('linters')`, registration, or `setup()` defaults.

## Optional embedding mode

```lua
local diver = '/absolute/path/to/diver'
-- Makes selected definition dependencies available; does not source Diver init.
vim.opt.runtimepath:append(diver)
local runner = assert(loadfile(diver .. '/lua/linters/init.lua'))({
  lazy = true,       -- defer definition modules until requested
  no_updates = true, -- do not initialize the linter updater
})
assert(runner.completion_api_version == 1)
local definition = runner.get_definition('luacheck')
```

The explicit chunk options are optional. Ordinary `require('linters')` retains
its existing loading behavior. Embedding does not call `runner.setup()` or replace
`package.loaded.linters`; hosts should reuse an already loaded user registry where
appropriate. `get_definition(name)` returns the registered definition or lazily
loads that named module; load failures remain available in `runner.load_errors`.

## Per-run completion

`run_linter(name, bufnr, opts)` preserves its boolean first return. A started run
also returns a handle with `cancel(status?)`; cancellation is idempotent and scoped
to that invocation.

Additional optional fields in `opts` (annotated as `LintRunOptions`). Field types are
validated with `vim.validate`, and `timeout` must be positive; a wrong type is a host
programming error and raises immediately rather than completing with `error`:

| Field | Meaning |
| --- | --- |
| `on_complete(result)` | Receives one terminal result for that invocation. |
| `timeout` | Per-run process timeout in milliseconds, overriding the definition. |
| `root` | Supplies the context root/default cwd before definition functions run. |
| `validate_context(context, argv, cwd)` | Must return exactly `true` to permit spawning. Runs after command/cwd resolution. |

```lua
local completed
local started, handle = runner.run_linter('luacheck', vim.api.nvim_get_current_buf(), {
  automatic = false,
  notify = false,
  timeout = 5000,
  on_complete = function(result) completed = result end,
})
if started and not completed then
  local finished = vim.wait(5000, function() return completed ~= nil end, 10)
  if not finished and handle then handle.cancel('timeout') end
end
assert(completed, 'expected a structured terminal result')
```

Immediate rejections complete synchronously. Process results complete on Neovim's
scheduled event loop after parsing and diagnostic publication. Hosts should wait
on this completion predicate, not sleep for an assumed duration or poll diagnostic
counts. `runner.run()` forwards its options to each selected linter; completion is
per linter, not an aggregate callback.

Results include `name`, `bufnr`, `status`, and `verified`; applicable results also
include `reason`, `exit_code`, `signal`, captured `changedtick`, `diagnostics`,
`namespace`, and stdout/stderr capped at 64 KiB (`OUTPUT_BYTES_MAX`) each.

- `ok`: process exited zero, parser returned a diagnostic array, no diagnostics.
- `failed`: diagnostics, rejected exit code, or process termination by signal.
- `unavailable`: missing definition/executable or ineligible/skipped buffer.
- `timeout`: process or caller completion deadline expired.
- `stale`: changed/deleted buffer, cancellation, supersession, or unsaved content
  supplied to a disk-only linter.
- `error`: command/cwd validation, spawn, parser, or publication failure.
- `unverified`: accepted nonzero exit without parsed diagnostics.

`verified` is true only for `ok`; it describes that selected lint run, not overall
program correctness. Empty cached diagnostics are not completion evidence.

## Host responsibilities

Definitions and their argument/cwd/parser functions are trusted executable Lua.
`validate_context` is a host policy hook, not an OS sandbox, and executes after
definition functions. Hosts must enforce workspace containment and execution
trust before invoking the runner. This API neither saves modified buffers nor
overrides a user's global setup.

Coverage is provided by Rose's headless `tests/tooling.lua` and optional
`tests/tooling_live.lua`: completion, unavailable executables, parser errors,
nonzero exits, timeouts, changed buffers, cancellation, and real Ruff fail/fix
results through the native runner.
