"""Run the local release checks sequentially; preserve evidence, never publish."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import time
root=Path(__file__).resolve().parents[1]
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
folder=root/'.tools'/('release-qa-'+stamp)
folder.mkdir(parents=True)
candidate=root/'.tools/Blackout Freight Candidate.rbxl'
subprocess.run([str(root/'.tools/rojo/rojo'),'build','-o',str(candidate)],cwd=root,check=True)
checks=[('compile',['.tools/luau/luau-compile','--null','src','tests'])]
checks += [(p.stem,['.tools/luau/luau',str(p.relative_to(root))]) for p in sorted((root/'tests').glob('*.test.luau'))]
checks += [
 ('profiles',['python3','scripts/run-expansion-studio-qa.py']),
 ('gameplay',['python3','scripts/run-progression-gameplay-qa.py']),
 ('progression-restore',['python3','scripts/run-persistence-studio-qa.py']),
 ('roles',['python3','scripts/run-roles-studio-qa.py']),
 ('support-roles',['python3','scripts/run-roles-studio-qa.py','--support']),
 ('yard',['python3','scripts/run-yard-studio-qa.py']),
 ('high-heat',['python3','scripts/run-yard-studio-qa.py','--high-heat']),
 ('tracker',['python3','scripts/run-yard-studio-qa.py','--tracker']),
 ('four-player-restore',['python3','scripts/run-four-player-studio-qa.py']),
 ('mobile-landscape',['python3','scripts/run-mobile-studio-qa.py',str(candidate),'--landscape-only']),
 ('mobile-portrait',['python3','scripts/run-mobile-studio-qa.py',str(candidate),'--portrait-only']),
]
report={'startedUTC':stamp,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'checks':[]}
for name,command in checks:
    start=time.monotonic()
    with (folder/(name+'.log')).open('w') as output:
        try:
            result=subprocess.run(command,cwd=root,stdout=output,stderr=subprocess.STDOUT,timeout=450)
            code=result.returncode
        except subprocess.TimeoutExpired:
            code=124
    entry={'name':name,'exitCode':code,'seconds':round(time.monotonic()-start,2)}
    report['checks'].append(entry)
    (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(name, 'PASS' if code==0 else 'FAIL', flush=True)
print('Evidence:',folder,flush=True)
raise SystemExit(any(entry['exitCode']!=0 for entry in report['checks']))
