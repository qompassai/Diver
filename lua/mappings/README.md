# Diver key mappings

Inventory of twelve Lua files, updated on 2026-09-21. **138 mapping definitions** are documented, including disabled mappings, overlapping definitions, and definitions that the supplied loader does not activate. A definition with multiple modes occupies one row; these are not 138 unique effective shortcuts.

Files are alphabetical. Within each mapping table, keys are sorted case-insensitively by their written notation, then by exact spelling and mode; punctuation appears before letters. Uppercase remains significant: `<leader>ds` and `<leader>dS` are different shortcuts. Tables use the descriptions from the documented files; the behavior column clarifies misleading descriptions. Navigation rows describe the regenerated files; other rows describe the original uploads.

This inventory combines the original ten mapping modules with the regenerated `fzf.lua` and `navmap.lua`. FZF defines **zero mappings**; navmap owns **24 mapping definitions** (29 mode/key pairs). The other modules contribute the original 114 definitions. `mojomap.lua` and `utilmap.lua` are still referenced but not supplied, so their keys and conflicts remain unknown. No SCIP binding appears in these files; SCIP keys below remain proposals.

The navigation code passed Lua 5.4 syntax loading and 23 mocked boundary/lifecycle checks. Neovim, LuaLS, and an interactive FZF/skim session were not available for end-to-end verification. This is not a claim that every mapping in your full configuration has been runtime-tested. The supplied FZF upload was the source of truth; the linked GitHub file could not be retrieved in this environment.

## Installation and mapping ownership

Replace the two Lua files at their existing module paths, and place this README with your mapping documentation:

| File | Destination |
| --- | --- |
| `fzf.lua` | `lua/config/nav/fzf.lua` |
| `navmap.lua` | `lua/mappings/navmap.lua` |
| `README.md` | `lua/mappings/README.md` |

Configure the backend once through your existing navigation setup. Your supplied mapping loader already calls `setup_navmap()`, so no loader change is needed for these two regenerated files.

```lua
local ok, err = require('config.nav.fzf').setup({
    binaries = { 'fzf', 'sk' },
    projects_directory = vim.fn.expand('~/projects'),
    prompt = '❯ ',
})
if not ok then
    vim.notify(err or 'FZF setup failed', vim.log.levels.ERROR)
end
-- Your existing require('mappings').setup() loads mappings.navmap.
-- When testing navmap alone, call require('mappings.navmap').setup() explicitly.
```

`fzf_setup` remains an alias of backend `setup`; `setup_navmap` remains an alias of mapping `setup`. The old backend `keymaps` table and `setup_mappings()` are removed. Remove any external caller of those old members. Backend setup registers commands and lifecycle cleanup, and mapping setup registers global shortcuts without LSP autocmds. Set Leader/LocalLeader before running mapping setup. Restart Neovim once after installing both replacements: the old anonymous LspAttach callbacks cannot be safely identified and removed during a hot reload.

The backend needs `fzf` or `sk` (skim), POSIX `sh`, and the relevant source tool: `fd`/`rg`/`find` for files, `rg` for grep, `git` for Git, and `find` for projects. Flash shortcuts retain the optional `flash` dependency and report an unavailable module when invoked. No FZF Lua plugin is required. Global `s`/`S` deliberately retain your Flash overrides of native editing actions.

| Action | Previous key | Current key | Reason |
| --- | --- | --- | --- |
| Grep project | `<leader>zs` | `<leader>zgg` | Leaves Zoxide split on zs; zg is a group shared by grep and Git. |
| Toggle search highlighting | `<leader>h` | `<leader>z/` | Leaves the existing terminal key alone; avoids making zh both an action and a prefix. |
| Select project directory | Command only | `<leader>zp` | Adds access to the existing projects picker. |
| Cancel FZF work | Function only | `<leader>zx` and `:NativeFzfCancel` | Cancels source collection, pending symbol requests, or the picker. |

All other FZF/search keys and all six existing navmap definitions are retained, now globally available. In a focused picker terminal, Escape/Ctrl+C exits the picker; the Normal-mode zx mapping is for Normal mode, and `:NativeFzfCancel` is also available. `*` now highlights a whole word without moving, while `n`/`N` honor counts. `live_grep()` remains the public compatibility name: it prompts once, runs ripgrep, and then fuzzy-filters the collected matches; it does not rerun ripgrep on every picker keystroke.


## Reading the tables

`<leader>` uses your configured `vim.g.mapleader`; these files do not set it. Comments assume Space, but that is not verified. `<LocalLeader>` uses `vim.g.maplocalleader`, which is also not set here. A chord such as `<C-g>c` means Ctrl+g, release, then c.

| Notation | Meaning |
| --- | --- |
| `c` | Command-line mode |
| `i` | Insert mode |
| `n` | Normal mode |
| `o` | Operator-pending mode |
| `t` | Terminal mode |
| `v` | Visual and Select modes |
| `x` | Visual mode only |
| `<A-…>` | Alt modifier |
| `<C-…>` | Ctrl modifier |
| `Global` | Installed by the module setup, without a buffer restriction |
| `LspAttach` | Buffer-local; installed when a language server attaches |
| `FileType` | Buffer-local; installed for the stated filetype |
| `Attach hook` | Buffer-local; requires external invocation of `lspmap.on_attach(args)` |

## Current mappings — files A–Z

| File | Definitions | Contents |
| --- | --- | --- |
| `aimap.lua` | 14 | AI / Rose |
| `cicdmap.lua` | 14 | Terminals / Zoxide |
| `datamap.lua` | 8 | Math text / Salesforce queries |
| `ddxmap.lua` | 22 | DAP / diagnostics / Markdown / self-checks |
| `disable.lua` | 4 | Disabled commenting keys |
| `fzf.lua` | 0 | Backend, commands, and search helpers; no mappings |
| `genmap.lua` | 20 | Completion / editing / windows / package updates |
| `init.lua` | 0 | Loader; no mappings |
| `langmap.lua` | 13 | Mojo / Python / notebooks |
| `lintmap.lua` | 1 | Diagnostic reset |
| `lspmap.lua` | 18 | LSP / diagnostics / Rust |
| `navmap.lua` | 24 | FZF / Flash / directory browsing / search |

<details>
<summary>aimap.lua — 14 mapping definitions</summary>

