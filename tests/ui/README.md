# tests/ui/

UI: facade, icons, calendar.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `ui/calendar.lua` — tests/ui/calendar.lua
- `ui/ui_facade.lua` — tests/ui/ui_facade.lua
- `ui/ui_icons.lua` — tests/ui/ui_icons.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
ui/calendar.lua
  └──▶ lua/calendar
ui/ui_facade.lua
  └──▶ lua/config/ui, lua/config/ui/colors, lua/config/ui/float
ui/ui_icons.lua
  └──▶ lua/config/ui/icons
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:CalUpdateCheck`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/ui/calendar.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/ui/ui_facade.lua" -c "qall!"
nvim --headless -u init.lua -c "luafile tests/ui/ui_icons.lua" -c "qall!"
```

</details>
