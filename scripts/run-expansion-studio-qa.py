"""Check expansion services in a temporary Studio play session; no cloud writes."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
studio = '/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio'
with tempfile.TemporaryDirectory(prefix='freight-expansion-') as directory:
    folder = Path(directory)
    place, launcher, output = (folder / name for name in ('Expansion QA.rbxl', 'run.luau', 'output.log'))
    subprocess.run([str(root / '.tools/rojo/rojo'), 'build', '-o', str(place)], cwd=root, check=True)
    launcher.write_text('''local sim = game:GetService("StudioDeviceSimulatorService")
sim:SetDeviceAsync("iphone_XR")
local test = game:GetService("StudioTestService")
local server = Instance.new("Script")
server.Source = [=[
local test = game:GetService("StudioTestService")
local players = game:GetService("Players")
task.delay(25, function() test:EndTest("TIMEOUT") end)
local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
local deadline = os.clock() + 20
repeat task.wait(0.1) until player:GetAttribute("ProfileStatus") == "local" or os.clock() > deadline
assert(player:GetAttribute("ProfileStatus") == "local", "Profile did not load")
assert(player:GetAttribute("Scrap") == 0 and player:GetAttribute("CrewRank") == 1)
local state = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
repeat task.wait(0.1) until state:GetAttribute("Phase") == "live" or os.clock() > deadline
assert(state:GetAttribute("Phase") == "live", "Shift failed to start")
repeat task.wait(0.1) until player:GetAttribute("MovementVerified") == true or os.clock() > deadline
assert(player:GetAttribute("MovementVerified") == true, "Stationary player flagged")
print("EXPANSION QA PASS profile, rank, shift, movement")
test:EndTest("PASS")
]=]
server.Parent = game:GetService("ServerScriptService")
print("EXPANSION STUDIO RESULT", test:ExecutePlayModeAsync("ExpansionQA"))
''')
    subprocess.run([studio, '--task', 'RunScript', '--localPlaceFile', str(place), '--runScriptFile', str(launcher), '--outputFile', str(output), '--quitAfterExecution'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=100)
    text = output.read_text()
    for line in text.splitlines():
        if line.startswith('EXPANSION'): print(line)
    assert 'EXPANSION STUDIO RESULT PASS' in text, text[-6000:]
