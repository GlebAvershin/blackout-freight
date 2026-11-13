"""Exercise the freight-yard map in a temporary Studio copy."""
from pathlib import Path
import subprocess
import tempfile
import sys
root = Path(__file__).resolve().parents[1]
subprocess.run(['python3','scripts/build-studio-qa.py',str(root/'.tools/rojo/rojo'),'--tracker' if '--tracker' in sys.argv else '--yard'],cwd=root,check=True)
with tempfile.TemporaryDirectory(prefix='freight-yard-') as directory:
    folder=Path(directory)
    launcher,output=folder/'run.luau',folder/'result.log'
    launcher.write_text('''local sim=game:GetService("StudioDeviceSimulatorService")
sim:SetDeviceAsync("iphone_XR")
print("YARD STUDIO RESULT",game:GetService("StudioTestService"):ExecutePlayModeAsync("YardQA"))
''')
    subprocess.run(['/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio','--task','RunScript',
                    '--localPlaceFile',str(root/'.tools/Blackout Freight Yard QA.rbxl'),
                    '--runScriptFile',str(launcher),'--outputFile',str(output),'--quitAfterExecution'],
                   stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=150)
    result=output.read_text()
    for line in result.splitlines():
        if line.startswith('YARD'): print(line)
    assert 'YARD STUDIO RESULT PASS' in result,result[-6000:]
