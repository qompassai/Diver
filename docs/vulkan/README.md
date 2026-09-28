# Vulkan in Diver

How Diver works with Vulkan: SDK detection, shader compilation,
frame capture, language servers, and AI-assisted shader review.

## Start here

1. **Is my machine ready?** → [sdk.md](sdk.md) — run `:VulkanStatus`.
2. **Compile shaders** → [toolchain.md](toolchain.md) — the four compilers,
   what each is for, and the flags Diver uses.
3. **Compile on save** → [toolchain.md](toolchain.md#compile-on-save) — save a
   `.vert`/`.frag`/`.hlsl`/`.slang` and get SPIR-V + diagnostics.
4. **Capture a frame** → [renderdoc.md](renderdoc.md) — `:VulkanCapture`.
5. **Editor smarts** → [lsp.md](lsp.md) — glsl_analyzer + clangd status.
6. **Ask Rose about shaders** → [rose-prompts.md](rose-prompts.md).
7. **What about DAP?** → [dap-story.md](dap-story.md) — honest answer: there is none.
8. **primo tool installs** → [primo-install.md](primo-install.md) — what was
   installed on 2026-09-28 and how.

## The modules

| Module | Job |
|---|---|
| `lua/dev/vulkan/sdk.lua` | SDK root, vulkaninfo version, layer list, vkconfig |
| `lua/dev/vulkan/toolchain.lua` | Probe glslangValidator/glslc/dxc/slangc; build compile argv |
| `lua/dev/vulkan/compile.lua` | BufWritePost compile to SPIR-V + `vim.diagnostic` |
| `lua/dev/vulkan/lsp.lua` | glsl_analyzer / clangd presence + version report |
| `lua/dev/vulkan/prompts.lua` | Vulkan-aware prompt templates (pure Lua) |
| `lua/dev/vulkan/init.lua` | Wires it all: `:Vulkan*` commands |
| `lua/dap/renderdoc.lua` | `:VulkanCapture` — RenderDoc capture, API validation on |

## Commands

`:VulkanStatus` `:VulkanToolchain` `:VulkanLayers` `:VulkanLsp`
`:VulkanCompile` `:VulkanRoseReview` `:VulkanRoseExplain`
`:VulkanRosePipeline` — plus `:VulkanCapture` from the RenderDoc module.

## Design rules (why it looks like this)

- **Probe, don't assume.** Every status answer comes from a real check.
  A missing tool is reported missing, never guessed.
- **Build argv, don't run.** `toolchain.build_argv` is pure so tests can
  verify every flag without a GPU toolchain installed.
- **Diagnostics go through `vim.diagnostic`.** Same surface as the native
  linters; nothing custom to learn.
- **Rose prompts are data-safe.** User content is concatenated, never
  passed through `string.format`, so a shader full of `%` can't break
  the template.
