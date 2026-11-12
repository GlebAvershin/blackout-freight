"""Build a Studio-only copy for a gameplay or guidance scenario."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
work = root / ".tools"
work.mkdir(exist_ok=True)
rojo = sys.argv[1] if len(sys.argv) > 1 else "rojo"
output = work / "Blackout Freight Server QA.rbxl"
solo = "--solo" in sys.argv[2:]
guidance = "--guidance" in sys.argv[2:]
if solo:
    output = work / "Blackout Freight Solo QA.rbxl"
if guidance:
    output = work / "Blackout Freight Guidance QA.rbxl"

with tempfile.TemporaryDirectory(prefix="freight-qa-", dir=work) as directory:
    qa = Path(directory)
    shutil.copytree(root / "src/server", qa / "server")
    shutil.copyfile(root / "tests/studio-scenario.server.luau", qa / "server/Scenario.server.luau")
    if solo:
        scenario = qa / "server/Scenario.server.luau"
        scenario.write_text(scenario.read_text().replace("local expectedPlayers = 2", "local expectedPlayers = 1"))
    shutil.copyfile(root / "tests/studio-journal.luau", qa / "server/JournalScenario.luau")
    shutil.copytree(root / "src/client", qa / "client")
    shutil.copyfile(root / "tests/studio-operations.client.luau", qa / "client/OperationsScenario.client.luau")
    server = qa / "server/Shift.server.luau"
    script = server.read_text()
    journal_constructor = 'local journal = EndingJournal.new(not RunService:IsStudio() and DataStoreService:GetDataStore("FreightEndings_v1") or nil)'
    assert script.count(journal_constructor) == 1
    script = script.replace(journal_constructor, '''local journal
local studioTest = game:GetService("StudioTestService")
local argsAvailable, testArgs = pcall(studioTest.GetTestArgs, studioTest)
local restore
if argsAvailable and type(testArgs) == "string" then
	restore = testArgs:match("^FourPlayerRestore:(.+)$") or testArgs:match("^BlackBoxCrewRestore:(.+)$")
end
if argsAvailable and (testArgs == "FourPlayerShift" or testArgs == "BlackBoxCrewWrite" or restore) then
	local http = game:GetService("HttpService")
	local records = if restore then http:JSONDecode(restore) else {}
	local store = {}
	function store:GetAsync(key)
		return records[key]
	end
	function store:UpdateAsync(key, update)
		records[key] = update(records[key])
		return records[key]
	end
	journal = EndingJournal.new(store)
	if not restore then
		local snapshot = Instance.new("BindableFunction")
		snapshot.Name = "FreightTestSnapshotJournal"
		snapshot.OnInvoke = function()
			journal:flush()
			return http:JSONEncode(records)
		end
		snapshot.Parent = game:GetService("ServerStorage")
	end
else
	journal = EndingJournal.new(nil)
end''')
    for variable in ("prompt", "deliver", "decoy"):
        script = script.replace(f"{variable}.Triggered:Connect(function(player)", f"connectPrompt({variable}, function(player)")
    assert script.count("connectPrompt(") == 4
    hook = '''assert(RunService:IsStudio(), "QA build is for Studio only")
local handlers = setmetatable({}, {__mode = "k"})
local function connectPrompt(prompt, callback)
	prompt.Triggered:Connect(callback)
	handlers[prompt] = callback
end
local test = Instance.new("BindableFunction")
test.Name = "FreightTestAction"
test.OnInvoke = function(prompt, player)
	assert(handlers[prompt], "unknown prompt")(player)
end
test.Parent = game:GetService("ServerStorage")

'''
    script = script.replace("local routePrompts = {}", hook + "local routePrompts = {}", 1)
    server.write_text(script)
    project = json.loads((root / "default.project.json").read_text())
    tree = project["tree"]
    if guidance:
        # Only the HUD fixture and its completion signal differ from production.
        shutil.copyfile(root / "tests/studio-guidance.client.luau", qa / "client/GuidanceScenario.client.luau")
        (qa / "client/OperationsScenario.client.luau").unlink()
        (qa / "server/Scenario.server.luau").unlink()
        (qa / "server/JournalScenario.luau").unlink()
        shutil.copyfile(root / "src/server/Shift.server.luau", server)
        (qa / "server/GuidanceResult.server.luau").write_text('''assert(game:GetService("RunService"):IsStudio())
local studio = game:GetService("StudioTestService")
local result = Instance.new("RemoteEvent")
result.Name = "GuidanceResult"
result.OnServerEvent:Once(function()
	studio:EndTest("GUIDANCE QA PASS")
end)
result.Parent = game:GetService("ReplicatedStorage")
task.delay(30, function()
	studio:EndTest("GUIDANCE QA TIMEOUT")
end)
''')
    tree["ServerScriptService"]["Freight"]["$path"] = str(qa / "server")
    tree["ReplicatedStorage"]["Freight"]["$path"] = str(root / "src/shared")
    tree["StarterPlayer"]["StarterPlayerScripts"]["Freight"]["$path"] = str(qa / "client")
    manifest = qa / "qa.project.json"
    manifest.write_text(json.dumps(project))
    subprocess.run([rojo, "build", str(manifest), "-o", str(output)], cwd=root, check=True)
