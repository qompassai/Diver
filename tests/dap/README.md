# tests/dap/

Debug Adapter Protocol configurations.

<details>
<summary>Table of Contents</summary>

- [Test files](#test-files)
- [Source map](#source-map)
- [Commands / keymaps / functions](#commands--keymaps--functions)
- [How to run](#how-to-run)

</details>

<details>
<summary>Test files</summary>

- `dap/dap_ansible_role_breakpoints.lua` — Tests for dap.ansible role-entry breakpoint seeding.
- `dap/dap_ruby_rdbg.lua` — Tests for the upstream-faithful rdbg rework in lua/dap/ruby.lua, plus

</details>

<details>
<summary>Source map</summary>

What each test exercises:

```
dap/dap_ansible_role_breakpoints.lua
  └──▶ lua/dap/ansible
dap/dap_ruby_rdbg.lua
  └──▶ lua/dap/backend, lua/dap/ruby
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
nvim --headless -u NONE -i NONE -l tests/dap/dap_ansible_role_breakpoints.lua
nvim --headless -u NONE -i NONE -l tests/dap/dap_ruby_rdbg.lua
```

</details>
