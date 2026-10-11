# tests/bidi/

WebDriver BiDi protocol implementation.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `bidi/bidi/bidi_http.lua` — http.lua contract tests. The pure parts (validation, request
- `bidi/bidi/bidi_session.lua` — BiDi session lifecycle + pure-helper tests. Runs under plain Lua 5.4:
- `bidi/bidi/bidi_wire.lua` — BiDi wire.lua framing tests. Pure logic; runs under plain Lua 5.4.
- `bidi/bidi/harness.lua` — Purpose: shared harness for the BiDi unit tests. Runs under plain

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
bidi/bidi/bidi_http.lua
  └──▶ lua/dev/browser/http
bidi/bidi/bidi_session.lua
  └──▶ lua/ai/websocket/client, lua/dev/browser/bidi, lua/dev/browser/bidi/browsing_context, lua/dev/browser/bidi/config (+6 more)
bidi/bidi/bidi_wire.lua
  └──▶ lua/dev/browser/bidi/wire
bidi/bidi/harness.lua
  └──▶ lua/bit
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
nvim --headless -u NONE -i NONE -l tests/bidi/bidi/bidi_http.lua
nvim --headless -u NONE -i NONE -l tests/bidi/bidi/bidi_session.lua
nvim --headless -u NONE -i NONE -l tests/bidi/bidi/bidi_wire.lua
nvim --headless -u NONE -i NONE -l tests/bidi/bidi/harness.lua
```

</details>
