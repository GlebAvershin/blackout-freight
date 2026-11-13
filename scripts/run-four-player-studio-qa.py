"""Four real Studio clients, then a second server with the captured test journal.
Uses only an in-memory fixture; this does not test cloud DataStores or invitations.
"""
from pathlib import Path
import json
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
subprocess.run(['python3','scripts/build-studio-qa.py',str(root/'.tools/rojo/rojo')],cwd=root,check=True)
with tempfile.TemporaryDirectory(prefix='freight-four-') as directory:
    folder=Path(directory)
    def run(argument):
        launcher,output=folder/'run.luau',folder/'output.log'
        launcher.write_text('print("FOUR RESULT", game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(4,'+json.dumps(argument)+'))\n')
        if output.exists(): output.unlink()
        subprocess.run(['/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio','--task','RunScript',
            '--localPlaceFile',str(root/'.tools/Blackout Freight Server QA.rbxl'),'--runScriptFile',str(launcher),
            '--outputFile',str(output),'--quitAfterExecution'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=200)
        result=output.read_text()
        evidence=root/'.tools/four-player-evidence'
        evidence.mkdir(exist_ok=True)
        (evidence/('restore.log' if argument.startswith('FourPlayerRestore:') else 'write.log')).write_text(result)
        values=[line.removeprefix('FOUR RESULT ').strip() for line in result.splitlines() if line.startswith('FOUR RESULT ')]
        assert values,result[-4000:]
        return values[-1]
    snapshot=run('FourPlayerShift')
    assert snapshot.startswith('FourPlayerRestore:'),snapshot
    records=json.loads(snapshot.removeprefix('FourPlayerRestore:'))
    assert len(records)==4 and all(record['broadcast'] for record in records.values())
    print('FOUR QA PASS four clients, five deliveries, four Broadcast journals',flush=True)
    restored=run(snapshot)
    assert restored=='Four-player journal restore passed',restored
    print('FOUR QA PASS second server restored all four journals',flush=True)
