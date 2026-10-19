"""Read-only local comparison. Python is a benchmark tool, not part of the lite worker."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import statistics
import sys

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(os.environ.get('MINIVOICE_LITE_BENCHMARK_DIR',str(ROOT / ('.build/lyrics-lite/full-benchmark' if '--full' in sys.argv else '.build/lyrics-lite/benchmark'))))
WORK.mkdir(parents=True, exist_ok=True)
MUSIC = Path(os.environ.get('MINIVOICE_LITE_MUSIC', str(Path.home()/'Downloads/01通用格式歌曲(完整)')))
FFMPEG = shutil.which('ffmpeg')
NATIVE = ROOT / '.build/native/MiniVoice.app/Contents/Resources'
fixtures = [('chinese', '014', 10, 65, 'zh'), ('chorus', '852', 65, 125, 'zh'),
            ('mixed', '992', 38, 98, 'zh'), ('english', '968', 0, 60, 'en')]
if '--full' in sys.argv:
    fixtures = [('holdout-chinese', '017', 0, None, 'zh'),
                ('full-mixed', '992', 0, None, 'zh'), ('full-english', '968', 0, None, 'en')]
results = json.loads((WORK/'results.json').read_text()) if '--resume' in sys.argv and (WORK/'results.json').exists() else []
for label, serial, left, right, language in fixtures:
    folder = WORK / label
    folder.mkdir(exist_ok=True)
    audio = next(p for p in MUSIC.iterdir() if p.name.startswith(serial+' - ') and p.suffix in {'.mp3', '.flac'})
    if right is None:
        right=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(audio)]))
    sidecar = MUSIC / 'lrc' / (audio.stem+'.lrc')
    reference = []
    for line in sidecar.read_text().splitlines():
        match = re.match(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)', line)
        if not match:
            continue
        stamp = int(match[1])*60+float(match[2])
        text = re.sub(r'<[^>]+>', '', match[3]).strip()
        if left+0.2 <= stamp < right-4 and text and not re.search(r'词：|曲：|编曲：', text):
            reference.append({'text': text, 'start': stamp-left})
    # End clips before the following unrequested lyric line to avoid edge bias.
    clip = folder / 'audio.wav'
    subprocess.run([FFMPEG, '-v', 'error', '-y', '-ss', str(left), '-i', str(audio), '-t', str(right-left),
                    '-vn', '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', str(clip)], check=True)
    request = dict(audioPath=str(clip), duration=right-left, lines=[r['text'] for r in reference], language=language,
                   model='small', modelDirectory=str(NATIVE/'LyricsModels'),
                   modelPath=str(ROOT/'.build/lyrics-lite/models/ggml-small-q5_1.bin'),
                   cliPath=str(ROOT/'.build/lyrics-lite/build/bin/whisper-cli'), ffmpegPath=FFMPEG)
    request_path = folder/'request.json'
    request_path.write_text(json.dumps(request, ensure_ascii=False))
    (folder/'reference.json').write_text(json.dumps(reference, ensure_ascii=False, indent=2))
    engines = ['lite-forced', 'baseline'] if '--full' in sys.argv else ['lite', 'lite-guided', 'lite-forced', 'baseline']
    for engine in engines:
        if any(r['fixture']==label and r['engine']==engine for r in results):
            continue
        request['useLyricsPrompt'] = engine in ['lite-guided','lite-forced']
        request['forceAlignerPath'] = str(ROOT/'.build/lyrics-lite/bin/lyrics-force') if engine=='lite-forced' else None
        request_path.write_text(json.dumps(request, ensure_ascii=False))
        output = folder/f'{engine}.json'
        command = ([str(ROOT/'.build/lyrics-lite/bin/lyrics-lite'), str(request_path), str(output)] if engine.startswith('lite') else
                   [str(NATIVE/'lyrics-worker/lyrics-worker'), str(request_path), str(output), str(folder/'status.txt')])
        began = time.monotonic()
        with (folder/f'{engine}.log').open('w') as log:
            try:
                process = subprocess.run(command, stdout=log, stderr=log, timeout=360,
                                         env={**os.environ, 'PATH':str(Path(FFMPEG).parent)+':'+os.environ['PATH']})
                status = process.returncode
            except subprocess.TimeoutExpired:
                status = 'timeout'
        row = dict(fixture=label, engine=engine, seconds=round(time.monotonic()-began, 2), exit=status, lines=len(reference))
        if status == 0 and output.exists():
            aligned = json.loads(output.read_text())
            errors = [abs(a['start']-r['start']) for a,r in zip(aligned,reference) if a.get('start') is not None]
            row.update(matched=len(errors), coverage=round(len(errors)/max(1,len(reference)),3),
                       median_error=round(statistics.median(errors),3) if errors else None,
                       within_1_second=sum(e<=1 for e in errors), max_error=round(max(errors),3) if errors else None)
        else:
            row['error_tail'] = (folder/f'{engine}.log').read_text(errors='replace')[-1400:]
        results.append(row)
        (WORK/'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
        print(json.dumps(row,ensure_ascii=False), flush=True)
