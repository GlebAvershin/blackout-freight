"""Read-only stdio server for Blackout Freight's experiment contract and demo."""
from typing import Any

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

from compass_report import FIXTURE, ROOT, build_report, read_counts

server = FastMCP("Blackout Freight")


@server.resource("freight://experiments/first-shift-compass-v1", mime_type="text/markdown")
def experiment_contract() -> str:
    return (ROOT.parent / "docs" / "first-shift-experiment.md").read_text(encoding="utf-8")


@server.tool(annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False), structured_output=True)
def analyze_compass_demo() -> dict[str, Any]:
    """Recompute the synthetic compass experiment, including assumptions and data-source label."""
    return build_report(read_counts(FIXTURE), "synthetic")


if __name__ == "__main__":
    server.run(transport="stdio")
