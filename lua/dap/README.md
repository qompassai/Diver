<!-- /qompassai/Diver/lua/dap/README.md -->
<!-- Qompass AI Diver DAP Docs -->
<!-- Copyright (C) 2026 Qompass AI, All rights reserved -->
<!-- ---------------------------------------- -->

<div align="center">

Qompass AI Diver Tiger-Style Debug Adapter Protocol (DAP) Docs

</div>

[!NOTE]
The config filename identifies the Diver Lua module. The expandable entry below it
lists the actual debugger adapter, backend, or transport used for that language.

Adapter index

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Ada</strong>
    <code>gdb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `ada`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/gdb.lua"><code>gdb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — primary — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Android</strong>
    <code>android.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `kotlin`, native C/C++/Rust libraries, Android processes</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/android.lua"><code>android.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — native-code DAP adapter — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-server"><strong>lldb-server</strong></a> — `lldb-server` — device-side native debug server — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-server">source</a></li>
          <li><a href="https://android.googlesource.com/platform/packages/modules/adb/"><strong>Android Debug Bridge</strong></a> — `adb` — device/process transport used by the adapter — <a href="https://android.googlesource.com/platform/packages/modules/adb/">source</a></li>
          <li><a href="https://docs.oracle.com/en/java/javase/25/docs/specs/jpda/jdwp-spec.html"><strong>JDWP / JDB</strong></a> — `jdb` / JDWP — Java/Kotlin VM attach transport — <a href="https://docs.oracle.com/en/java/javase/25/docs/specs/jpda/jdwp-spec.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Ansible</strong>
    <code>ansible.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `ansible`, `yaml.ansible`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/ansible.lua"><code>ansible.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/jborean93/ansibug"><strong>ansibug</strong></a> — `python -m ansibug dap` — primary — <a href="https://github.com/jborean93/ansibug">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Apex</strong>
    <code>apex.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `apex`, `visualforce`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/apex.lua"><code>apex.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/forcedotcom/salesforcedx-vscode"><strong>Salesforce Apex Replay Debugger</strong></a> — Salesforce extension DAP — debug-log replay — <a href="https://github.com/forcedotcom/salesforcedx-vscode">source</a></li>
          <li><a href="https://github.com/forcedotcom/salesforcedx-vscode"><strong>Salesforce Apex Interactive Debugger</strong></a> — Salesforce extension DAP — interactive org debugging — <a href="https://github.com/forcedotcom/salesforcedx-vscode">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Assembly</strong>
    <code>lldb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `asm`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua"><code>lldb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative / GNU targets — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Bash</strong>
    <code>bash.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `bash`; extensionless `bash`/`sh` shebang scripts</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/bash.lua"><code>bash.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/rogalmic/vscode-bash-debug"><strong>vscode-bash-debug</strong></a> — Node DAP adapter — primary DAP frontend — <a href="https://github.com/rogalmic/vscode-bash-debug">source</a></li>
          <li><a href="https://github.com/rocky/bashdb"><strong>bashdb</strong></a> — `bashdb` — debugger backend used by vscode-bash-debug — <a href="https://github.com/rocky/bashdb">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>C</strong>
    <code>lldb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `c`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua"><code>lldb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>C# / Razor</strong>
    <code>csharp.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `cs`, `razor`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/csharp.lua"><code>csharp.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/Samsung/netcoredbg"><strong>NetCoreDbg</strong></a> — `netcoredbg --interpreter=vscode` — .NET / CoreCLR DAP adapter — <a href="https://github.com/Samsung/netcoredbg">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>C++</strong>
    <code>lldb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `cpp` (`cc`, `cpp`, `cxx`, headers mapped to `cpp`)</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua"><code>lldb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>COBOL</strong>
    <code>cobol.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `cobol` (`cbl`, `cobol`, `cpy`, copybooks)</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/cobol.lua"><code>cobol.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/RechInformatica/rech-cobol-debugger"><strong>Rech COBOL Debugger</strong></a> — Rech DAP adapter — general external COBOL debugger bridge — <a href="https://github.com/RechInformatica/rech-cobol-debugger">source</a></li>
          <li><a href="https://github.com/OCamlPro/superbol-vscode-debug"><strong>SuperBOL GnuCOBOL Debugger</strong></a> — GnuCOBOL + GDB adapter — GnuCOBOL — <a href="https://github.com/OCamlPro/superbol-vscode-debug">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — native/debug-info fallback — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Crystal</strong>
    <code>lldb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `crystal`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua"><code>lldb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary native adapter — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative native adapter — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Cython</strong>
    <code>python.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `cython`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/python.lua"><code>python.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/microsoft/debugpy"><strong>debugpy</strong></a> — `python -m debugpy` — Python/runtime layer — <a href="https://github.com/microsoft/debugpy">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — generated/native extension layer — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Fortran</strong>
    <code>gdb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `fortran`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/gdb.lua"><code>gdb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — primary — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Go</strong>
    <code>go.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `go`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/go.lua"><code>go.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/go-delve/delve"><strong>Delve DAP</strong></a> — `dlv dap` — primary — <a href="https://github.com/go-delve/delve">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Haskell</strong>
    <code>haskell.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `haskell`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/haskell.lua"><code>haskell.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/phoityne/haskell-debug-adapter"><strong>haskell-debug-adapter</strong></a> — `haskell-debug-adapter` — DAP adapter — <a href="https://github.com/phoityne/haskell-debug-adapter">source</a></li>
          <li><a href="https://github.com/phoityne/haskell-dap"><strong>haskell-dap</strong></a> — Haskell DAP protocol implementation — protocol library — <a href="https://github.com/phoityne/haskell-dap">source</a></li>
          <li><a href="https://github.com/phoityne/ghci-dap"><strong>ghci-dap</strong></a> — `ghci-dap` — GHCi debugger backend — <a href="https://github.com/phoityne/ghci-dap">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>JavaScript / TypeScript</strong>
    <code>node.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `javascript`, `javascriptreact`, `typescript`, `typescriptreact`, Glimmer variants</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/node.lua"><code>node.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/microsoft/vscode-js-debug"><strong>vscode-js-debug</strong></a> — standalone js-debug DAP server — Node.js and browser debugging — <a href="https://github.com/microsoft/vscode-js-debug">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Kotlin</strong>
    <code>kotlin.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `kotlin`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/kotlin.lua"><code>kotlin.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/fwcd/kotlin-debug-adapter"><strong>kotlin-debug-adapter</strong></a> — `kotlin-debug-adapter` — Kotlin/JVM DAP adapter — <a href="https://github.com/fwcd/kotlin-debug-adapter">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Lua</strong>
    <code>lua.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `lua`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/lua.lua"><code>lua.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/actboy168/lua-debug"><strong>actboy168/lua-debug</strong></a> — `lua-debug` — Lua/LuaJIT DAP adapter — <a href="https://github.com/actboy168/lua-debug">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Mojo</strong>
    <code>mojo.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `mojo`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/mojo.lua"><code>mojo.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://docs.modular.com/mojo/tools/debugging/"><strong>Mojo LLDB</strong></a> — `mojo-lldb` / `mojo debug` — CPU debugging — <a href="https://docs.modular.com/mojo/tools/debugging/">source</a></li>
          <li><a href="https://docs.modular.com/mojo/cli/debug"><strong>Mojo CUDA-GDB</strong></a> — `mojo-cuda-gdb` / `mojo debug --cuda-gdb` — NVIDIA GPU debugging — <a href="https://docs.modular.com/mojo/cli/debug">source</a></li>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — native-binary DAP path — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Objective-C</strong>
    <code>lldb.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `objc` (`m`, `mm`)</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/lldb.lua"><code>lldb.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>PHP</strong>
    <code>php.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `php`; Blade executes through PHP</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/php.lua"><code>php.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/xdebug/vscode-php-debug"><strong>vscode-php-debug</strong></a> — Node DAP adapter — DAP bridge — <a href="https://github.com/xdebug/vscode-php-debug">source</a></li>
          <li><a href="https://github.com/xdebug/xdebug"><strong>Xdebug</strong></a> — PHP extension / DBGp endpoint — runtime debugger backend — <a href="https://github.com/xdebug/xdebug">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>PowerShell</strong>
    <code>powershell.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `ps1` and PowerShell module/profile patterns</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/powershell.lua"><code>powershell.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/PowerShell/PowerShellEditorServices"><strong>PowerShell Editor Services</strong></a> — PSES Debugging Service — LSP + DAP service — <a href="https://github.com/PowerShell/PowerShellEditorServices">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Python</strong>
    <code>python.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `python`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/python.lua"><code>python.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/microsoft/debugpy"><strong>debugpy</strong></a> — `python -m debugpy.adapter` / debugpy server — primary — <a href="https://github.com/microsoft/debugpy">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Ruby</strong>
    <code>ruby.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `ruby`; ERB/Rails through Ruby</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/ruby.lua"><code>ruby.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/ruby/debug"><strong>rdbg / debug.rb</strong></a> — `rdbg` — Ruby debugger and DAP endpoint — <a href="https://github.com/ruby/debug">source</a></li>
          <li><a href="https://github.com/ruby/vscode-rdbg"><strong>vscode-rdbg</strong></a> — RDBG DAP frontend/client integration — reference implementation — <a href="https://github.com/ruby/vscode-rdbg">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Rust</strong>
    <code>rust.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `rust`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/rust.lua"><code>rust.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary native adapter — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative native adapter — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Scala</strong>
    <code>scala.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `scala`</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/scala.lua"><code>scala.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/scalameta/metals"><strong>Metals DAP</strong></a> — `debug-adapter-start` — DAP endpoint/session broker — <a href="https://github.com/scalameta/metals">source</a></li>
          <li><a href="https://github.com/scalacenter/bloop"><strong>Bloop debugger</strong></a> — Bloop JVM debugger — debugger process used by Metals — <a href="https://github.com/scalacenter/bloop">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;">
    <strong>Zig</strong>
    <code>zig.lua</code>
  </summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Filetypes / runtime:</strong> `zig`; `zon` project metadata</li>
      <li><strong>Diver config:</strong> <a href="https://github.com/qompassai/Diver/blob/main/lua/dap/zig.lua"><code>zig.lua</code></a></li>
      <li><strong>Debug adapter stack:</strong>
        <ul>
          <li><a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap"><strong>LLDB DAP</strong></a> — `lldb-dap` — primary native adapter — <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">source</a></li>
          <li><a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html"><strong>GDB DAP</strong></a> — `gdb -i=dap` — alternative native adapter — <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">source</a></li>
        </ul>
      </li>
    </ul>
  </blockquote>
