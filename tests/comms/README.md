# tests/comms/

Email clients and communications.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `comms/email_clients.lua` — tests/comms/email_clients.lua

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
comms/email_clients.lua
  └──▶ lua/email, lua/email/clients, lua/email/clients/aerc, lua/email/clients/neomutt
```

</details>

<details>
<summary>Commands / keymaps / functions</summary>

Commands covered:

- `:Neomutt`
- `:NeomuttCompose`

</details>

<details>
<summary>How to run</summary>

From the config root (`~/.config/nvim`):

```sh
nvim --headless -u init.lua -c "luafile tests/comms/email_clients.lua" -c "qall!"
```

</details>
