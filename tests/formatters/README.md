# tests/formatters/

Formatter pipeline stages.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `formatters/format_stages_adversarial.lua` — tests/formatters/format_stages_adversarial.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
formatters/format_stages_adversarial.lua
  └──▶ lua/formatters
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

(no commands or keymaps asserted in these tests)

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/formatters/format_stages_adversarial.lua" -c "qall!"
```

</details>