</details>

Debug adapters

The same adapter can serve several language-specific modules. Diver keeps the
language module responsible for build discovery, roots, source mapping, environment,
pretty-printers, device transport, and launch/attach policy while reusing the underlying
DAP implementation wherever possible.

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;"><strong>LLDB DAP</strong></summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Executable:</strong> <code>lldb-dap</code></li>
      <li><strong>Source:</strong> <a href="https://github.com/llvm/llvm-project/tree/main/lldb/tools/lldb-dap">llvm-project/lldb/tools/lldb-dap</a></li>
      <li><strong>Used by:</strong> Android native code, Assembly, C, C++, Crystal, Mojo native binaries, Objective-C, Rust, Zig.</li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;"><strong>GDB DAP</strong></summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><strong>Executable:</strong> <code>gdb -i=dap</code></li>
      <li><strong>Source / docs:</strong> <a href="https://sourceware.org/gdb/current/onlinedocs/gdb.html/Interpreters.html">GDB DAP interpreter</a></li>
      <li><strong>Used by:</strong> Ada, Assembly, C, C++, COBOL native paths, Crystal, Cython native extensions, Fortran, Objective-C, Rust, Zig.</li>
    </ul>
  </blockquote>
</details>

<details>
  <summary style="font-size: 1.25em; font-weight: bold; padding: 12px; background: #667eea; color: white; border-radius: 10px; cursor: pointer; margin: 8px 0; display: flex; align-items: center; gap: 8px;"><strong>Runtime-specific DAPs</strong></summary>
  <blockquote style="font-size: 1.05em; line-height: 1.7; padding: 20px; background: #f8f9fa; border-left: 6px solid #667eea; border-radius: 8px; margin: 10px 0; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <ul>
      <li><a href="https://github.com/jborean93/ansibug">ansibug</a> — Ansible</li>
      <li><a href="https://github.com/rogalmic/vscode-bash-debug">vscode-bash-debug</a> + <a href="https://github.com/rocky/bashdb">bashdb</a> — Bash</li>
      <li><a href="https://github.com/Samsung/netcoredbg">NetCoreDbg</a> — C# / .NET</li>
      <li><a href="https://github.com/go-delve/delve">Delve DAP</a> — Go</li>
      <li><a href="https://github.com/phoityne/haskell-debug-adapter">haskell-debug-adapter</a> — Haskell</li>
      <li><a href="https://github.com/microsoft/vscode-js-debug">vscode-js-debug</a> — JavaScript / TypeScript</li>
      <li><a href="https://github.com/fwcd/kotlin-debug-adapter">kotlin-debug-adapter</a> — Kotlin</li>
      <li><a href="https://github.com/actboy168/lua-debug">lua-debug</a> — Lua</li>
      <li><a href="https://github.com/xdebug/vscode-php-debug">vscode-php-debug</a> + <a href="https://github.com/xdebug/xdebug">Xdebug</a> — PHP</li>
      <li><a href="https://github.com/PowerShell/PowerShellEditorServices">PowerShell Editor Services</a> — PowerShell</li>
      <li><a href="https://github.com/microsoft/debugpy">debugpy</a> — Python</li>
      <li><a href="https://github.com/ruby/debug">rdbg/debug.rb</a> — Ruby</li>
      <li><a href="https://github.com/scalameta/metals">Metals</a> + <a href="https://github.com/scalacenter/bloop">Bloop</a> — Scala</li>
    </ul>
  </blockquote>
</details>

Filetypes without a dedicated debugger

Configuration, markup, query, template, stylesheet, data, and documentation filetypes
should not receive a synthetic per-filetype DAP merely because Diver recognizes them.
When they participate in an executable application, debug the owning runtime instead
(for example PHP for Blade, Ruby for ERB, Node.js for JavaScript-backed templates,
.NET for Razor, or Apex for Visualforce).
