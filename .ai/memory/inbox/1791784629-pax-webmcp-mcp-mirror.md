---
origin_lane: qompassai
content_label: sfw
---

# WebMCP MCP dialect + scip require repoints mirrored

2026-10-11 (Matt: "move it"). Three commits, origin/main 10961277..2e87b536:
- 06292610 feat(webmcp): bridge.lua routes jsonrpc=2.0 frames to a per-client
  ai.mcp.server.protocol session via new lua/ai/webmcp/mcp_adapter.lua
  (tools/list + tools/call over the endpoint table; CallToolResult decided in
  the adapter; auth mirrors native rules; async endpoints fail closed).
  Includes Matt's live bridge rewrite and scip.status exists/fresh mirrors.
- ac3f9969 fix(recon): gate.lua annotations param typed ToolAnnotations
  (clears the LuaLS missing-fields diagnostic) + StyLua formatting.
- 2e87b536 fix(scip): stale require('scip.query') repointed to dev.scip.query
  in ai/dataaccess, ai/builder (x2), ai/debugbridge/bsp, dev/refactor.
  Companion change on the host: scip-lua-rs installed as ~/.local/bin/scip-lua.
All files gated per-file (luacheck 0/0, StyLua clean, LuaLS settle 0) and the
bridge suite passes 10/10 headless. Live bytes sha-verified into the worktree.
