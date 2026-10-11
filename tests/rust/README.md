# tests/rust/

Rust FFI and tooling tests.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `rust/rust-ffi.lua` — Rust FFI self-test — proves the Rust bridge loads.

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
rust/rust-ffi.lua
  └──▶ lua/utils/table, lua/utils/uuid, lua/websocket_ffi
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
nvim --headless -u NONE -i NONE -l tests/rust/rust-ffi.lua
```

</details>
