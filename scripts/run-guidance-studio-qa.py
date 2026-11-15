"""Build and run first-shift guidance QA on macOS."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
work = root / ".tools"
studio = "/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
subprocess.run(
    ["python3", "scripts/build-studio-qa.py", str(work / "rojo/rojo"), "--guidance"],
    cwd=root, check=True,
)
launcher = work / "guidance-qa-launcher.luau"
output = work / "guidance-qa-output.log"
output.unlink(missing_ok=True)
launcher.write_text('''task.wait(3)
local studio = game:GetService("StudioTestService")
local result = studio:ExecutePlayModeAsync("FreightGuidance")
if result == nil then
    task.wait(2)
    result = studio:ExecutePlayModeAsync("FreightGuidance")
end
print("GUIDANCE STUDIO RESULT", result)
''')
try:
    subprocess.run([
        studio, "--task", "RunScript", "--localPlaceFile", str(work / "Blackout Freight Guidance QA.rbxl"),
        "--runScriptFile", str(launcher), "--outputFile", str(output), "--quitAfterExecution",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=150)
finally:
    if output.exists():
        print(output.read_text())
if not output.exists() or "GUIDANCE STUDIO RESULT GUIDANCE QA PASS" not in output.read_text().splitlines():
    raise SystemExit("Studio guidance did not pass")
