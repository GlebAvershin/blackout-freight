"""Check the outage lifecycle and crew ping replication on two Studio clients."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
studio = "/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
server = (root / "tests/studio-blackout.server.luau").read_text()
client = (root / "tests/studio-blackout.client.luau").read_text()
assert "]==]" not in server and "]==]" not in client

with tempfile.TemporaryDirectory(prefix="freight-blackout-") as directory:
    folder = Path(directory)
    place, launcher, output = (folder / name for name in ("Blackout QA.rbxl", "run.luau", "results.log"))
    shutil.copyfile(sys.argv[1], place)
    launcher.write_text(f'''
local serverRoot = game:GetService("ServerScriptService")
local shared = game:GetService("ReplicatedStorage").Freight
local shift = serverRoot.Freight.Shift
-- Accelerate the ordinary first shift and outage without replacing their state machines.
local accelerated, replacements = shift.Source:gsub("roundStartedAt %+ Config%.ShiftSeconds, ids",
    "roundStartedAt + (blackoutStartsAt and Config.ShiftSeconds or 6), ids")
assert(replacements == 1)
shift.Source = accelerated
local sector = shared.SectorBlackout
sector.Source = sector.Source:gsub("EarliestSeconds = 35", "EarliestSeconds = 4")
local server = Instance.new("Script")
server.Source = [==[{server}]==]
server.Parent = serverRoot
local client = Instance.new("LocalScript")
client.Source = [==[{client}]==]
client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
print("BLACKOUT STUDIO RESULT", game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, "BlackoutQA"))
''')
    subprocess.run([studio, "--task", "RunScript", "--localPlaceFile", str(place),
                    "--runScriptFile", str(launcher), "--outputFile", str(output), "--quitAfterExecution"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=160)
    result = output.read_text()
    print("\n".join(line for line in result.splitlines() if line.startswith("BLACKOUT")))
    assert "BLACKOUT STUDIO RESULT PASS" in result, result[-7000:]
