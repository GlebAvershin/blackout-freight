"""Exercise role abilities on two Studio clients; injected hooks exist only in the QA copy."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
subprocess.run(['python3', 'scripts/build-studio-qa.py', str(root / '.tools/rojo/rojo'), '--roles'], cwd=root, check=True)
with tempfile.TemporaryDirectory(prefix='freight-roles-') as directory:
    folder = Path(directory)
    launcher, output = folder / 'run.luau', folder / 'result.log'
    launcher.write_text('''local sim = game:GetService("StudioDeviceSimulatorService")
sim:SetDeviceAsync("iphone_XR")
print("ROLES STUDIO RESULT", game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, "RolesQA"))
''')
    subprocess.run(['/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio', '--task', 'RunScript',
                    '--localPlaceFile', str(root / '.tools/Blackout Freight Roles QA.rbxl'),
                    '--runScriptFile', str(launcher), '--outputFile', str(output), '--quitAfterExecution'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=190)
    result = output.read_text()
    for line in result.splitlines():
        if line.startswith('ROLES'): print(line)
    assert 'ROLES STUDIO RESULT PASS' in result, result[-6000:]
