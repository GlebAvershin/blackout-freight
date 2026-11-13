"""Run the mobile HUD checks in a temporary copy of the built place on macOS."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
studio = "/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
modes = (False,) if "--landscape-only" in sys.argv else ((True,) if "--portrait-only" in sys.argv else (False, True))
client_source = (root / "tests/studio-mobile.client.luau").read_text()
assert "]==]" not in client_source

with tempfile.TemporaryDirectory(prefix="freight-mobile-") as directory:
    folder = Path(directory)
    place, launcher, output = (folder / name for name in ("Mobile QA.rbxl", "run.luau", "results.log"))
    candidate = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "dist/Blackout Freight Closed Test.rbxl"
    shutil.copyfile(candidate, place)
    launcher.write_text(f'''local sim = game:GetService("StudioDeviceSimulatorService")
local test = game:GetService("StudioTestService")
-- Seed only this temporary QA copy; production profiles are never touched.
local shift = game:GetService("ServerScriptService").Freight.Shift
shift.Source = shift.Source:gsub("local profiles = ProfileService.new%(%)", [=[
local qaRecords = {{}}
local profiles = ProfileService.new({{UpdateAsync = function(_, key, callback)
    local old = qaRecords[key] or {{version = 1, scrap = 120, rankXP = 0, sequence = 0, upgrades = {{}}}}
    local value = callback(old)
    if value then qaRecords[key] = value end
    return value
end}})
]=], 1)
local client = Instance.new("LocalScript")
client.Name = "MobileHudQA"
client.Source = [==[
{client_source}]==]
client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
local server = Instance.new("Script")
server.Source = [=[
local studioTest = game:GetService("StudioTestService")
local event = Instance.new("RemoteEvent")
event.Name = "MobileHudResult"
event.OnServerEvent:Connect(function(player, step)
	if step == "seed" then
		player:SetAttribute("EndingBroadcast", true)
		player:SetAttribute("EndingShelter", true)
		player:SetAttribute("ArchiveWest", true)
		player:SetAttribute("ArchiveEast", true)
		player:SetAttribute("BestClearSeconds", 73)
		player:SetAttribute("ArchiveBlackBox", true)
		player:SetAttribute("ArchiveYard", true)
		player:SetAttribute("BestBlackBoxCrewSeconds", 41)
		player:SetAttribute("Aurora", false)
		player:SetAttribute("Crew", false)
		player:SetAttribute("MobileFixtureReady", true)
	elseif step == "briefing" then
        game:GetService("ReplicatedStorage").Freight.Shift:SetAttribute("Phase", "briefing")
    elseif step == "resume" then
        game:GetService("ReplicatedStorage").Freight.Shift:SetAttribute("Phase", "live")
    elseif step == "role-preview" then
        player.Character:PivotTo(CFrame.new(0,3,50))
        player:SetAttribute("Carrying", true)
    elseif step == "role-reset" then
        player.Character:PivotTo(CFrame.new(0,3,59))
        player:SetAttribute("Carrying", false)
    elseif step == "crew" then
		player:SetAttribute("Crew", true)
	elseif step == "done" then
		studioTest:EndTest("PASS")
	end
end)
event.Parent = game:GetService("ReplicatedStorage")
task.delay(60, function() studioTest:EndTest("TIMEOUT") end)
]=]
server.Parent = game:GetService("ServerScriptService")
for _, portrait in {{{", ".join(str(mode).lower() for mode in modes)}}} do
	sim:SetDeviceAsync(portrait and "iphone_XR" or "iphone_7")
	if not portrait then sim:SetResolutionAsync(640, 300) end
	local orientation = portrait and Enum.ScreenOrientation.Portrait or Enum.ScreenOrientation.LandscapeLeft
	-- Studio can reset a sensor orientation when starting Play.
	game:GetService("StarterGui").ScreenOrientation = orientation
	sim:SetOrientationAsync(orientation)
	client:SetAttribute("Portrait", portrait)
	print("MOBILE HUD STUDIO RESULT", portrait, test:ExecuteMultiplayerTestAsync(1,"MobileHudQA"))
end
sim:StopSimulationAsync()
''')
    try:
        subprocess.run([
            studio, "--task", "RunScript", "--localPlaceFile", str(place),
            "--runScriptFile", str(launcher), "--outputFile", str(output), "--quitAfterExecution",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=190)
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
        if output.exists(): print(output.read_text()[-10000:])
        raise
    lines = output.read_text().splitlines()
    for line in lines:
        if line.startswith(("MOBILE HUD", "Players.")):
            print(line)
    assert all(f"MOBILE HUD STUDIO RESULT {mode} PASS" in lines for mode in (str(value).lower() for value in modes))
