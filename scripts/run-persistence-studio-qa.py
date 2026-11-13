"""Fresh ending + earned Scrap + client-selected role across two Studio processes.

Storage is a JSON-roundtripped fixture, not Roblox cloud DataStores.
Production target, timer, drone and reward rules are unchanged.
"""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
subprocess.run(['python3', 'scripts/build-studio-qa.py', str(ROOT / '.tools/rojo/rojo'), '--persistence'], cwd=ROOT, check=True)
evidence = ROOT / '.tools/persistence-evidence'
evidence.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='freight-persistence-') as directory:
    folder = Path(directory)
    def run(argument, label):
        launcher, output = folder / 'run.luau', evidence / f'{label}.log'
        launcher.write_text('print("PERSISTENCE RESULT", game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1,' + json.dumps(argument) + '))\n')
        if output.exists():
            output.unlink()
        subprocess.run(['/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio', '--task', 'RunScript',
            '--localPlaceFile', str(ROOT / '.tools/Blackout Freight Persistence QA.rbxl'),
            '--runScriptFile', str(launcher), '--outputFile', str(output), '--quitAfterExecution'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=250)
        text = output.read_text()
        for line in text.splitlines():
            if line.startswith('PERSISTENCE') and not line.startswith('PERSISTENCE RESULT'):
                print(line, flush=True)
        values = [line.removeprefix('PERSISTENCE RESULT ').strip() for line in text.splitlines() if line.startswith('PERSISTENCE RESULT ')]
        assert values, text[-4000:]
        return values[-1]
    snapshot = run('PersistenceWrite', 'write')
    assert snapshot.startswith('PersistenceRestore:'), snapshot
    records = json.loads(snapshot.removeprefix('PersistenceRestore:'))
    assert len(records['profile']) == len(records['journal']) == 1
    profile = next(iter(records['profile'].values()))
    journal = next(iter(records['journal'].values()))
    assert profile['scrap'] == profile['rankXP'] == 50 and profile['preferences']['role'] == 'Technician'
    assert journal['broadcast'] and not journal['shelter']
    (evidence / 'snapshot.json').write_text(json.dumps(records, indent=2))
    assert run(snapshot, 'restore') == 'PERSISTENCE RESTORE PASS'
    print('PERSISTENCE QA PASS two processes, new Broadcast, 50 Scrap, Technician restored', flush=True)
