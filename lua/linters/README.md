<!-- /qompassai/Diver/linters/README.md -->
<!-- Qompass AI Diver Linters -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- ---------------------------------------- -->

<div align="center">
  <details style="display: inline-block; text-align: left; max-width: 600px; width: 100%;">
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <div class="icon-row" style="display: flex; align-items: center; gap: 6px;">
      <img src="https://raw.githubusercontent.com/qompassai/svg/refs/heads/main/assets/icons/abap/abap.svg"
           alt="abap" width="60" height="60" title="Abap" />
    </div>
    <strong>Advanced Business Application Programming(ABAP)</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li>
        <a href="https://github.com/qompassai/diver/blob/main/lsp/abaplint_ls.lua">abaplint_ls</a>
      </li>
        <p>
      <a href="https://github.com/abaplint/abaplint">Abaplint LSP Reference</a>
    </p>
 <div style="background: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 10px; font-family: monospace;">

```bash
:TODO
```

</div>
    </ul>
  </blockquote>
</details>
<details style="display: inline-block; text-align: left; max-width: 600px; width: 100%;">
<summary style="font-size: 1.4em; font-weight: bold; padding: 15px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 10px 0; display: flex; align-items: center; gap: 8px;">
    <strong>New Linter Adapters (21)</strong>
  </summary>
  <blockquote style="font-size: 1.2em; line-height: 1.8; padding: 25px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 15px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <p>
      Plain-language guide to the adapters added in this round: which tool runs,
      what it checks, and which filetypes it runs on.
    </p>
    <table>
      <tr><th>Tool</th><th>What it checks</th><th>Filetypes</th></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/cspell.lua">cspell</a></td><td>Spots misspelled words in code and prose</td><td>markdown, text</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/deno.lua">deno</a></td><td>Deno's built-in checker for JavaScript and TypeScript</td><td>javascript, javascriptreact, jsx, tsx, typescript, typescriptreact</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/eslint.lua">eslint</a></td><td>Enforces style and correctness rules for JavaScript and TypeScript</td><td>javascript, javascriptreact, jsx, tsx, typescript, typescriptreact, vue</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/fish.lua">fish</a></td><td>Checks fish shell scripts for syntax mistakes without running them</td><td>fish</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/flake8.lua">flake8</a></td><td>Referees Python style: line length, unused imports, spacing</td><td>python</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/json_tool.lua">json_tool</a></td><td>Verifies JSON is well-formed using Python's own parser</td><td>json</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/markdownlint-cli2.lua">markdownlint-cli2</a></td><td>Checks Markdown against a style guide: trailing spaces, headings, line length</td><td>markdown, markdown.mdx, quarto</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/mypy.lua">mypy</a></td><td>Proofreads Python type hints for mismatches</td><td>python</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/php.lua">php</a></td><td>Asks PHP itself to check syntax without running the file</td><td>php</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/pycodestyle.lua">pycodestyle</a></td><td>Checks Python against the official PEP 8 style guide</td><td>python</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/pylint.lua">pylint</a></td><td>Strict Python teacher: bugs, conventions, and code smells</td><td>python</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/quick-lint-js.lua">quick-lint-js</a></td><td>Catches JavaScript typos at lightning speed</td><td>javascript, javascriptreact, jsx, tsx, typescript, typescriptreact</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/ruby.lua">ruby</a></td><td>Asks Ruby itself to check syntax without running the file</td><td>ruby</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/ruff.lua">ruff</a></td><td>Super-fast Python checker for style and error rules</td><td>python</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/selene.lua">selene</a></td><td>Checks Lua code, e.g. unused variables</td><td>lua</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/sqruff.lua">sqruff</a></td><td>Fast SQL linter for style and correctness</td><td>sql</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/tombi.lua">tombi</a></td><td>Checks TOML config files for syntax and style problems</td><td>toml</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/vale.lua">vale</a></td><td>Proofreads prose against writing style rules</td><td>markdown, text</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/write_good.lua">write_good</a></td><td>Writing coach that nags about weasel words and passive voice</td><td>markdown, text</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/zizmor.lua">zizmor</a></td><td>Security checker for GitHub Actions workflow files</td><td>yaml.ghaction, yaml.github</td></tr>
      <tr><td><a href="https://github.com/qompassai/diver/blob/main/lua/linters/zsh.lua">zsh</a></td><td>Checks Zsh scripts for syntax mistakes without running them</td><td>zsh</td></tr>
    </table>
  </blockquote>
</details>
<details>
</details>
