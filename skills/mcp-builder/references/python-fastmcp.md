# Python MCP Servers with FastMCP (Secondary Path)

Use for the current phlow Python server and for Python-native integrations.
New servers default to `references/rust-rmcp.md`; phlow's server is moving
to Rust nightly on the `rust` branch, so Python work here is maintenance and
parity, not new investment.

## The SDK

- Package `mcp` on PyPI (FastMCP is its server framework). 2.x speaks
  2026-07-28 with legacy back-compat — it flips on upgrade, unlike TS/Go.
  Re-check latest: `curl -s https://pypi.org/pypi/mcp/json | jq -r .info.version`
- Install and run with `uv` (`uv run`, `uv pip install`) per the standing
  Python setup — not bare `pip`.
- Pydantic v2 models are the schema source of truth, like `schemars`/Zod
  elsewhere. Don't hand-write JSON Schema beside Pydantic.

## Minimal pattern

```python
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

mcp = FastMCP("phlow_mcp")

class ReadFileInput(BaseModel):
    path: str = Field(description="Path relative to the allowed root")
    limit: int = Field(default=50, ge=1, le=200)

class ReadFileOutput(BaseModel):
    path: str
    content: str
    truncated: bool

@mcp.tool(
    name="phlow_read_file",
    description="Read a text file under the allowed root.",
    annotations={"readOnlyHint": True},
)
def read_file(input: ReadFileInput) -> ReadFileOutput:
    # re-validate, canonicalize, contain, bound — then work.
    # Raise -> FastMCP converts to an isError result; keep the
    # message safe, log the detail server-side.
    ...
```

## Rules

- `python -m py_compile` is the syntax floor; real testing is the 50/50
  validation/adversarial split in the skill body.
- `subprocess.run([...], shell=False)` — argv arrays, never `shell=True`
  with interpolated strings. Same injection rule as every language.
- Logging to stderr only. Nothing but MCP messages on stdout (stdio).
- Async (`async def`) for I/O-bound tools; don't block the loop.
- Parity rule for phlow: any tool added or changed in the Python server must
  have its contract (name, schemas, annotations, error behavior) mirrored in
  the Rust port, or explicitly marked as Python-only with a reason. The
  rose.nvim client must never see the two disagree.
