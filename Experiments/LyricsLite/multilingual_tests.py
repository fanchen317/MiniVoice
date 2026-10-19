"""Original-text speech controls plus one real Japanese singing fixture.
Speech controls validate routing/Unicode, not general singing accuracy.
"""
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'.build/lyrics-lite'
WORK=BASE/'multilingual-benchmark'
WORK.mkdir(exist_ok=True)
FFMPEG=shutil.which('ffmpeg')
controls=[
 ('ja','Kyoko',['青い空の下を歩いています','静かな海の音を聞いてください','明日は新しい一日が始まります','大切な思い出を忘れません']),
 ('ko','Yuna',['오늘은 하늘이 아주 맑습니다','조용한 바다의 소리를 들어 보세요','우리는 내일 다시 만날 것입니다','소중한 기억을 오래 간직합니다']),
 ('fr','Thomas',['Le ciel est bleu ce matin','Écoutez le bruit tranquille de la mer','Demain nous prendrons le train ensemble','Je garde ces souvenirs dans mon cœur']),
 ('es','Monica',['El cielo está muy claro esta mañana','Escucha el sonido tranquilo del mar','Mañana volveremos a caminar juntos','Siempre guardaré estos recuerdos']),
 ('de','Anna',['Der Himmel ist heute wunderbar blau','Höre auf die leisen Wellen am Meer','Morgen werden wir uns wiedersehen','Diese schönen Erinnerungen bleiben bei mir']),
 ('ar','Maged',['السماء صافية في هذا الصباح','استمع إلى صوت البحر الهادئ','سوف نلتقي مرة أخرى في الغد','سوف تبقى هذه الذكريات معي']),
 ('hi','Lekha',['आज सुबह आसमान बहुत साफ है','समुद्र की शांत आवाज सुनिए','हम कल फिर एक साथ मिलेंगे','ये सुंदर यादें हमेशा मेरे साथ रहेंगी']),
 ('th','Kanya',['วันนี้ท้องฟ้าสดใสมาก','ลองฟังเสียงคลื่นทะเลที่เงียบสงบ','พรุ่งนี้เราจะได้พบกันอีกครั้ง','ฉันจะเก็บความทรงจำนี้ไว้เสมอ']),
]

def duration(path):
 return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(path)]))

def evaluate(folder,clip,reference,language,kind):
 request=dict(audioPath=str(clip),duration=duration(clip),lines=[r['text'] for r in reference],language=language,
              modelPath=str(BASE/'models/ggml-small-q5_1.bin'),cliPath=str(BASE/'build/bin/whisper-cli'),
              ffmpegPath=FFMPEG,useLyricsPrompt=True,forceAlignerPath=str(BASE/'bin/lyrics-force'))
 p=folder/('request-'+language+'.json');p.write_text(json.dumps(request,ensure_ascii=False))
 output=folder/('result-'+language+'.json');began=time.monotonic()
 with (folder/('run-'+language+'.log')).open('w') as log:
  subprocess.run([str(BASE/'bin/lyrics-lite'),str(p),str(output)],stdout=log,stderr=log,timeout=180,check=True)
 rows=json.loads(output.read_text());errors=[abs(a['start']-r['start']) for a,r in zip(rows,reference) if a.get('start') is not None]
 return dict(case=folder.name,kind=kind,language=language,seconds=round(time.monotonic()-began,2),lines=len(reference),matched=len(errors),
             median_error=round(statistics.median(errors),3) if errors else None,max_error=round(max(errors),3) if errors else None,
             within_1_second=sum(e<=1 for e in errors),text_preserved=[r['text'] for r in rows]==request['lines'])

results=[]
for code,voice,texts in controls:
 folder=WORK/('speech-'+code);folder.mkdir(exist_ok=True)
 try:
  reference=[];chunks=[];offset=0
  for i,text in enumerate(texts):
   aiff=folder/f'{i}.aiff';wav=folder/f'{i}.wav'
   subprocess.run(['say','-v',voice,'-o',str(aiff),text],check=True,timeout=30,capture_output=True)
   subprocess.run([FFMPEG,'-nostdin','-v','error','-y','-i',str(aiff),'-af','apad=pad_dur=0.6','-ar','16000','-ac','1',str(wav)],check=True)
   reference.append(dict(text=text,start=offset));offset+=duration(wav);chunks.append(wav)
  listing=folder/'concat.txt';listing.write_text(''.join("file '"+str(p)+"'\n" for p in chunks));clip=folder/'audio.wav'
  subprocess.run([FFMPEG,'-nostdin','-v','error','-y','-f','concat','-safe','0','-i',str(listing),'-c','copy',str(clip)],check=True)
  (folder/'reference.json').write_text(json.dumps(reference,ensure_ascii=False,indent=2))
  for language in [code,'auto']:
   row=evaluate(folder,clip,reference,language,'synthetic-speech');results.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
 except Exception as e:
  row=dict(case=folder.name,error=str(e));results.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
 (WORK/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))

music=Path(os.environ.get('MINIVOICE_LITE_MUSIC',str(Path.home()/'Downloads/01通用格式歌曲(完整)')))
audio=next(p for p in music.iterdir() if p.name.startswith('770 - ') and p.suffix=='.mp3')
reference=[]
for line in (music/'lrc'/(audio.stem+'.lrc')).read_text().splitlines():
 m=re.match(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)',line)
 if m:
  t=int(m[1])*60+float(m[2]);text=re.sub(r'<[^>]*>','',m[3]).strip()
  if 0.2<t<61 and text:reference.append(dict(text=text,start=t))
folder=WORK/'japanese-song';folder.mkdir(exist_ok=True);clip=folder/'audio.wav'
subprocess.run([FFMPEG,'-nostdin','-v','error','-y','-i',str(audio),'-t','65','-vn','-ar','16000','-ac','1',str(clip)],check=True)
(folder/'reference.json').write_text(json.dumps(reference,ensure_ascii=False,indent=2))
for language in ['ja','auto']:
 row=evaluate(folder,clip,reference,language,'real-singing');results.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
(WORK/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
