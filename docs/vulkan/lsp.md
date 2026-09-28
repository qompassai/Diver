# Shader LSP: what was verified before wiring anything

## The rule

No LSP config gets wired unless the server is verified upstream first:
it exists, it speaks the Language Server Protocol, and it launches over
stdio the way Neovim expects. An unverifiable server gets a loud gap
note, not a config.

## glsl_analyzer: verified, already wired

- Upstream: https://github.com/nolanderc/glsl_analyzer — a real LSP
  server for GLSL, speaking LSP over stdio.
- Diver config: `lsp/glslana_ls.lua` (filetypes `comp glsl vert frag
  geom tesc tese`, code actions advertised). Nothing new was needed;
  this workstream verified the binary exists on primo
  (`/usr/bin/glsl_analyzer`) and added `lua/dev/vulkan/lsp.lua` to
  report its presence/version via `:VulkanLsp`.

## clangd for C++ host code: verified, already wired

- Diver config: `lsp/clangd_ls.lua` already exists; the formatter side
  has `lua/formatters/clang_format.lua` in the 138-adapter catalog.
- Verified on primo: `/usr/bin/clangd` present. `:VulkanLsp` reports it
  alongside glsl_analyzer.

The Vulkan host-code workflow this enables: clangd for navigation and
diagnostics in the C++ that creates the instance/device/pipeline, plus
validation layers at runtime (`VK_LAYER_KHRONOS_validation`, see
[sdk.md](sdk.md)), plus shader compile-on-save for the GLSL side.

## The honest gap: Slang has no wired LSP

`slangd` ships inside the Slang release and speaks LSP, but it has **not**
been evaluated against diver's strict LuaLS-style config profile, so it
is deliberately not wired. HLSL gets the `dxc` native linter
(`lua/linters/dxc.lua`) instead of an LSP. `lsp.lua`'s report and
`:VulkanLsp` state this gap out loud rather than hiding it.

## Try it

```
:VulkanLsp   " glsl_analyzer + clangd presence and versions
```

## What was learned

- Checking first saved work: both servers were already wired, so the
  contribution here is verification + a status surface, not another
  config file.
- `glsl_analyzer --version` behavior is uncertain across builds, so the
  prober treats version as best-effort (`nil` when the flag fails) while
  `found` stays authoritative. A version probe that hard-fails would
  turn "installed" into "error" — worse than honest ignorance.
