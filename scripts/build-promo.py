"""Caption existing real gameplay without presenting illustration as gameplay."""
from pathlib import Path
import json
import subprocess
root=Path(__file__).resolve().parents[1]
source=root/'dist/blackout-freight-chase-gameplay.mp4'
output=root/'dist/blackout-freight-playtest-promo.mp4'
layers=root/'.tools/promo-layers'
layers.mkdir(exist_ok=True)
subprocess.run(['swift',str(root/'scripts/render-promo-captions.swift'),str(layers)],check=True)
command=['ffmpeg','-v','error','-y','-i',str(source)]
for i in range(3): command += ['-i',str(layers/f'caption-{i}.png')]
graph="[0:v][1:v]overlay=0:H-h-12:enable='lt(t,2.4)'[a];[a][2:v]overlay=0:H-h-12:enable='gte(t,2.4)*lt(t,5.4)'[b];[b][3:v]overlay=0:H-h-12:enable='gte(t,5.4)',format=yuv420p[v]"
command += ['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-crf','18','-preset','medium','-movflags','+faststart',str(output)]
subprocess.run(command,check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,width,height','-of','json',str(output)]))
assert 8 <= float(probe['format']['duration']) <= 12
assert probe['streams'][0]['width']==1280 and probe['streams'][0]['height']==720
print('PROMO PASS',probe)
