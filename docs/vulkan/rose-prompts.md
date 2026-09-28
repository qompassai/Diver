# Vulkan-aware Rose prompts

## Why templates at all

Rose (diver's in-editor AI, `lua/ai/rose/`) is a generalist. It can read
code, but it doesn't start with the Vulkan mental model: validation
layers, VUIDs, subpass dependencies, descriptor layouts. These templates
teach it the context first, so answers start from the right place.

## How it was done

`lua/dev/vulkan/prompts.lua` is **pure Lua** — no `vim.*` calls. Three
templates, each a builder function over a small context table:

| Template | Command | Use |
|---|---|---|
| `shader_review` | `:VulkanRoseReview` | Review the current buffer: UB, descriptor/binding mismatches, push-constant alignment, vendor portability |
| `validation_error` | `:VulkanRoseExplain` | Explain a validation-layer error in plain language + smallest fix. Carries a "do not invent VUID numbers" instruction |
| `pipeline_debug` | `:VulkanRosePipeline` | Ranked suspect list for a misbehaving pipeline (attachments → subpass deps → descriptors → dynamic state → vertex input → sync) |

### Wiring (diver side only)

`lua/dev/vulkan/init.lua` registers the three `:VulkanRose*` commands,
which build the prompt and hand it to `require('ai.rose').ask()`.
rose.nvim itself is a **separate repo** (`~/workspace/repos/rose.nvim`)
and was not touched — diver's conventions put the integration here,
reaching Rose through its public `ask()` entry point.

### Safety

User content (shader source, error text) is **concatenated**, never
passed through `string.format` — a shader full of `%` can't break the
template. Contexts over 32 KB are truncated with a marker rather than
silently dropped or blowing up the chat context window.

## Try it

```
:VulkanRoseReview    " reviews the current shader buffer
:VulkanRoseExplain   " prompts for a validation error, explains it
:VulkanRosePipeline  " prompts for a setup description, debugs it
```

## What was learned

- The most valuable line in the validation template is the honesty
  instruction: models happily invent VUID numbers. Telling it to say
  "I don't know the exact VUID" instead produces better answers.
- Keeping the module pure made it the easiest of the five to test —
  `tests/lua/vulkan_prompts.lua` needs no vim stub at all.