Rose commands are buffer-local and installed only after LSP attachment. Their command definitions are outside this upload. In Visual/Select mode the `:` mappings carry the selection range. `<C-g><C-g>` means press Ctrl+g twice, not Ctrl+g followed by plain g.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<C-g><C-g>` | `n` | Rose: generate response | `:RoseChatRespond<CR>` | LspAttach | 41 |
| `<C-g>a` | `v` | Rose Append to selection | `:RoseAppend<CR>` | LspAttach | 112 |
| `<C-g>c` | `n` | [r]ose [c]hat | `:RoseChatNew<CR>` | LspAttach | 17 |
| `<C-g>d` | `n` | Rose: delete current chat | `:RoseChatDelete<CR>` | LspAttach | 59 |
| `<C-g>e` | `n` | Rose Edit local context file | `:RoseContext<CR>` | LspAttach | 95 |
| `<C-g>f` | `n` | Rose Chat Finder | `:RoseChatFinder<CR>` | LspAttach | 33 |
| `<C-g>i` | `n` | Rose Print plugin config | `:RoseInfo<CR>` | LspAttach | 86 |
| `<C-g>m` | `n` | Rose Switch model | `:RoseModel<CR>` | LspAttach | 77 |
| `<C-g>p` | `n` | Rose Select provider | `<cmd>RoseProvider<CR>` | LspAttach | 68 |
| `<C-g>p` | `v` | Rose Prepend to selection | `:RosePrepend<CR>` | LspAttach | 121 |
| `<C-g>r` | `n` | Rose Repeat last action | `:RoseRetry<CR>` | LspAttach | 129 |
| `<C-g>r` | `v` | Rose Rewrite selection | `:RoseRewrite<CR>` | LspAttach | 103 |
| `<C-g>s` | `n` | Rose: stop generation | `:RoseStop<CR>` | LspAttach | 50 |
| `<C-g>t` | `n` | [r] Toggle Popup Chat | `:RoseChatToggle<CR>` | LspAttach | 25 |


</details>

<details>
<summary>cicdmap.lua — 14 mapping definitions</summary>

This file contains terminals and directory navigation, despite its CI/CD name. Every map is restricted to LSP-attached buffers, including its Terminal-mode maps; ordinary terminal buffers therefore usually do not receive them. The two annotated direction strings are invalid ToggleTerm values. `<leader>zl` and `<leader>zt` start `<cmd>` sequences without a terminating `<CR>` and cannot act as editable prompts as written.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<A-h>` | `n, t` | TT: toggle horizontal terminal | Create a new horizontal Terminal, then toggle it; instance is not retained. | LspAttach | 66 |
| `<A-i>` | `n, t` | TT: toggle floating terminal | Create a new floating Terminal, then toggle it; instance is not retained. | LspAttach | 82 |
| `<A-v>` | `n, t` | TT: toggle vertical terminal | Create a new vertical Terminal, then toggle it; instance is not retained. | LspAttach | 47 |
| `<leader>h` | `n` | TT: new horizontal terminal | Create/toggle Terminal with invalid direction `'[h]orizontal toggleterm'`. | LspAttach | 18 |
| `<leader>v` | `n` | TT: new vertical terminal | Create/toggle Terminal with invalid direction `'vertical toggleterm'`. | LspAttach | 32 |
| `<leader>za` | `n` | Zoxide add current directory | `<cmd>:lua require('telescope').extensions.zoxide.add()<CR>` | LspAttach | 164 |
| `<leader>zi` | `n` | Zoxide interactive | `<cmd>:Zi<CR>` | LspAttach | 99 |
| `<leader>zl` | `n` | Zoxide local to window | `<cmd>:Lz ` — incomplete `<cmd>` sequence. | LspAttach | 131 |
| `<leader>zli` | `n` | Zoxide interactive local to window | `<cmd>:Lzi<CR>` | LspAttach | 148 |
| `<leader>zq` | `n` | Zoxide query | `:Z ` — editable query prompt; trailing space retained. | LspAttach | 107 |
| `<leader>zs` | `n` | Zoxide split window | `<cmd>:Telescope zoxide list<CR><C-s>` | LspAttach | 115 |
| `<leader>zt` | `n` | Zoxide local to tab | `<cmd>:Tz ` — incomplete `<cmd>` sequence. | LspAttach | 139 |
| `<leader>zti` | `n` | Zoxide interactive local to tab | `<cmd>:Tzi<CR>` | LspAttach | 156 |
| `<leader>zv` | `n` | Zoxide vertical split | `<cmd>:Telescope zoxide list<CR><C-v>` | LspAttach | 123 |


</details>

<details>
<summary>datamap.lua — 8 mapping definitions</summary>

The loader calls `setup_datamap()` instead of the broader `setup()`, so the six Salesforce definitions below are **not registered through the supplied loader**. They become eligible only if another caller invokes `setup_sf_query_maps()` or `setup()`. Math preview is plain virtual text, not typeset LaTeX. DDX overwrites both math keys under the supplied setup order.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<leader>mp` | `n` | Preview LaTeX (virt text) | `toggle_line_math()` — echo extracted math as virtual text; overwritten by DDX. | LspAttach | 62 |
| `<leader>mt` | `n` | Toggle LaTeX virt text | `toggle_all_math()` — toggle buffer math text; overwritten by DDX. | LspAttach | 71 |
| `<leader>sfl` | `n` | SF: lint query | `<cmd>SfQueryLint<cr>` | FileType: soql/sosl; setup skipped | 132 |
| `<leader>sfR` | `n` | SF: run query (auto) | `<cmd>SfQueryRun<cr>` | FileType: soql/sosl; setup skipped | 140 |
| `<leader>sfr` | `n` | SF: run SOQL | `<cmd>SfSoqlRun<cr>` | FileType: soql; setup skipped | 97 |
| `<leader>sfr` | `n` | SF: run SOSL | `<cmd>SfSoslRun<cr>` | FileType: sosl; setup skipped | 115 |
| `<leader>sft` | `n` | SF: SOQL template | `<cmd>SfSoqlTemplate<cr>` | FileType: soql; setup skipped | 105 |
| `<leader>sft` | `n` | SF: SOSL template | `<cmd>SfSoslTemplate<cr>` | FileType: sosl; setup skipped | 123 |


</details>

<details>
<summary>ddxmap.lua — 22 mapping definitions</summary>

DAP callbacks use `dap`, `dap-python`, and `dapui` plugins. Missing modules are caught with a notification; several missing methods silently do nothing. Markdown commands are attached to every LSP buffer without a Markdown filetype restriction. Global diagnostics settings can change even though the triggering mapping is buffer-local.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<leader>da` | `n` | Select Debug Adapter | Select python/cpp/rust; directly call a function-valued `dap.adapters[choice]` without its expected arguments; not a configuration launch. | Global | 191 |
| `<leader>db` | `n` | Toggle Breakpoint | `require('dap').toggle_breakpoint()` | Global | 125 |
| `<leader>di` | `n` | Step Into | `require('dap').step_into()` | Global | 147 |
| `<leader>dl` | `n` | Toggle diagnostic virtual_lines | Toggle global `virtual_lines`; set global `virtual_text` to the inverse. | LspAttach | 84 |
| `<leader>do` | `n` | Step Out | `require('dap').step_out()` | Global | 158 |
| `<leader>dpc` | `n` | [d]ebug [p]ython [c]lass | `require('dap-python').test_class()` | FileType: python | 63 |
| `<leader>dpm` | `n` | [d]ebug [p]ython [m]ethod | `require('dap-python').test_method()` | FileType: python | 56 |
| `<leader>dps` | `n` | [d]ebug [p]ython [s]election | `require('dap-python').debug_selection()`; currently bound in Normal mode. | FileType: python | 70 |
| `<leader>dq` | `n` | Show project diagnostics | `vim.diagnostic.setqflist()` — collected diagnostics across buffers, not a project scan. | LspAttach | 102 |
| `<leader>dr` | `n` | Toggle REPL | `require('dap').repl.toggle()` | Global | 169 |
| `<leader>dS` | `n` | Step Over | `require('dap').step_over()` | Global | 136 |
| `<leader>ds` | `n` | Start/Continue Debug | `require('dap').continue()` | Global | 114 |
| `<leader>du` | `n` | Toggle DAP UI | `require('dapui').toggle()` | Global | 180 |
| `<leader>dv` | `n` | Verbose Debug Mode | Set DAP logging to DEBUG and LSP logging to debug; no restore/toggle. | Global | 230 |
| `<leader>mi` | `n` | Generate image from code block | `<cmd>KittyScrollbackGenerateImage<CR>` | LspAttach | 109 |
| `<leader>mp` | `n` | Markdown Preview | `<cmd>MarkdownPreview<CR>` | LspAttach | 106 |
| `<leader>mr` | `v` | Run selected code | `:SnipRun<CR>` | LspAttach | 110 |
| `<leader>ms` | `n` | Stop Markdown Preview | `<cmd>MarkdownPreviewStop<CR>` | LspAttach | 107 |
| `<leader>mt` | `n` | Toggle Table Mode | `<cmd>TableModeToggle<CR>` | LspAttach | 108 |
| `<leader>S` | `n` | Run Neovim config self-check | `<cmd>ConfigSelfCheck<CR>` | Global | 35 |
| `<leader>SL` | `n` | Open config self-check log | `<cmd>ConfigSelfCheckLog<CR>` | Global | 41 |
| `<leader>SS` | `n` | Run config syntax check | `<cmd>ConfigSyntaxCheck<CR>` | Global | 46 |


