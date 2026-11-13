"""Check a release artifact and the production source inventory without publishing."""
import argparse
import hashlib
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, default=ROOT/'dist/Blackout Freight Progression Preview.rbxl')
    parser.add_argument('--rojo', default=str(ROOT/'.tools/rojo/rojo'))
    args = parser.parse_args()
    payload = args.artifact.read_bytes()
    assert payload.startswith(b'<roblox!\x89\xff\r\n\x1a\n'), 'Not a binary Roblox place'
    with tempfile.TemporaryDirectory(prefix='freight-release-') as directory:
        folder = Path(directory)
        binary, xml = folder/'candidate.rbxl', folder/'candidate.rbxlx'
        for output in (binary, xml):
            subprocess.run([args.rojo, 'build', '-o', str(output)], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        assert binary.read_bytes() == payload, 'Artifact differs from the current production project'
        scripts = [item for item in ET.parse(xml).iter('Item') if item.get('class') in ('Script','LocalScript','ModuleScript')]
        assert scripts, 'Empty source inventory'
        for item in scripts:
            source = item.find('./Properties/*[@name="Source"]').text or ''
            for marker in ('FreightTestAction', 'EndTest(', 'QA PASS'):
                assert marker not in source, 'Test hook in release: '+marker
        print(json.dumps({'artifact':str(args.artifact), 'sha256':hashlib.sha256(payload).hexdigest(),
                          'scripts':len(scripts), 'matchesProductionProject':True}, indent=2))

if __name__ == '__main__':
    main()
