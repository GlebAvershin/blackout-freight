"""Build a Studio-only copy for the two-client server scenario."""
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
if solo:
    output = work / "Blackout Freight Solo QA.rbxl"

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
    for variable in ("prompt", "deliver"):
        script = script.replace(f"{variable}.Triggered:Connect(function(player)", f"connectPrompt({variable}, function(player)")
    assert script.count("connectPrompt(") == 3
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
    tree["ServerScriptService"]["Freight"]["$path"] = str(qa / "server")
    tree["ReplicatedStorage"]["Freight"]["$path"] = str(root / "src/shared")
    tree["StarterPlayer"]["StarterPlayerScripts"]["Freight"]["$path"] = str(qa / "client")
    manifest = qa / "qa.project.json"
    manifest.write_text(json.dumps(project))
    subprocess.run([rojo, "build", str(manifest), "-o", str(output)], cwd=root, check=True)
