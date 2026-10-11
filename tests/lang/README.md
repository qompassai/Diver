# tests/lang/

Language configs: coverage, buffer-local commands.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `lang/buffer_local_commands.lua` — Qompass AI Diver buffer-local command tests
- `lang/lang_coverage_adversarial.lua` — tests/lang/lang_coverage_adversarial.lua
- `lang/lang_coverage_validation.lua` — tests/lang/lang_coverage_validation.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
lang/buffer_local_commands.lua
  └──▶ lua/config/lang/rust, lua/diagram
lang/lang_coverage_adversarial.lua
  └──▶ lua/config/lang/coverage_gen
lang/lang_coverage_validation.lua
  └──▶ lua/bsp/servers, lua/config/lang, lua/config/lang/coverage, lua/formatters (+3 more)
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:DiagramRender`
- `:GoBuild`
- `:GoTest`
- `:LuaModernize`
- `:LuaRangeAction`
- `:PhpCodeAction`
- `:PhpStan`
- `:PhpTest`
- `:Pint`
- `:PyHostPing`
- `:RustCheck`
- `:RustClippy`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/lang/buffer_local_commands.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/lang/lang_coverage_adversarial.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/lang/lang_coverage_validation.lua" -c "qall!"
```

</details>
