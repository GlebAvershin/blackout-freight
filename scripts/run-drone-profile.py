"""Measure Heat 5 on a local Studio server with four clients (macOS)."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ref", help="Use production sources from this Git revision")
parser.add_argument("--rojo", default="rojo")
args = parser.parse_args()
rojo = str(Path(args.rojo).resolve()) if Path(args.rojo).is_file() else args.rojo


def replace_once(source, original, replacement):
    if source.count(original) != 1:
        raise ValueError(f"Expected exactly one profiling hook: {original}")
    return source.replace(original, replacement, 1)


with tempfile.TemporaryDirectory(prefix="freight-heat5-") as directory:
    copy = Path(directory)
    for name in ("src", "tests", "scripts"):
        shutil.copytree(root / name, copy / name)
    shutil.copyfile(root / "default.project.json", copy / "default.project.json")
    if args.ref:
        for source in (copy / "src").rglob("*.luau"):
            source.write_bytes(subprocess.check_output(
                ["git", "show", f"{args.ref}:{source.relative_to(copy)}"], cwd=root,
            ))

    server = copy / "src/server"
    (server / "DroneProbe.luau").write_text("return {samples = {}, move = 0, rays = 0, parts = 0}")
    shift = server / "Shift.server.luau"
    source = "local probe = require(script.Parent.DroneProbe)\n" + shift.read_text()
    source = replace_once(source, "Random.new()", "Random.new(7105)")
    source = replace_once(source, "\t\tstartShift()", """		while #Players:GetPlayers() ~= 4 do task.wait(0.1) end
		startShift()""")
    source = replace_once(source, "moveDrone(math.min(dt, 0.15))", """probe.move, probe.rays, probe.parts = 0, 0, 0
				local started = os.clock()
				debug.profilebegin("Heat5.MoveDrone")
				moveDrone(math.min(dt, 0.15))
				debug.profileend()
				local elapsed = os.clock() - started
				if probe.record then
					table.insert(probe.samples, {elapsed, probe.move, probe.rays, probe.parts,
						state:GetAttribute("SentinelMode"), dt})
				end""")
    shift.write_text(source)
    controller = server / "SentinelController.luau"
    source = "local probe = require(script.Parent.DroneProbe)\n" + controller.read_text()
    move_calls = {
        "drone:PivotTo(CFrame.lookAt(dronePoint, dronePoint + dir))": 8,
        "unit.model:PivotTo(CFrame.lookAt(nextPoint, nextPoint + delta.Unit))": 8,
        "body.CFrame = CFrame.lookAt(dronePoint, dronePoint + dir)": 1,
        "unit.body.CFrame = CFrame.lookAt(nextPoint, nextPoint + delta.Unit)": 1,
    }
    instrumented = 0
    for call, part_count in move_calls.items():
        if call in source:
            instrumented += 1
            source = replace_once(source, call, f"""do
				local started = os.clock()
				debug.profilebegin("Heat5.DroneTransforms")
				{call}
				debug.profileend()
				probe.move += os.clock() - started
				probe.parts += {part_count}
			end""")
    if instrumented != 2:
        raise ValueError("Expected one Sentinel and one Swarm movement hook")
    source = replace_once(source, "local clearPath = callbacks.clearPath", """local function clearPath(origin, target)
		probe.rays += 1
		return callbacks.clearPath(origin, target)
	end""")
    controller.write_text(source)
    shutil.copyfile(root / "tests/studio-drone-profile.server.luau", copy / "tests/studio-high-heat.server.luau")
    subprocess.run([
        sys.executable, "scripts/build-studio-qa.py", rojo, "--yard", "--high-heat",
    ], cwd=copy, check=True)

    launcher = copy / "run.luau"
    launcher.write_text('''local test = game:GetService("StudioTestService")
print("RESULT", test:ExecuteMultiplayerTestAsync(4, "YardQA"))
''')
    output = copy / "studio.log"
    try:
        subprocess.run([
            "/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio",
            "--task", "RunScript", "--localPlaceFile", str(copy / ".tools/Blackout Freight Yard QA.rbxl"),
            "--runScriptFile", str(launcher), "--outputFile", str(output), "--quitAfterExecution",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=225)
    finally:
        if output.exists():
            print(output.read_text()[-10000:])
    if "RESULT PROFILE PASS" not in output.read_text():
        sys.exit("Heat 5 benchmark did not finish")
