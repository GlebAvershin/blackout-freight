"""Walk a real Studio character through a delivery and reject teleported currency farming."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
subprocess.run(['python3', 'scripts/build-studio-qa.py', str(root / '.tools/rojo/rojo'), '--progression'], cwd=root, check=True)
with tempfile.TemporaryDirectory(prefix='freight-gameplay-') as directory:
    folder = Path(directory)
    place=folder/'Scenario.rbxl'
    shutil.copyfile(root/'.tools/Blackout Freight Progression Gameplay QA.rbxl',place)
    launcher, output = folder / 'run.luau', folder / 'result.log'
    launcher.write_text('''local sim = game:GetService("StudioDeviceSimulatorService")
sim:SetDeviceAsync("iphone_XR")
print("PROGRESSION GAMEPLAY RESULT", game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1,"ProgressionGameplay"))
''')
    subprocess.run(['/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio', '--task', 'RunScript',
                    '--localPlaceFile', str(place),
                    '--runScriptFile', str(launcher), '--outputFile', str(output), '--quitAfterExecution'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=120)
    result = output.read_text()
    for line in result.splitlines():
        if line.startswith('PROGRESSION'): print(line)
    assert 'PROGRESSION GAMEPLAY RESULT PASS' in result, result[-6000:]
