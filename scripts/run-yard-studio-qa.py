"""Exercise the freight-yard map in a temporary Studio copy."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys
root = Path(__file__).resolve().parents[1]
pilot = '--pilot' in sys.argv
scenario = '--pilot' if pilot else '--tracker' if '--tracker' in sys.argv else '--yard'
options = [scenario]
if '--high-heat' in sys.argv:
    options.append('--high-heat')
subprocess.run(['python3', 'scripts/build-studio-qa.py', str(root/'.tools/rojo/rojo'), *options], cwd=root, check=True)
artifact = 'Blackout Freight Pilot QA.rbxl' if pilot else 'Blackout Freight Yard QA.rbxl'
with tempfile.TemporaryDirectory(prefix='freight-yard-') as directory:
    folder=Path(directory)
    place=folder/'Scenario.rbxl'
    shutil.copyfile(root/'.tools'/artifact,place)
    launcher,output=folder/'run.luau',folder/'result.log'
    launcher.write_text('''local sim=game:GetService("StudioDeviceSimulatorService")
sim:SetDeviceAsync("iphone_XR")
print("YARD STUDIO RESULT",game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(CLIENT_COUNT,"YardQA"))
'''.replace("CLIENT_COUNT", "3" if pilot else "1"))
    subprocess.run(['/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio','--task','RunScript',
                    '--localPlaceFile',str(place),
                    '--runScriptFile',str(launcher),'--outputFile',str(output),'--quitAfterExecution'],
                   stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=150)
    result=output.read_text()
    for line in result.splitlines():
        if line.startswith('YARD'): print(line)
    assert 'YARD STUDIO RESULT PASS' in result,result[-6000:]