</details>

<details>
<summary>disable.lua — 4 mapping definitions</summary>

These four mappings install `<Nop>`; they do not delete a mapping. They suppress comment-related keys only in LSP-attached buffers, and supply no `desc` metadata.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `gc` | `n` | Disabled (no description set) | `<Nop>` | LspAttach | 17 |
| `gc` | `o` | Disabled (no description set) | `<Nop>` | LspAttach | 20 |
| `gc` | `x` | Disabled (no description set) | `<Nop>` | LspAttach | 19 |
| `gcc` | `n` | Disabled (no description set) | `<Nop>` | LspAttach | 18 |


</details>

<details>
<summary>fzf.lua — backend and command reference</summary>

This regenerated module contains no `vim.keymap.set` calls, no mapping specifications, and no mapping registration function. All previous public action functions are retained; `toggle_search_highlight()` is added as an action for navmap.

One active session owns its process, LSP requests, timer, picker buffer/window, and private temporary directory. New requests cancel the previous session. Source jobs run asynchronously with a 10-second deadline; LSP requests use a 5-second deadline. A picker remains interactive until selection, cancellation, buffer destruction, or Neovim exit. Completed selections are discarded if their original buffer/window is no longer valid or has changed.

| Limit | Value / behavior |
| --- | --- |
| Entries / parsed path records | 20,000; reject over-limit file/grep sources; symbol traversal reports truncation. |
| Process stdout | 8 MiB; terminate and report overflow. |
| Process stderr | 64 KiB; terminate and report overflow. |
| Picker input | 8 MiB; reject oversized assembled input. |
| Displayed label | 2,048 bytes; control bytes removed. Values retain original paths. |
| Symbol traversal | 40,000 visited nodes, depth 32, at most 32 clients; iterative traversal. |
| File permissions | Private mkdtemp directory; input/output created exclusively with mode 0600. |

File discovery and Git status use NUL records so filenames containing spaces, colons, arrows, or newlines keep their identities. Grep uses ripgrep JSON and byte columns; LSP navigation passes the responding client's offset encoding to `show_document`. Git rename destinations follow the documented [porcelain v1 NUL format](https://git-scm.com/docs/git-status#_porcelain_format_version_1).

The picker uses one fixed shell script for terminal redirection, with every variable passed separately as an argument. FZF/skim default-command/default-option environment values and shell startup variables are cleared for the picker process so they cannot change the output protocol or add unexpected picker actions. Search source processes use argv arrays, and grep inserts `--` before the pattern. This navigation module does not implement a project sandbox or add a workspace-trust policy; any such policy in your configuration still needs explicit integration.

Help/color/command completion and Neovim buffer enumeration initially allocate their host-provided result lists; the module enforces its item limit afterward. LSP transport decoding similarly occurs inside Neovim before the bounded symbol walk. Limits therefore bound this module's retained source output and traversal, not the whole editor's memory.

| Command | Action |
| --- | --- |
| `:NativeFzfBuffers` | Find a listed loaded buffer. |
| `:NativeFzfCancel` | Cancel active navigation work and release owned resources. |
| `:NativeFzfColorschemes` | Choose a colorscheme. |
| `:NativeFzfCommands` | Choose an Ex command; prefill command line for editing. |
| `:NativeFzfDocumentSymbols` | Request symbols from capable attached clients. |
| `:NativeFzfFiles` | Find project files; fd, then rg, then find fallback. |
| `:NativeFzfGitBranches` | Choose a local branch and run git switch. |
| `:NativeFzfGitStatus` | Find status entries and open the selected destination path. |
| `:NativeFzfGrep [pattern]` | Prompt if omitted; run a regex search, then fuzzy-filter matches. |
| `:NativeFzfHelp` | Choose a help tag. |
| `:NativeFzfMarks` | Choose a buffer/global mark. |
| `:NativeFzfProjects` | Choose a directory one or two levels beneath projects_directory; change cwd and find its files. |
| `:NativeFzfWorkspaceSymbols` | Prompt for workspace symbol query; symbols without a resolved range are omitted. |
| `:Projects` | Compatibility alias of NativeFzfProjects. |

Project discovery lists directories, not only Git repositories. The find fallback excludes .git but does not implement .gitignore semantics. Selecting a deleted Git status path can open a new empty buffer. Existing build/plugin hooks remain governed by their own configuration.

</details>

<details>
<summary>genmap.lua — 20 mapping definitions</summary>

