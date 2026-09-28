# RenderDoc capture: `:VulkanCapture`

## What RenderDoc does

RenderDoc takes a snapshot of what your GPU drew in one frame — every
draw call, texture, buffer, and shader — and lets you inspect it in a
GUI. For Vulkan work it's the fastest way to answer "why is my screen
black": capture one frame, walk the event browser, and see exactly
which draw call went wrong.

## How it was done

`lua/dap/renderdoc.lua` already wrapped `renderdoccmd` (capture, list,
open) as argv-built subprocess calls. This workstream added one
Vulkan-specific entry point:

```
:VulkanCapture <executable> [args ...]
```

It launches the target under `renderdoccmd capture` with
`--opt-api-validation` enabled, so the capture carries the
validation-layer messages emitted during the frame — the exact errors
you then paste into `:VulkanRoseExplain`. `<leader>dGv` does the same
from a prompt.

### Flags, verified not invented

Every flag in the argv builder was re-verified against
`renderdoccmd capture --help` (v1.46) on primo on 2026-09-28:

```
usage: renderdoccmd capture [options ...] <executable> [program arguments]
  -d, --working-dir        --capture-file (-c)   -w, --wait-for-exit
  --opt-disallow-vsync  --opt-disallow-fullscreen
  --opt-api-validation  --opt-api-validation-unmute
  --opt-capture-callstacks  --opt-capture-callstacks-only-actions
  --opt-delay-for-debugger  --opt-verify-buffer-access
  --opt-hook-children  --opt-ref-all-resources
  --opt-capture-all-cmd-lists  --opt-soft-memory-limit
```

The module's builder matches this list exactly; program arguments are
appended verbatim after the executable — no shell string is ever built.

## Typical workflow

```
:VulkanCapture ./build/myapp --scene sponza
" ... interact, trigger the bad frame, quit the app ...
:RenderdocCaptures     " pick the newest .rdc, opens in qrenderdoc
```

Captures are listed newest-first with deterministic tie-breaking, so
repeated listings agree.

## Frame-capture helpers in the module

- `M.capture(opts)` — validated argv, detached spawn, never blocks the editor.
- `M.list_captures(dir)` — `*.rdc` scan, newest first.
- `M.open_capture(path)` / `M.open_ui()` — open in qrenderdoc.
- `M.is_available()` / `M.ui_available()` — honest presence checks.
- `:RenderdocStatus` — one-line availability report.

## What was learned

- `renderdoccmd capture` has **no** `--vulkan-only`-style flag; API
  selection happens in the app itself. The Vulkan-specific part of
  `:VulkanCapture` is enabling `--opt-api-validation` by default —
  for D3D you'd want different defaults, hence a separate command
  rather than a flag on the generic one.
- Validation layers must be active *in the app* for the recorded API
  events to be useful; the capture flag only records them.
