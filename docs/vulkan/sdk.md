# SDK detection: how Diver finds your Vulkan setup

## What "SDK detection" means

The Vulkan SDK is the toolbox: headers, the loader, validation layers,
and tools like `vulkaninfo`. On Linux it can live in several places —
the LunarG installer uses `~/VulkanSDK/<version>`, distros put pieces
under `/usr/share/vulkan`, and the `VULKAN_SDK` environment variable
points at it when set. Diver checks them in that priority order.

## How it was done

`lua/dev/vulkan/sdk.lua` implements the detection:

1. **`VULKAN_SDK` first.** If the variable names an existing directory,
   that's the answer. A stale value (points nowhere) is not fatal —
   detection falls through to probing instead of erroring.
2. **Well-known paths.** `/usr/share/vulkan`, `/usr/local/share/vulkan`,
   `/etc/vulkan`, `/opt/vulkan`, `~/.local/share/vulkan`. Short on purpose:
   only paths the LunarG installer and distro packages actually use.
3. **`vulkaninfo --summary`** for the instance version and the layer list.
   The parser reads the `Vulkan Instance Version:` line and the
   `Instance Layers:` section. Section parsing stops at the next
   top-level header, so a future vulkaninfo layout change degrades to
   "no layers found" rather than garbage.
4. **Validation layers.** `VK_LAYER_KHRONOS_validation` in the layer list
   means the safety net is available. `VK_LAYER_PATH` entries are listed
   so you can see where the loader looks for extra layers.
5. **`vkconfig`** presence — the GUI for building layer configurations.

Every answer is a real check: `uv.fs_stat` for directories,
`fn.executable` for binaries, `vim.system` for versions. Missing pieces
are reported as missing.

## Commands run (2026-09-28, primo)

```sh
vulkaninfo --summary | head -40   # Instance Version: 1.4.357, 34 instance layers
which vulkaninfo glslangValidator glslc renderdoccmd vkconfig glsl_analyzer clangd
echo "VULKAN_SDK=[$VULKAN_SDK]"  # empty
echo "VK_LAYER_PATH=[$VK_LAYER_PATH]"  # empty
```

What was learned: primo has a system Vulkan (loader 1.4.357, 34 layers,
vkconfig present) but **no `VULKAN_SDK`** — the distro packages provide
the loader/layers/tools without the SDK env marker. That's why detection
falls back to well-known paths instead of treating `VULKAN_SDK` as
required.

## Try it

```
:VulkanStatus   " SDK root, vulkaninfo, version, layer count, vkconfig
:VulkanLayers   " full instance layer list (* marks the validation layer)
```

## Module reference

`M.sdk_root()` → path or nil + error. `M.instance_version()`,
`M.layers()`, `M.vkconfig_available()`, `M.validation_layer_available(layers)`,
`M.status()` (one report table), `M.format_status(report)` (display lines).
Parsers (`parse_instance_version`, `parse_layers`) are pure and covered
by `tests/lua/vulkan_sdk.lua`.
