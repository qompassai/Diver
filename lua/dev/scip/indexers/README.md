# Native SCIP runner for Neovim 0.13+

Copy the contents of `lua/scip/` into your Neovim configuration's `lua/scip/`
directory. Load the runner from your main configuration:

```lua
require('scip').setup({
    timeout_ms = 600000,
    notify = true,
})
```

The downloaded standalone `init.lua` belongs at `lua/scip/init.lua`, not at the
root of your Neovim configuration. `clang`, `java`, and `php` also need the
included `lua/scip/utils.lua`, or an existing compatible helper.

| Command | Action |
| --- | --- |
| `:ScipIndex` | Choose the first enabled indexer matching the buffer filetype. |
| `:ScipIndex python` | Explicitly select a named enabled indexer. |
| `:ScipCancel` | Send SIGKILL to the owned process and wait for its exit callback. |
| `:ScipStatus` | Show the active or most recent report, including captured output. |

For an explicit root, including a project without a recognized marker:

```lua
local ok, err = require('scip').run({
    indexer = 'go',
    root = '/absolute/path/to/project',
})
if not ok then
    vim.notify(err, vim.log.levels.ERROR)
end
```

`run()` returns `true` after spawning, or `nil, error` on immediate failure.
Completion is asynchronous; `status()` returns an independent report snapshot.
The module supports the ten attached definitions in fixed order: clang, dart,
dotnet, go, java, latex, lua, nix, php, python. Lua, LaTeX and Nix retain their
supplied `enabled = false` settings. Explicit selection does not override this.

## Behavior and limits

- Uses native `vim.system` with an argv array and an explicit canonical cwd.
- Runs only on explicit request. Repeated `setup()` replaces owned commands and
  the shutdown autocmd. Plain `require()` does not register commands or run tools.
- Requires a saved, named normal file buffer. Indexers read files from disk;
  save other modified project buffers yourself before indexing.
- Checks executable availability without installing anything. Indexer CLI
  arguments are preserved from the supplied definitions. Tool versions and
  language-specific prerequisites still determine whether indexing succeeds.
- Searches up to 128 parent directories, prioritizing language markers at each
  directory and stopping at the first `.git` or `.hg` boundary. Markers are exact
  paths, not globs. Supply an explicit root for unsupported layouts.
- Owns at most one indexing process across all projects, with no pending queue.
- Captures at most 64 KiB combined stdout and stderr. Further output is drained
  and discarded; `truncated` records this. Streams are combined in arrival order.
- Timeout defaults to 10 minutes and is configurable from 1 ms through 1 hour.
- Cancellation and shutdown target the directly owned process, not its process
  tree. Child build processes may survive. Cancellation can leave a partial index.
- Accepts success only after exit code and signal are zero, no stream error was
  reported, and a nonempty `index.scip` has new filesystem metadata. This is a
  freshness check, not protobuf validation. An indexer that preserves all file
  metadata can produce a conservative failure. Tools producing another output
  filename need corresponding definition/runner changes.
- Does not delete or rename existing indexes. Output replacement behavior belongs
  to each external indexer. It does not add unsupported generic output flags.
- Retains one completed report. Stale exit callbacks cannot release a newer job.
- Project tools and build scripts execute with your user privileges. Use this
  runner only for trusted projects; PHP may use `vendor/bin/scip-php`.

## Included repairs

The supplied `dotnet.lua` and `python.lua` had their `local indexer = {`
declarations inside annotation comments, causing syntax errors. These declarations
are restored. In `clang.lua`, the unused `vim.fs` alias is removed and annotations
use `ScipContext` and `ScipIndexer`, matching the runner. Other definitions retain
their supplied behavior. The helper implements `path_exists()` and bounded
compilation database lookup in the root, `build/`, `build/debug/`, or
`build/release/` directories.

## Verification

All twelve Lua files were parsed with LuaJIT 2.1. Mock-host tests covered module
loading, idempotent setup, disabled entries, sparse/NUL arguments, callback and
spawn failures, missing executables, saved-buffer checks, output bounds, duplicate
runs, stale callbacks, cancellation, timeout exit handling, freshness checks,
stream errors, and independent status snapshots. Neovim 0.13 and external SCIP
binaries were unavailable here, so real editor/indexer integration was not run.

Style reference: [Tiger Style for Lua](https://github.com/qompassai/Lua/blob/main/TIGER_STYLE_LUA.md).