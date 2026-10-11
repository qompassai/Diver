# tests/proto/

Wire protocols (websocket).

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `proto/websocket.lua` — WebSocket self-test — proves the websocket helpers work.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
proto/websocket.lua
  └──▶ lua/websocket, lua/websocket/client, lua/websocket/server
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
nvim --headless -u NONE -i NONE -l tests/proto/websocket.lua
```

</details>
