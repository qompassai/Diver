# The honest DAP story for RenderDoc and Vulkan

## Short version

**There is no DAP for RenderDoc or Vulkan, and Diver doesn't pretend
there is one.** `lua/dap/renderdoc.lua` lives in `lua/dap/` for one
reason: so graphics developers get the same discoverable command
surface (`:VulkanCapture`, `:RenderdocCaptures`, `<leader>dG*` mappings)
as real DAP adapters. It never speaks the Debug Adapter Protocol.

## What's real

- `renderdoccmd capture` — launches a Vulkan app under capture.
  Verified flags (v1.46, `renderdoccmd capture --help` on primo,
  2026-09-28). This is a real subprocess invocation with real effects.
- `renderdoccmd` capture listing / `qrenderdoc` opening — real.
- `:VulkanCapture` — real; it adds `--opt-api-validation` so captures
  carry validation-layer messages.

## What isn't

- **No DAP wire protocol for RenderDoc.** RenderDoc ships a GUI
  (`qrenderdoc`) and a CLI (`renderdoccmd`). There is no debug-adapter
  executable to attach, no DAP `initialize`/`launch` handshake, no
  breakpoints, no stepping. Anyone telling you otherwise is confused.
- **No Vulkan DAP either.** GPU shader debugging happens through
  vendor tools and RenderDoc's shader debugger, not through DAP.
- **vogl is deliberately not implemented.** Valve's vogl lost its
  maintainer in 2014 and the repo is stale; RenderDoc covers its ground.

## Why the module lives in lua/dap/ anyway

Discoverability. A Vulkan developer reaching for "debug my frame"
should find `:VulkanCapture` next to `:DapContinue`, not hunt through
unrelated namespaces. The module docstring states the non-DAP nature
up front so nobody mistakes command-surface parity for protocol
support.

## If a DAP story ever becomes real

The day RenderDoc (or a Vulkan shader debugger) ships a DAP server,
the honest move is a new adapter module speaking that protocol —
not retrofitting this one. Until then, this document stays as the
record of what was checked and what isn't there.