Command-line expression mappings and forced package update are global. Editing, save, clipboard, and window mappings wait for LSP attachment. In command-line completion, literal j/k select items while the popup is visible instead of refining the typed text.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<C-b>` | `i` | Move to the beginning of the line | `<ESC>^i` | LspAttach | 121 |
| `<C-c>` | `n` | Copy the entire file to the clipboard | `<cmd>%y+<CR>` | LspAttach | 130 |
| `<C-e>` | `i` | Move to the end of the line | `<End>` | LspAttach | 139 |
| `<C-h>` | `i` | Move left by one character | `<Left>` | LspAttach | 157 |
| `<C-h>` | `n` | Switch to the window on the left | `<C-w>h` | LspAttach | 166 |
| `<C-j>` | `c` | Next command-line completion item | Expression: popup visible → `<C-n>`; otherwise → `<C-j>`. | Global | 18 |
| `<C-j>` | `i` | Move down by one line | `<Down>` | LspAttach | 175 |
| `<C-j>` | `n` | Switch to the window below | `<C-w>j` | LspAttach | 184 |
| `<C-k>` | `c` | Previous command-line completion item | Expression: popup visible → `<C-p>`; otherwise → `<C-k>`. | Global | 32 |
| `<C-k>` | `i` | Move up by one line | `<Up>` | LspAttach | 193 |
| `<C-k>` | `n` | Switch to the window above | `<C-w>k` | LspAttach | 202 |
| `<C-l>` | `i` | Move right by one character | `<Right>` | LspAttach | 211 |
| `<C-l>` | `n` | Switch to the window on the right | `<C-w>l` | LspAttach | 220 |
| `<C-s>` | `n` | Save the current file | `<cmd>w<CR>` | LspAttach | 229 |
| `<Down>` | `c` | Next command-line completion item | Expression: popup visible → `<C-n>`; otherwise → `<Down>`. | Global | 46 |
| `<Esc>` | `n` | Clear search highlights | `<cmd>noh<CR>` | LspAttach | 148 |
| `<leader>U` | `n` | Force update vim.pack plugins | `vim.pack.update(nil, { force = true })` | Global | 102 |
| `<Up>` | `c` | Previous command-line completion item | Expression: popup visible → `<C-p>`; otherwise → `<Up>`. | Global | 60 |
| `j` | `c` | Next command-line completion item | Expression: popup visible → `<C-n>`; otherwise → `j`. | Global | 74 |
| `k` | `c` | Previous command-line completion item | Expression: popup visible → `<C-p>`; otherwise → `k`. | Global | 88 |


</details>

<details>
<summary>init.lua — loader and activation</summary>

No key mappings are defined here. `M.setup()` attempts modules in the exact order below, even though this README displays files alphabetically. An earlier unhandled setup error can prevent later modules from loading.

| Order | Module | Entry point selected / status |
| --- | --- | --- |
| 1 | `aimap` | `setup_aimap()` |
| 2 | `cicdmap` | `setup_cicdmap()` |
| 3 | `datamap` | `setup_datamap()`; skips Salesforce setup |
| 4 | `ddxmap` | `setup_ddxmap()` |
| 5 | `disable` | `setup_disable()` |
| 6 | `genmap` | `setup_genmap()` |
| 7 | `langmap` | `setup_langmap()` |
| 8 | `lspmap` | `setup_lspmap()`; commands only |
| 9 | `lintmap` | `setup_lintmap()` |
| 10 | `mojomap` | Referenced; not supplied |
| 11 | `navmap` | `setup_navmap()`; regenerated global mappings |
| 12 | `utilmap` | Referenced; not supplied |

Only `require()` is protected by `pcall`; setup execution is not. Error paths call `vim.echo(...)`, whose definition is not supplied; use a supported reporting API or verify a custom implementation.

</details>

<details>
<summary>langmap.lua — 13 mapping definitions</summary>

The Python/Jupyter maps actually apply to every LSP-attached filetype. Mojo registration is nested inside `LspAttach`: its `FileType` autocmd is created late and repeated on later attachments, so the first Mojo buffer may miss its mappings. Notebook actions mix Jupynium, Iron, Molten, and ToggleTerm; they do not necessarily control the same kernel.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<leader>dmf` | `n` | Debug Mojo file | `:MojoDebug<CR>` | Late FileType: mojo | 32 |
| `<leader>ja` | `n` | [j]upyter [a]ttach to running jupyter notebook | `<cmd>JupyniumAttachToRunningNotebook<CR>` | LspAttach | 89 |
| `<leader>jc` | `n` | [j]upyter [c]lear REPL output | `<cmd>IronReplClear<CR>` | LspAttach | 97 |
| `<leader>jel` | `n` | [j]upter [e]valuate [l]ine | `:MoltenEvaluateLine` | LspAttach | 105 |
| `<leader>jev` | `v` | [j]upyter [e]valuate [v]isual selection | `vim.cmd('MoltenEvaluateVisual')`; callback supplies no explicit visual range. | LspAttach | 115 |
| `<leader>ji` | `n` | [j]upyter [i]nterrupt kernel | `<cmd>JupyniumKernelInterrupt<CR>` | LspAttach | 125 |
| `<leader>jl` | `n` | start [j]upyter [l]ab terminal | Create a new floating ToggleTerm running `jupyter lab`. | LspAttach | 133 |
| `<leader>mr` | `n` | Run Mojo file | `:MojoRun<CR>` | Late FileType: mojo | 28 |
| `<leader>pl` | `n` | [p]ython [l]int | `:PythonLint` | LspAttach | 39 |
| `<leader>ppi` | `n` | 🐍 [p]ython [p]oetry [i]nstall | `:PoetryInstall` | LspAttach | 69 |
| `<leader>ptF` | `n` | 🐍 [p]ython [t]est [F]ile | `:PyTestFile` | LspAttach | 49 |
| `<leader>ptf` | `n` | 🐍 [p]ython [t]est [f]unction | `:PyTestFunc` | LspAttach | 59 |
| `<leader>pu` | `n` | 🐍 [p]ython [p]oetry Update | `:PoetryUpdate` | LspAttach | 79 |


</details>

<details>
<summary>lintmap.lua — 1 mapping definitions</summary>

