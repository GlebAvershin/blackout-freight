import sys
import unittest
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


class MCPTests(unittest.IsolatedAsyncioTestCase):
    async def test_read_only_experiment_via_stdio(self):
        server = Path(__file__).with_name("freight_mcp.py")
        async with stdio_client(StdioServerParameters(
            command=sys.executable, args=[str(server)],
        )) as (incoming, outgoing):
            async with ClientSession(incoming, outgoing) as client:
                await client.initialize()
                tools = (await client.list_tools()).tools
                self.assertEqual([tool.name for tool in tools], ["analyze_compass_demo"])
                self.assertTrue(tools[0].annotations.readOnlyHint)
                resource = await client.read_resource("freight://experiments/first-shift-compass-v1")
                self.assertIn("FirstShiftCompassV1", resource.contents[0].text)
                result = await client.call_tool("analyze_compass_demo")
                self.assertFalse(result.isError)
                self.assertEqual(result.structuredContent["decision"], "simulation_only")
