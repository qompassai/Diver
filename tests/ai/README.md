# tests/ai/

AI tooling: inference, caching, retrieval, personas, recon.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `ai/ai_cache_retrieval_adversarial.lua` — Adversarial tests for ai.cache.tiered + ai.retrieval.two_stage.
- `ai/ai_cache_tiered.lua` — Self-test for ai.cache.tiered (two-tier context cache).
- `ai/ai_inference_adversarial.lua` — Adversarial inference self-test — tries to break the helpers, locks in the fixes.
- `ai/ai_inference_kv_policy.lua` — KV precision policy self-test — proves the policy table and validator behave.
- `ai/ai_inference_speculative.lua` — Speculative decoding self-test — proves the inference helpers behave.
- `ai/ai_retrieval_two_stage.lua` — Self-test for ai.retrieval.two_stage (coarse-to-fine ranker).
- `ai/huggingface.lua` — tests/ai/huggingface.lua
- `ai/personas.lua` — tests/ai/personas.lua
- `ai/recon.lua` — Recon subsystem self-test: skills loader, annotations, gate,

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
ai/ai_cache_retrieval_adversarial.lua
  └──▶ lua/ai/cache/tiered, lua/ai/mcp/discovery, lua/ai/retrieval/two_stage
ai/ai_cache_tiered.lua
  └──▶ lua/ai/cache/tiered
ai/ai_inference_adversarial.lua
  └──▶ lua/ai/inference/kv_policy, lua/ai/inference/speculative, lua/ai/rose/config
ai/ai_inference_kv_policy.lua
  └──▶ lua/ai/inference/kv_policy, lua/ai/rose/config
ai/ai_inference_speculative.lua
  └──▶ lua/ai/inference/speculative, lua/ai/rose/config
ai/ai_retrieval_two_stage.lua
  └──▶ lua/ai/retrieval/two_stage
ai/huggingface.lua
  └──▶ lua/ai/huggingface, lua/ai/huggingface/api
ai/personas.lua
  └──▶ lua/ai/herd/personas
ai/recon.lua
  └──▶ lua/ai/mcp/skills, lua/ai/mcp/webmcp, lua/ai/recon/gate, lua/ai/recon/parse (+6 more)
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:HfDatasets`
- `:HfModels`
- `:HfPapers`
- `:PersonasUpdateCheck`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u NONE -i NONE -l tests/ai/ai_cache_retrieval_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/ai/ai_cache_tiered.lua
nvim --headless -u NONE -i NONE -l tests/ai/ai_inference_adversarial.lua
nvim --headless -u NONE -i NONE -l tests/ai/ai_inference_kv_policy.lua
nvim --headless -u NONE -i NONE -l tests/ai/ai_inference_speculative.lua
nvim --headless -u NONE -i NONE -l tests/ai/ai_retrieval_two_stage.lua
nvim --headless -u init.lua -c "luafile tests/ai/huggingface.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/ai/personas.lua" -c "qall!"
nvim --headless -u NONE -i NONE -l tests/ai/recon.lua
```

</details>