The only mapping clears diagnostics; this file does not define a run-linter mapping. Clearing diagnostic data is different from hiding its display.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<leader>cd` | `n` | Clear diagnostics | `vim.diagnostic.reset()` with no namespace/buffer filter — clears diagnostic data globally. | LspAttach | 18 |


</details>

<details>
<summary>lspmap.lua — 18 mapping definitions</summary>

`setup_lspmap()` creates commands only. All 18 mappings require an external caller of `M.on_attach(args)`; no caller or `LspAttach` registration is present in the supplied files. “Attach hook” below means conditional on that external integration. Rust-only maps additionally check filetype. Capability-sensitive signature-help and code-lens maps additionally check the attaching client.

| Key | Mode | Description in source | Action / actual behavior | Scope / activation | Line |
| --- | --- | --- | --- | --- | --- |
| `<C-k>` | `i` | Show signature help | `lsp.buf.signature_help` | Attach hook; signatureHelp | 338 |
| `<C-Space>` | `i` | Trigger LSP completion | Call `lsp.completion.get()` when available; returned omnifunc fallback is ignored without `expr = true`. | Attach hook | 293 |
| `<leader>cl` | `n` | Run code lens | `lsp.codelens.run` | Attach hook; codeLens | 348 |
| `<leader>fD` | `n` | Show line diagnostics | `vim.diagnostic.open_float(nil, { scope = 'line' })` | Attach hook | 287 |
| `<leader>li` | `n` | Show LSP info | `<cmd>LspInfo<cr>` | Attach hook | 291 |
| `<leader>re` | `n` | Rust: select edition | Select 2021/2024, update module field, then `:LspRestart`; external configuration consumption unverified. | Attach hook; rust | 313 |
| `<leader>rn` | `n` | Rename symbol | `lsp.buf.rename` | Attach hook | 265 |
| `<leader>rt` | `n` | Rust: select toolchain | Select stable/beta/nightly, update module field, then `:LspRestart`; external configuration consumption unverified. | Attach hook; rust | 319 |
| `<Tab>` | `i` | Accept inline completion | Try `lsp.inline_completion.get()`; returned Tab fallback is ignored without `expr = true`. | Attach hook | 302 |
| `[d` | `n` | Previous diagnostic | `vim.diagnostic.jump({ count = -1 })` | Attach hook | 279 |
| `]d` | `n` | Next diagnostic | `vim.diagnostic.jump({ count = 1 })` | Attach hook | 283 |
| `ca` | `n` | Code actions | `lsp.buf.code_action` | Attach hook | 247 |
| `f` | `n` | Format buffer | Check formatting support; `lsp.buf.format({ async = true, bufnr = bufnr })`; no client filter. | Attach hook | 267 |
| `gd` | `n` | Go to definition | Check definition support; call `lsp.buf.definition({ pos = vim.pos.cursor(...), loclist = true })`. | Attach hook | 249 |
| `gI` | `n` | Go to implementation | `lsp.buf.implementation` | Attach hook | 261 |
| `gs` | `n` | Show document symbols | `lsp.buf.document_symbol` | Attach hook | 263 |
| `gw` | `n` | Show workspace symbols | `lsp.buf.workspace_symbol` | Attach hook | 264 |
| `K` | `n` | Show hover information | `lsp.buf.hover` | Attach hook | 262 |

The following commands are registered by setup, independently of the mapping hook. They are commands, not additional key bindings.

| Command | Behavior |
| --- | --- |
| `:LspInfo` | List clients attached to the current buffer. |
| `:LspRestart [name]` | Stop matching attached clients, wait 100 ms, enable collected names, then edit the original buffer. |
| `:LspStart [name]` | Enable the supplied configuration name; defaults to the filetype string, then edits the buffer. Filetypes are not generally LSP configuration names. |
| `:LspStop [name]` | Stop matching current-buffer clients; an explicit name also disables that configuration. A shared client can serve other buffers. |
| `:RustEdition {edition}` | Store 2021 or 2024 in the module, then restart current-buffer LSP clients. |
| `:RustToolchain {toolchain}` | Store stable, beta, or nightly in the module, then restart current-buffer LSP clients. |


</details>

<details>
<summary>navmap.lua — 24 mapping definitions</summary>

The sole owner of FZF/search mappings. All definitions are global and installed by `setup()` / `setup_navmap()` without waiting for LSP. Repeated setup replaces the same mode/key pairs; no mapping autocmds are added. Optional modules are loaded when their actions run. FZF symbol actions still require a capable attached client, but their key registrations do not.

The original navmap imported the backend's keymaps and recreated them. That indirection and duplication are removed. The table includes the 16 moved FZF/search definitions, six original navmap definitions, and two added shortcuts for projects/cancellation.

| Key | Mode | Description | Action | Scope | Line |
| --- | --- | --- | --- | --- | --- |
| `*` | `n` | Search: highlight current word | `config.nav.fzf.highlight_word_under_cursor()` | Global | 17 |
| `<C-s>` | `c` | Flash: toggle search | `require('flash').toggle()` | Global | 114 |
| `<leader>e` | `n` | Navigation: browse current directory | Structured `:edit` of the file directory; cwd for unnamed/special buffers. | Global | 136 |
| `<leader>z/` | `n` | Search: toggle highlighting | `config.nav.fzf.toggle_search_highlight()` | Global | 19 |
| `<leader>zb` | `n` | FZF: find buffer | `config.nav.fzf.buffers()` | Global | 23 |
| `<leader>zc` | `n` | FZF: find command | `config.nav.fzf.commands()` | Global | 24 |
| `<leader>zd` | `n` | FZF: find document symbol | `config.nav.fzf.document_symbols()` | Global | 25 |
| `<leader>zf` | `n` | FZF: find file | `config.nav.fzf.files()` | Global | 26 |
| `<leader>zgb` | `n` | FZF: switch Git branch | `config.nav.fzf.git_branches()` | Global | 28 |
| `<leader>zgg` | `n` | FZF: grep project | `config.nav.fzf.live_grep()` | Global | 27 |
| `<leader>zgs` | `n` | FZF: find Git status entry | `config.nav.fzf.git_status()` | Global | 29 |
| `<leader>zH` | `n` | FZF: select colorscheme | `config.nav.fzf.colorschemes()` | Global | 31 |
| `<leader>zh` | `n` | FZF: find help tag | `config.nav.fzf.help_tags()` | Global | 30 |
| `<leader>zm` | `n` | FZF: find mark | `config.nav.fzf.marks()` | Global | 32 |
| `<leader>zp` | `n` | FZF: select project directory | `config.nav.fzf.projects()` | Global | 33 |
| `<leader>zw` | `n` | FZF: grep current word | `config.nav.fzf.grep_cword()` | Global | 34 |
| `<leader>zWs` | `n` | FZF: find workspace symbol | `config.nav.fzf.workspace_symbols()` | Global | 35 |
| `<leader>zx` | `n` | FZF: cancel current operation | `config.nav.fzf.cancel()` | Global | 36 |
| `N` | `n` | Search: previous match | `config.nav.fzf.prev_match()` | Global | 38 |
| `n` | `n` | Search: next match | `config.nav.fzf.next_match()` | Global | 37 |
| `R` | `o, x` | Flash: search Tree-sitter nodes | `require('flash').treesitter_search()` | Global | 120 |
| `r` | `o` | Flash: remote jump | `require('flash').remote()` | Global | 117 |
| `S` | `n, x, o` | Flash: jump backward | `require('flash').jump({ search = { forward = false } })` | Global | 126 |
| `s` | `n, x, o` | Flash: jump forward | `require('flash').jump()` | Global | 123 |


</details>

## Conflicts and activation gaps

These findings refer to the supplied setup order. External configuration can change the final effective mapping.

| Key / area | Finding | Practical result |
| --- | --- | --- |
| `<leader>mp` (`n`) | `datamap.lua:62` and `ddxmap.lua:106` use the same LSP-buffer key. | DDX is registered later and replaces math preview with MarkdownPreview. |
| `<leader>mt` (`n`) | `datamap.lua:71` and `ddxmap.lua:108` use the same LSP-buffer key. | TableModeToggle replaces the math text toggle. |
| `<C-k>` (`i`) | `genmap.lua:193` moves up; `lspmap.lua:338` requests signature help. | When the external LSP hook is wired, event order determines the winner. |
| `<leader>S`, `SL`, `SS` (`n`) | A complete action is also the prefix of two longer actions. | The short action can wait for mapping timeout; reserve the prefix for a group. |
| `<leader>zl` / `zli`; `zt` / `zti` | Short keys are both actions and prefixes; the short RHS strings also lack `<CR>`. | Fix command construction and choose distinct leaf keys. |
| `<leader>sfr`, `sft` | SOQL and SOSL define the same keys in disjoint filetypes. | Intentional buffer-local reuse, not a collision; currently skipped by the loader. |
| `<leader>mr` | Normal Mojo run and Visual/Select SnipRun have different modes. | No same-mode collision shown, but the meaning of m mixes Mojo, Markdown, and math. |
| `<C-g>p`, `<C-g>r` | AI actions differ between Normal and Visual/Select modes. | Valid mode-specific reuse; document the different meanings. |
| `ca`, `f`, `gw` (`n`) | Custom LSP keys occupy native editing sequences. | Code actions interfere with change-around text-object input; f replaces character find; gw replaces native formatting operator. |
| LSP maps | No visible caller of `lspmap.on_attach`. | Commands register, but map activation cannot be established from these files. |
| Mojo maps | `FileType` autocmd is created inside `LspAttach`. | Initial FileType may already have passed; repeated attachments create duplicate registrations. |
| Salesforce maps | Loader prefers `setup_datamap()` over `setup()`. | SOQL/SOSL registration is skipped unless an external caller invokes it. |
| Terminal maps | `t` maps are local to the source LSP buffer. | They normally do not exist inside the terminal buffers where they are needed. |
| FZF legacy zs / h | Resolved in regenerated navmap: grep is zgg, search highlight is z/. | cicdmap still owns its original zs and h keys; its unrelated terminal-direction defect remains. |
| FZF duplicate registration | Resolved: fzf setup no longer registers keys; navmap no longer imports a backend keymaps table. | Restart once to remove old anonymous callback registrations. |
| Flash s / S | Preserved, now global in Normal/Visual/Operator-pending modes. | Native substitute/change actions are overridden; revise only if you prefer their original behavior. |

## Recommended naming scheme

Use one domain prefix for cross-language tools, then a short action. Put filetype-specific tools on buffer-local `<LocalLeader>` mappings. The same local key can run Python, Mojo, or a Salesforce query depending on the current buffer. Keep common debug operations in the DAP group even when the current language selects the adapter.

For an easy starting convention, use Space as Leader and comma as LocalLeader, assigned before registering mappings. This is a recommendation, not a requirement: comma is already Vim's reverse-repeat character-search key, so choose another LocalLeader if that motion matters to you. Native documentation reserves LocalLeader for filetype-specific mappings; expression callbacks must opt into expression behavior for returned keys to be processed. See [Neovim mapping documentation](https://github.com/neovim/neovim/blob/master/runtime/doc/map.txt).

The prefix choices below are a proposed personal convention, not a Neovim standard. Check the two missing mapping modules before claiming any key is free. These broad category migrations remain proposals; only the navigation changes in the installation table above have been applied.

<details>
<summary>Categories — proposed prefixes A–Z</summary>

| Category | Prefix | Examples / ownership |
| --- | --- | --- |
| AI | `<leader>a` | `ac` new chat, `af` find chat, `am` model, `ap` provider, `ar` respond, `as` stop; keep Ctrl+g aliases during migration if desired. |
| Configuration | `<leader>c` | `cc` self-check, `cl` self-check log, `cs` syntax check, `cu` package update. Move existing code-lens and diagnostic-reset keys first. |
| DAP | `<leader>d` | `dc` continue, `db` breakpoint, `di` step into, `dn` step over, `do` step out, `dr` REPL, `du` UI. |
| Diagnostics | `<leader>x` | `xd` line details, `xl` virtual lines, `xq` collected diagnostics; preserve `[d` / `]d`. |
| Language-specific actions | `<LocalLeader>` | `r` run, `l` lint, `tn` nearest test, `tf` file tests; install only in relevant buffers. |
| LSP | `<leader>l` | `la` code action, `lf` format, `li` info, `ll` code lens, `lr` rename, `ls` document symbols, `lw` workspace symbols. |
| Navigation | `<leader>z` | Current FZF and Zoxide keys share z; zgg/zgb/zgs group grep/Git. Consider a dedicated Zoxide subgroup in a later migration. |
| SCIP | `<leader>s` | Reserve `si` index, `sl` validate index, `ss` status; query/navigation keys require a real consumer, not just an indexer. Move Salesforce off sf first. |
| Terminal | `<leader>t` | `tf` floating, `th` horizontal, `tv` vertical; reuse persistent instances. |


</details>

<details>
<summary>Language-specific actions — proposed buffer-local keys</summary>

| Action | Proposed key | Examples / scope |
| --- | --- | --- |
| Debug file | `<LocalLeader>df` | Python / Mojo: debug current file with the selected backend. |
| Debug nearest test | `<LocalLeader>dn` | Python method/test under cursor; replaces dpm. |
| Debug selection | `<LocalLeader>ds` (`x`) | Python selection, with explicit visual range handling. |
| Debug test class | `<LocalLeader>dc` | Python class; replaces dpc. |
| Evaluate line / selection | `<LocalLeader>el` / `es` | Notebook integration; select one explicit backend for these actions. |
| Lint buffer | `<LocalLeader>l` | PythonLint or SfQueryLint; same action, filetype-specific implementation. |
| Math text line / buffer | `<LocalLeader>ml` / `mt` | TeX or Markdown math text; avoids Markdown preview keys. |
| Notebook operations | `<LocalLeader>n…` | `na` attach, `nc` clear, `ni` interrupt, `nl` launch; backend must be documented. |
| Poetry install / update | `<LocalLeader>pi` / `pu` | Python only; pi/pu consistently share the Poetry prefix. |
| Preview start / stop | `<LocalLeader>ps` / `px` | Markdown only; p is a group, not also an executable action. |
| Query template | `<LocalLeader>qt` | SOQL/SOSL template for the current filetype. |
| Run current file / query | `<LocalLeader>r` | MojoRun or the appropriate Salesforce query runner; Python only if an actual runner is provided. |
| Rust edition / toolchain | `<LocalLeader>ce` / `ct` | Rust configuration choices; must reach the real workspace/server configuration. |
| Table mode | `<LocalLeader>tt` | Markdown table mode; shares t with filetype-local testing only where those scopes do not overlap. |
| Test file / nearest test | `<LocalLeader>tf` / `tn` | Python: removes the ptF/ptf case-only distinction. |


</details>

<details>
<summary>Migration examples — current keys to proposed keys</summary>

| Current | Proposed | Reason |
| --- | --- | --- |
| `<leader>cd` | `<leader>xc` only if a reset action is retained | Diagnostics belongs under x; define reset scope explicitly. |
| `<leader>cl` | `<leader>ll` | Code lens belongs under LSP; frees configuration log. |
| `<leader>dl` / `dq` | `<leader>xl` / `xq` | Separate diagnostics from debugging. |
| `<leader>ds` / `dS` | `<leader>dc` / `dn` | Continue and next/step-over have distinct lowercase mnemonics. |
| `<leader>fD` | `<leader>xd` | Diagnostics details under one category. |
| `<leader>h` / `v` | `<leader>th` / `tv` | Give terminals one named group. |
| `<leader>mp` / `ms` (Markdown) | `<LocalLeader>ps` / `px` | Filetype-local preview controls. |
| `<leader>mp` / `mt` (math) | `<LocalLeader>ml` / `mt` | Resolve existing overwrites and identify math text. |
| `<leader>rn` | `<leader>lr` | Rename is an LSP action. |
| `<leader>S` / `SL` / `SS` | `<leader>cc` / `cl` / `cs` | Remove a prefix/action overlap; give checks a category. |
| `<leader>sfr` / `sfR` | `<LocalLeader>r` | Unify the query action after deciding whether automatic dispatch is sufficient. |
| `<leader>U` | `<leader>cu` | Package maintenance belongs under configuration; explicitly decide whether force is needed. |
| `ca` / `f` / `gw` | `<leader>la` / `lf` / `lw` | Restore native editing sequences. |


</details>

Keep existing, useful navigation such as `gd`, `gI`, `K`, `[d`, and `]d` when it suits you. Before adding aliases, inspect the defaults shipped with your installed build; current upstream documents `gra`, `gri`, `grn`, and `grr` for common LSP actions. See [Neovim LSP documentation](https://github.com/neovim/neovim/blob/master/runtime/doc/lsp.txt). You can use those defaults alongside the category scheme instead of duplicating every action.

Use descriptions in a consistent `Category: verb object` form: `DAP: toggle breakpoint`, `Diagnostics: show collected diagnostics`, `LSP: rename symbol`, `Python: run nearest test`, and `SCIP: index workspace`. Keep backend names in descriptions when they distinguish actions, such as `Notebook (Molten): evaluate line`. Reserve each group prefix for navigation to its leaves; avoid making a group prefix an action itself.

## TODO checklist

Complete the correctness fixes before changing muscle memory. The priorities are sequential; checklist items within each priority are alphabetical by their bold label. Unchecked items remain recommendations; the completed navigation work is marked below.

### Completed — navigation regeneration

- [x] **Backend separation:** Removed every mapping definition/registration from fzf.lua; centralized FZF, search, Flash, and browsing keys in navmap.lua.
- [x] **Cancellation:** Added one-session ownership, source cancellation, LSP deadline/cancellation, stale-result rejection, and cleanup on picker/source failure and exit.
- [x] **Mapping collisions:** Replaced FZF zs/h with zgg/z/; retained Zoxide and terminal ownership of the old keys.
- [x] **Navigation activation:** Made navigation global and repeatable without LspAttach callbacks; preserved setup aliases.
- [x] **Parsing and positions:** Adopted NUL file/Git records, ripgrep JSON, option-safe grep, and LSP encoding-aware navigation.
- [x] **Verification:** Passed syntax loading and 23 mocked boundary/lifecycle checks; preserved 114 original inventory rows and added 24 navigation definitions.

### Priority 1 — functionality and activation

- [ ] **Completion fallbacks:** Give the `<Tab>` and `<C-Space>` callbacks an expression-capable mapping path, with correct termcode handling, or explicitly insert the fallback keys. Confirm Tab still indents when there is no inline suggestion. Do not assume returning a string from a normal Lua mapping inserts it. (`lspmap.lua:293,302`)
- [ ] **DAP launch selection:** Replace the bare `dap.adapters[choice]()` call with configuration selection and the backend's run/continue flow. Function adapters resolve adapter data through a callback and configuration; they are not zero-argument launch commands. See [nvim-dap adapter documentation](https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt). (`ddxmap.lua:191`)
- [ ] **Diagnostics scope:** Decide whether `<leader>cd` means reset this buffer, reset one source, or hide display. Its current no-argument reset clears diagnostic data across namespaces and buffers. Decide whether virtual-line toggles should be buffer-local too. Rename “project diagnostics” to “collected diagnostics” unless a workspace scan is actually implemented. (`lintmap.lua:18`; `ddxmap.lua:84,102`)
- [ ] **Language activation:** Move Mojo `FileType` registration out of `LspAttach`; scope Python/Poetry maps to Python, Markdown actions to Markdown, and notebook actions to the chosen integration's supported buffers. (`langmap.lua:9,18`; `ddxmap.lua:106`)
- [ ] **Loader entry points:** Standardize modules on one `setup()` entry point or explicitly invoke every required sub-setup. Ensure Salesforce registration runs, protect setup execution as well as require, and replace or verify the unsupplied `vim.echo` helper. (`init.lua:24`; `datamap.lua:151`)
- [ ] **LSP activation:** Wire `lspmap.on_attach` exactly once through the real core LSP integration, or add one named `LspAttach` autocmd. Check already-attached buffers on reload and buffer-level capability changes; avoid installing another hook if one already exists outside this upload. (`lspmap.lua:328,356`)
- [ ] **LSP lifecycle commands:** Resolve actual configuration names instead of treating filetypes as names; check restart against your installed `lsp.enable` behavior instead of relying on a fixed 100 ms delay. Avoid unnecessary `:edit`, handle modified buffers, and document the effect of stopping a client shared by multiple buffers. (`lspmap.lua:96`)
- [ ] **Mapping overwrites:** Separate Markdown and math keys; choose a single Insert-mode `<C-k>` owner. Verify the final owner after multiple clients attach, since later callbacks can overwrite earlier maps. (`datamap.lua:62,71`; `ddxmap.lua:106,108`; `genmap.lua:193`; `lspmap.lua:338`)
- [ ] **Math extraction:** Match double-dollar delimiters before single-dollar delimiters; the first single-dollar pattern currently captures an empty string from `$$...$$`. Decide how escaped dollars, multiple expressions, multiline math, and edits should update extmarks. Label this as math text preview unless actual rendering is implemented. (`datamap.lua:19,41`)
- [ ] **Non-LSP tools:** Register editor, AI, terminal, package, lint, and diagnostics UI mappings independently of language-server attachment when their functionality does not require an LSP client. Ensure plain text and terminal buffers get the applicable shortcuts.
- [ ] **Rust configuration:** Verify that `current_edition` and `current_toolchain` are consumed by the actual workspace/server configuration; the supplied file only stores fields and restarts clients. Handle selector cancellation quietly and prefer workspace-specific state. (`lspmap.lua:62,74,313,319`)
- [ ] **Setup idempotence:** Use named augroups with controlled clearing, and avoid duplicate autocmds on repeated setup. DDX has a group, but clearing it at module load does not make repeated `setup_ddxmap()` calls idempotent by itself.
- [ ] **Terminal construction:** Use valid `horizontal`, `vertical`, or `float` values, retain instances for true toggling, and install Terminal-mode mappings in terminal buffers or globally as intended. See [ToggleTerm configuration and custom-terminal examples](https://github.com/akinsho/toggleterm.nvim). (`cicdmap.lua:18,32,47,66,82`)
- [ ] **Visual actions:** Bind selection-only operations in `x` unless Select mode is intentional. Check Python debug selection and Molten evaluation against the backend's range contract; callbacks must preserve or pass the selected range explicitly where required. (`ddxmap.lua:70`; `langmap.lua:115`)
- [ ] **Zoxide command construction:** Use an editable `:Lz ` / `:Tz ` prompt for argument entry or a complete `<cmd>…<CR>` action. Verify the installed Telescope extension exposes `add` and its split actions; chained `<C-s>`/`<C-v>` should be tested against the picker rather than assumed to choose the desired directory. (`cicdmap.lua:115,123,131,139,164`)

### Priority 2 — categories and naming

- [ ] **Category ownership:** Adopt a documented prefix table; keep DAP on d, LSP on l, SCIP on s, diagnostics on x, and terminals on t if these remain free after reviewing the missing modules.
- [ ] **Description consistency:** Replace bracketed letters, inconsistent capitalization, ambiguous “toggle” labels, and incidental emoji with `Category: verb object`. Correct the “jupter” typo and the mismatched comment on `<leader>jel`; fix the Ctrl+g response comment to describe two Ctrl+g presses.
- [ ] **File ownership:** Rename or split modules by their actual responsibilities: `cicdmap` currently holds terminals/navigation; `ddxmap` mixes four domains; `lintmap` only resets diagnostics; Rust controls are mixed into LSP. Update loader names together with any module moves.
- [ ] **Language reuse:** Introduce buffer-local LocalLeader actions, especially run, lint, debug, and test. Use the same suffix for the same action across languages; do not repeat the language name in every shortcut when the buffer already supplies it.
- [ ] **Native editing:** Restore Normal-mode f, ca-prefixed text-object changes, and gw. Reassess disabling gc/gcc and overriding Insert Ctrl+h/Ctrl+k, Normal Ctrl+g, and other native actions; retain overrides only when the tradeoff is deliberate.
- [ ] **Prefix ambiguity:** Replace `<leader>S` as an action/group overlap; redesign Zoxide's zl/zli and zt/zti overlaps. Prefer lowercase leaf keys with clear words over case-only distinctions such as ptF/ptf and ds/dS.
- [ ] **SCIP ownership:** Reserve index creation/validation/status keys first. Add definition/reference/symbol actions only after confirming a SCIP reader/query implementation and its trust checks; do not invent command names or imply an indexer provides navigation.

### Priority 3 — workflow coverage and adoption

- [ ] **Backend consistency:** Decide which DAP backend these mappings target; the uploaded code uses nvim-dap and companion plugins. Keep any migration to a native backend behind a small, verified interface. Select one notebook backend per action and identify it in descriptions.
- [ ] **Command availability:** Check optional commands/modules when invoked and give a useful unavailable message. Mapping creation alone does not prove Rose, Salesforce, Mojo, Markdown, Poetry, or notebook commands are installed.
- [ ] **Debug workflow:** Add supported terminate/disconnect, restart, run-last, conditional breakpoint, and evaluation actions where useful. Make verbose logging reversible, and report partial failure accurately instead of always announcing both backends changed.
- [ ] **Formatting ownership:** Select the intended formatting client/source so multiple attached servers do not unexpectedly format the same buffer. Add a deliberate range-format action only when supported. (`lspmap.lua:267`)
- [ ] **Lint workflow:** Add explicit run-current-buffer, select/describe linters, and cancel actions if the native linter API supports them. Keep results in the diagnostics group and honor existing workspace-trust gates for process execution.
- [ ] **Missing inventory:** Add `mojomap.lua`, `utilmap.lua`, core LSP attach integration, and any DAP/SCIP modules that create their own keys before calling the inventory complete for the whole configuration.
- [ ] **Safe maintenance:** Decide whether routine package updates need `force = true`; make the shortcut label match the chosen behavior. Keep project command execution behind existing trust checks and avoid interpolating filenames into shell commands in new runners.
- [ ] **Staged migration:** Fix activation and collisions first, migrate one category at a time, retain only conflict-free temporary aliases, then remove aliases after adoption. Changing Leader values must happen before mappings are registered.
- [ ] **Terminal input:** Verify Ctrl+Space, Ctrl+s, Ctrl+h, and Alt chords reach Neovim unchanged in the terminal and desktop session you use. Adjust terminal flow control or desktop bindings only if a real conflict is observed.
- [ ] **Navigation runtime:** Run the regenerated modules in your actual Neovim 0.13 build with fzf/skim, ripgrep, Git, Flash, and LuaLS. Check terminal focus, Escape/Ctrl+C, Unicode symbol jumps, filenames with unusual bytes, and repeated setup. The tests here mock Neovim APIs; they do not replace this integration check.
- [ ] **SCIP and navigation placement:** If adopting the proposed s prefix for SCIP, keep Flash's plain s separate in your documentation. Consider moving Zoxide to a dedicated subgroup rather than adding more mixed z leaves.
- [ ] **Verification:** Check fresh buffers without LSP, with one/multiple clients, after reload, and after detachment. Use `:verbose nmap <leader>mp`, `:verbose imap <C-k>`, `:verbose tmap <A-h>`, and `:verbose autocmd LspAttach` to verify the effective owners. Check soql, sosl, python, rust, mojo, Markdown, and terminal buffers separately; regenerate this README when mappings change.