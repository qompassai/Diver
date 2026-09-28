# Native SCIP indexer runner for Neovim 0.13+

The `lua/scip/` tree is a native Neovim SCIP integration: it detects the
right SCIP indexer for the current buffer, runs it asynchronously, and
offers health, coverage, and index-inspection commands. Everything runs on
explicit request; requiring the modules registers nothing.

```lua
require('scip').setup({
    timeout = 300000, -- milliseconds; default 5 minutes
    notify = true,
    lint_after_index = true,
})
```

`setup()` deep-merges your options over the built-in defaults and creates
the `:Scip*` commands. `indexer_order`, when supplied, replaces the default
priority list wholesale (insertion order is honored verbatim, never sorted).

## Indexer definitions

Each file in this directory defines one indexer and returns it through the
shared factory, which validates the `ScipIndexer` shape once at require time:

```lua
local factory = require('scip.indexers.factory')

return factory.new('go', {
    args = {},
    command = 'scip-go',
    filetypes = { go = true },
    markers = { '.git', 'go.mod', 'go.work' },
})
```

A definition carries `command` (string or `fun(ctx: ScipContext): string`),
`args` (string array or `fun(ctx: ScipContext): string[]`), a `filetypes`
set, project-root `markers`, and an optional `enabled` flag. All 15
definitions are enabled: only `latex`, `lua`, and `nix` set `enabled`
explicitly (to `true`); none set it to `false`. Their doc comments note that
no verified standard `scip-latex` / `scip-lua` / `scip-nix` executable is
known — the definitions are registration points that degrade gracefully when
the binary is absent.

| Name | Command | Notes |
| --- | --- | --- |
| `apex` | `scip-apex` | Community Apex indexer (`index .`) |
| `clang` | `scip-clang` | Adds `--compdb-path=` from compilation-database lookup |
| `dart` | `dart` | `pub global run scip_dart .` |
| `dotnet` | `scip-dotnet` | `index` |
| `go` | `scip-go` | No extra args |
| `java` | `scip-java` | `index [--build-tool=gradle\|maven\|sbt]` by project layout |
| `latex` | `scip-latex` | `index .` |
| `lua` | `scip-lua` | `index .` |
| `nix` | `scip-nix` | `index .` |
| `php` | `scip-php` | Prefers `vendor/bin/scip-php` when present |
| `python` | `scip-python` | `index .` |
| `ruby` | `scip-ruby` | `.` unless `sorbet/config` exists (then no args) |
| `rust` | `rust-analyzer` | `scip .` |
| `typescript` | `scip-typescript` | Args depend on detected package manager / config |
| `zig` | `scip-zig` | `--pkg` / `--root-pkg` derived from the project |

`command` and `args` may be functions of the indexing context
(`{ name, bufnr, filename, root, index_file }`), which is how `php` finds its
project-local binary and `clang` locates the compilation database.

Custom indexers can be added at runtime; validation failures return
`nil, err` rather than throwing:

```lua
local ok, err = require('scip').register('myindex', {
    command = 'scip-myindex',
    args = { 'index', '.' },
    filetypes = { mylang = true },
    markers = { '.git', 'myindex.config' },
})
```

## Commands

| Command | Action |
| --- | --- |
| `:ScipIndex` | Index with the first enabled indexer matching the buffer (priority order). |
| `:ScipIndex python` | Index with the named indexer (with completion). |
| `:ScipCancel` | Send SIGTERM to the active indexer; state clears immediately. |
| `:ScipStatus` | Show the active indexer, root, and elapsed time, or index-file presence. |
| `:ScipHealth` | `:checkhealth`-style report: CLI, per-indexer readiness, project, state. |
| `:ScipCoverage` | Scratch buffer with per-indexer readiness for the current buffer. |
| `:ScipLint` | Run `scip lint` on the current project's index file. |
| `:ScipPrint` | Open the index as JSON in a scratch buffer. |
| `:ScipSnapshot` | Write a human-readable snapshot under the project root. |
| `:ScipStats` | Show `scip stats` for the current project's index. |

The Lua entry points mirror the commands: `require('scip').index(name, opts)`
with `opts = { bufnr = ..., root = ... }`. An explicit `root` bypasses marker
search. Only one indexing process runs at a time; a second `:ScipIndex` while
one is active is refused with a reminder to `:ScipCancel` first.

## Behavior and limits

- Indexing runs asynchronously through `vim.system` with an argv array and
  the project root as cwd. `index()` returns `nil`; completion is reported
  through notifications.
- Project-root discovery uses `vim.fs.root()` with the indexer's markers,
  searched upward from the buffer. Detection and health checks do **not**
  fall back to the cwd: an indexer with no resolvable root is reported as
  `no project root` instead of being probed against the wrong directory.
  (An explicit `root` override, and `root.resolve()` used by the
  inspect-the-existing-index commands, still fall back to the cwd.)
- The index file defaults to `<root>/index.scip` (`index_file` config;
  absolute values are used as-is).
- Subprocess output is streamed with a 64 KiB budget **per stream**: stdout
  and stderr each retain their first 64 KiB while the rest is drained and
  discarded, so a pathological indexer cannot exhaust memory. Truncation is
  surfaced in the UI (quickfix entries and scratch buffers carry the notice).
- `timeout` is in milliseconds (default 300000). Cancellation sends SIGTERM
  (signal 15) and clears state at once; a cancelled run's late exit callback
  is ignored as stale.
- When `lint_after_index` is enabled (default), a successful run validates
  the index with `scip lint`. Validation captures the run's state generation
  and reports only while that generation still owns the state, so a stale
  lint cannot announce results for a run you already superseded.
- Executable probes are memoized per configuration generation; changing the
  configuration drops the cache.
- Indexer CLIs execute with your user privileges. Index only projects you
  trust.

## Adding an indexer

1. Copy the closest existing definition and adjust `command`, `args`,
   `filetypes`, and `markers`.
2. Return it via `factory.new('<name>', { ... })` — the factory asserts the
   shape at require time with the indexer name in the error.
3. Register the module in `config.lua`'s `default_indexers()` and add the
   name to `indexer_order` where its priority belongs.
4. If the command depends on the project (a `vendor/bin` binary, a build
   tool), resolve it from the `ScipContext` and prefer
   `utils.local_or_bin()` for the local-over-global pattern.

Style reference: [Tiger Style for Lua](https://github.com/qompassai/Lua/blob/main/TIGER_STYLE_LUA.md).
