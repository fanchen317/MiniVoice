"""End-to-end negative fixtures; never edits the user's songs."""
import json
from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[2]
base=root/'.build/lyrics-lite'
folder=base/'negative'
folder.mkdir(exist_ok=True)
template=json.loads((base/'benchmark/chinese/request.json').read_text())
summary=[]
for case in ['silence','wrong-text','wrong-language']:
    wav=folder/(case+'.wav')
    source=(['-f','lavfi','-i','anullsrc=r=16000:cl=mono'] if case=='silence' else
            ['-ss','18','-i',str(base/'multilingual-benchmark/japanese-song/audio.wav')] if case=='wrong-language' else
            ['-i',str(base/'benchmark/chinese/audio.wav')])
    subprocess.run([template['ffmpegPath'],'-nostdin','-v','error','-y',*source,'-t','12',str(wav)],check=True)
    req={**template,'audioPath':str(wav),'duration':12,'useLyricsPrompt':True,
         'forceAlignerPath':str(base/'bin/lyrics-force'),
         'lines':['数据库的事务隔离级别','量子计算机正在处理数据','宇宙飞船穿越银河系']}
    if case=='wrong-language':req['language']='auto'
    request=folder/(case+'-request.json')
    output=folder/(case+'-result.json')
    request.write_text(json.dumps(req,ensure_ascii=False))
    with (folder/(case+'.log')).open('w') as log:
        subprocess.run([str(base/'bin/lyrics-lite'),str(request),str(output)],stdout=log,stderr=log,check=True,timeout=90)
    rows=json.loads(output.read_text())
    matched=sum(row.get('start') is not None for row in rows)
    assert len(rows)==len(req['lines']) and matched==0,(case,rows)
    summary.append({'case':case,'lines':len(rows),'matched':matched})
(folder/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary))
