# TypeScript MCP Servers (Secondary Path)

Use when the server must run where Rust can't go (a JS-only deployment
target, an existing Node codebase) — not as the default. The default is
`references/rust-rmcp.md`.

## The SDK split (verified 2026-09-29 — get this right)

The old single package `@modelcontextprotocol/sdk` is **frozen at 1.30.0**
and only speaks 2025-11-25 (legacy path). Current development is the split:

- `@modelcontextprotocol/core` — shared protocol types
- `@modelcontextprotocol/server` — server role (2.0.0 speaks 2026-07-28)
- `@modelcontextprotocol/client` — client role
- framework adapters as separate packages

Depending on the split packages pulls a heavier tree (HTTP/auth stack) than
a stdio server needs — check what you actually install. Pin exact versions;
re-check latest at the registry:
`curl -s https://registry.npmjs.org/@modelcontextprotocol%2Fserver | jq -r '.["dist-tags"].latest'`

## Minimal registration pattern

```typescript
import { McpServer } from "@modelcontextprotocol/server";
import { StdioServerTransport } from "@modelcontextprotocol/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "phlow-mcp-server", version: "0.1.0" });

server.registerTool(
  "phlow_read_file",
  {
    title: "Read file",
    description: "Read a text file under the allowed root.",
    inputSchema: {
      path: z.string().describe("Path relative to the allowed root"),
      limit: z.number().int().min(1).max(200).default(50),
    },
    outputSchema: {
      // root type object; structuredContent SHOULD conform
      path: z.string(),
      content: z.string(),
      truncated: z.boolean(),
    },
    annotations: { readOnlyHint: true },
  },
  async ({ path, limit }) => {
    // re-validate, canonicalize, contain, bound — then work
    try {
      const result = await readFileUnderRoot(path, limit);
      return {
        content: [{ type: "text", text: formatHuman(result) }],
        structuredContent: result,
      };
    } catch (err) {
      // tool-originated failure → isError result, safe message
      return { isError: true, content: [{ type: "text", text: safeMessage(err) }] };
    }
  }
);

await server.connect(new StdioServerTransport());
```

## Rules that differ from the Rust path

- **Zod is the schema source of truth**, like `schemars` is for Rust. Don't
  hand-write JSON Schema beside Zod — they will drift.
- `npm run build` (tsc, strict) must pass with zero errors; the Inspector
  (`npx @modelcontextprotocol/inspector`) against the built output is the
  manual gate.
- Async everywhere for I/O; never block the event loop on a tool call.
- Same security floor as everywhere: no shell interpolation (argv arrays via
  `spawn`, never `exec` with a string), credentials from env, stderr logging,
  bounded teardown. See `references/threat-model.md` — none of it is
  language-specific.
