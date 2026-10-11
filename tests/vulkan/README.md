# tests/vulkan/

Vulkan SDK, toolchain, RenderDoc.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `vulkan/vulkan_compile.lua` — Tests for dev.vulkan.compile -- finding parsing, tool mapping, diagnostics.
- `vulkan/vulkan_prompts.lua` — Tests for dev.vulkan.prompts -- Vulkan-aware Rose prompt templates.
- `vulkan/vulkan_renderdoc.lua` — Tests for dap/renderdoc.lua Vulkan additions (:VulkanCapture) plus the
- `vulkan/vulkan_sdk.lua` — Tests for dev.vulkan.sdk -- SDK detection, vulkaninfo parsing, layers.
- `vulkan/vulkan_toolchain.lua` — Tests for dev.vulkan.toolchain -- compiler probing and argv building.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
vulkan/vulkan_compile.lua
  └──▶ lua/dev/vulkan/compile
vulkan/vulkan_prompts.lua
  └──▶ lua/dev/vulkan/prompts
vulkan/vulkan_renderdoc.lua
  └──▶ lua/dap/renderdoc
vulkan/vulkan_sdk.lua
  └──▶ lua/dev/vulkan/sdk
vulkan/vulkan_toolchain.lua
  └──▶ lua/dev/vulkan/toolchain
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:Vulkan`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/vulkan/vulkan_compile.lua
nvim --headless -u NONE -i NONE -l tests/vulkan/vulkan_prompts.lua
nvim --headless -u NONE -i NONE -l tests/vulkan/vulkan_renderdoc.lua
nvim --headless -u NONE -i NONE -l tests/vulkan/vulkan_sdk.lua
nvim --headless -u NONE -i NONE -l tests/vulkan/vulkan_toolchain.lua
```

</details>
