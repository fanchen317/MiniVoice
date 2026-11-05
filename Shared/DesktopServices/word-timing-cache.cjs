const fs = require('node:fs/promises');
const syncFS = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const VERSION = 'audio-word-cache-v1';
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const sungText = text => String(text || '').normalize('NFC').replace(/[\p{P}\p{Z}\s]/gu, '');
const lyricHash = song => hash(String(song?.lyrics || ''));
const stamp = stat => ({size: stat.size, modified: stat.mtimeMs, changed: stat.ctimeMs});
const sameStamp = (a, b) => a && b && a.size === b.size && a.modified === b.modified && a.changed === b.changed;
const lineTime = line => Number.isFinite(line.ms) ? line.ms / 1000 : line.time;
const hasWords = line => Array.isArray(line.words) && line.words.length > 0;
const voicedLines = song => (song.lines || []).filter(line => sungText(line.text));
const nativeWordsComplete = song => {
  const rows = voicedLines(song);
  return rows.length > 0 && rows.every(hasWords);
};

function normalizeLines(parsed) {
  if (!Array.isArray(parsed)) throw Error('逐字缓存返回了无效歌词');
  return parsed.map(line => ({...line, time: lineTime(line), words: (line.words || []).map(word => ({
    text: String(word.text || ''),
    start: Number.isFinite(word.ms) ? word.ms / 1000 : word.start,
    end: Number.isFinite(word.endMs) && word.endMs >= 0 ? word.endMs / 1000 : word.end,
  }))}));
}

// Coverage measures the proportion of original written text with validated audio
// timestamps. It is deliberately not an estimate of temporal alignment accuracy.
function validatedLines(song, parsed) {
  const original = song.lines || [];
  const rows = normalizeLines(parsed);
  const byTimeAndText = new Map(rows.map(line => [JSON.stringify([line.time, line.text]), line]));
  let total = 0, covered = 0;
  const lines = original.map((line, index) => {
    const count = [...sungText(line.text)].length;
    total += count;
    // Never overwrite genuine source words, even if a model produces more words.
    if (hasWords(line)) { covered += count; return line; }
    const start = lineTime(line);
    const next = original.slice(index + 1).map(lineTime).find(time => Number.isFinite(time) && time > start);
    const end = Number.isFinite(next) ? next : song.duration;
    const candidate = byTimeAndText.get(JSON.stringify([start, line.text]));
    if (!count || !Number.isFinite(start) || start < 0 || !candidate?.words?.length || sungText(candidate.words.map(word => word.text).join('')) !== sungText(line.text)) return line;
    let previous = start;
    const valid = candidate.words.every(word => {
      const last = Number.isFinite(word.end) ? word.end : word.start;
      const okay = Number.isFinite(word.start) && word.start >= previous && word.start >= start - .001 && Number.isFinite(word.end) && last >= word.start && (!sungText(word.text) || last > word.start) && (!Number.isFinite(end) || last <= end + .001);
      previous = last;
      return okay;
    });
    if (!valid) return line;
    covered += count;
    return {...line, words: candidate.words, timingSource: 'audioAligned'};
  });
  return {lines, quality: {wordCoverage: total ? covered / total : 0, coveredCharacters: covered, totalCharacters: total}};
}

function wordTimingCache({directory, command, onUpdate = () => {}, onStatus = () => {}, enabled = true,
  maxMemory = 128, retryMs = 60 * 60 * 1000, settingsRetryMs = 60 * 1000, idleDelayMs = 1000,
  minimumCoverage = .9, pipelineVersion = VERSION} = {}) {
  if (typeof directory !== 'string' || typeof command !== 'function') throw Error('逐字缓存需要缓存目录和宿主命令');
  const root = path.join(directory, 'WordTimings-v1');
  const memory = new Map(), generations = new Map(), attempts = new Map(), known = new Map();
  const queue = [], queued = new Set(), waiters = new Set();
  let state = {}, observed = false, stopped = false, running = false, scheduled = null, activeID = null;
  let settings = null, settingsUntil = 0, settingsSignature = '', wasImporting = false;
  let completed = 0, failed = 0, hits = 0;
  const notify = callback => { try { const result = callback(); result?.catch?.(() => {}); } catch {} };
  const status = (phase, extra = {}) => notify(() => onStatus({phase, pending: queue.length, activeID, completed, failed, hits, ...extra}));
  const generation = id => generations.get(id) || 0;
  const usable = () => observed && !stopped && enabled && state.wordTimingCacheEnabled !== false;
  const busy = () => state.importing || state.scanning || state.fileWriteID || state.tasks?.downloadingModel || (state.jobs || []).some(job => !job.finished && job.purpose !== 'wordTimingCache');
  const wake = () => { if (!running && !scheduled) { for (const resolve of waiters) resolve(); waiters.clear(); } };
  const enqueue = id => { if (known.has(id) && !queued.has(id)) { queued.add(id); queue.push(id); } };
  function paused(id, revision) {
    if (usable() && !busy() && known.has(id) && revision === generation(id)) return false;
    if (!stopped && known.has(id)) { attempts.delete(id); enqueue(id); }
    return true;
  }
  function prioritize(id) { const index = queue.indexOf(id); if (index > 0) queue.unshift(queue.splice(index, 1)[0]); }
  function schedule() {
    if (!usable() || busy() || running || scheduled || !queue.length || (!settings && settingsUntil > Date.now())) { wake(); return; }
    scheduled = setTimeout(() => { scheduled = null; void run(); }, Math.max(0, idleDelayMs));
  }
  function invalidate(id) {
    id = String(id); generations.set(id, generation(id) + 1); memory.delete(id); attempts.delete(id);
    enqueue(id); schedule();
  }
  function remember(id, entry) {
    memory.delete(id); memory.set(id, entry);
    while (memory.size > Math.max(1, maxMemory)) memory.delete(memory.keys().next().value);
  }
  const slot = song => path.join(root, hash(JSON.stringify([String(song.id), song.path])) + '.json');
  function fingerprint(song, fileStamp, model) { return hash(JSON.stringify({version: pipelineVersion, path: song.path, stamp: fileStamp, source: lyricHash(song), model})); }
  async function modelSettings() {
    if (Date.now() < settingsUntil) return settings;
    settingsUntil = Date.now() + settingsRetryMs;
    try {
      const value = await command('desktopSettings', {});
      const model = value?.lyricsModel || 'small';
      const entry = value?.models?.find(item => item.id === model);
      settings = {model, available: Boolean(entry && (entry.installed || entry.bundled))};
    } catch { settings = {model: state.preferences?.lyricsModel || state.lyricsModel || 'small', available: false}; }
    return settings;
  }
  async function currentSong(id) {
    const song = await command('detail', {id});
    if (!song || String(song.id) !== id || typeof song.path !== 'string' || typeof song.lyrics !== 'string') throw Error('歌曲或歌词已不可用');
    return song;
  }
  async function saveEntry(song, entry, current) {
    await fs.mkdir(root, {recursive: true});
    if (!current()) return false;
    const temporary = slot(song) + '.' + crypto.randomUUID() + '.tmp';
    try {
      await fs.writeFile(temporary, JSON.stringify(entry), {flag: 'wx', mode: 0o600});
      if (!current()) return false;
      await fs.rename(temporary, slot(song));
      // A disable/save may arrive while the filesystem is committing the rename.
      // Remove this late commit so re-enabling cannot load an abandoned result.
      if (!current()) { await fs.rm(slot(song), {force: true}); return false; }
      return true;
    }
    finally { await fs.rm(temporary, {force: true}); }
  }
  function eligible(song) {
    const rows = voicedLines(song);
    return Boolean(rows.length && rows.every(line => Number.isFinite(lineTime(line)) && lineTime(line) >= 0) && !nativeWordsComplete(song));
  }
  async function processSong(id, model, modelAvailable) {
    const revision = generation(id), song = await currentSong(id);
    if (paused(id, revision)) return;
    if (!eligible(song)) return;
    const sourceHash = lyricHash(song), fileStamp = stamp(await fs.stat(song.path));
    if (paused(id, revision)) return;
    const key = fingerprint(song, fileStamp, model);
    if (memory.get(id)?.fingerprint === key) return;
    const attempted = attempts.get(id);
    if (attempted?.key === key && attempted.until > Date.now()) return;
    try {
      const cached = JSON.parse(await fs.readFile(slot(song), 'utf8'));
      if (paused(id, revision)) return;
      if (cached.version === pipelineVersion && cached.fingerprint === key && cached.path === song.path && cached.sourceHash === sourceHash && sameStamp(cached.stamp, fileStamp) && cached.timingSource === 'audioAligned' && cached.quality?.wordCoverage >= minimumCoverage) {
        const checked = validatedLines(song, cached.lines);
        if (checked.quality.wordCoverage >= minimumCoverage) {
          const latest = await currentSong(id);
          if (paused(id, revision)) return;
          const latestStamp = stamp(await fs.stat(latest.path));
          if (paused(id, revision)) return;
          if (latest.path !== song.path || lyricHash(latest) !== sourceHash || !sameStamp(latestStamp, fileStamp)) { invalidate(id); return; }
          remember(id, {...cached, lines: checked.lines}); hits++; notify(onUpdate);
          return;
        }
      }
    } catch (error) {
      if (paused(id, revision)) return;
      if (!['ENOENT', 'SyntaxError'].includes(error.code || error.name)) status('cacheMiss', {id, message: '缓存不可读，将重新分析'});
    }
    if (!modelAvailable) { attempts.set(id, {key, until: settingsUntil, missingModel: true}); return; }
    if (paused(id, revision)) return;
    attempts.set(id, {key, until: Date.now() + retryMs});
    status('analyzing', {id, title: song.title});
    const aligned = await command('analyzeWordTiming', {id, source: song.lyrics});
    if (paused(id, revision)) return;
    if (aligned?.timingSource !== 'audioAligned' || typeof aligned.lyrics !== 'string') throw Error('宿主没有返回音频对齐的逐字时间轴');
    const parsed = await command('sharedCore', {op: 'lyrics.parse', raw: aligned.lyrics});
    if (paused(id, revision)) return;
    const checked = validatedLines(song, parsed);
    if (checked.quality.wordCoverage < minimumCoverage) { failed++; status('needsReview', {id, quality: checked.quality, message: '逐字时间覆盖不足，保留原逐行歌词'}); return; }
    // A save/import/online replacement can happen while inference is running.
    // Validate both textual source and file identity again before publishing.
    const latest = await currentSong(id);
    if (paused(id, revision)) return;
    const latestStamp = stamp(await fs.stat(latest.path));
    if (paused(id, revision)) return;
    if (revision !== generation(id) || latest.path !== song.path || lyricHash(latest) !== sourceHash || !sameStamp(latestStamp, fileStamp) || settings?.model !== model) {
      invalidate(id); return;
    }
    const entry = {version: pipelineVersion, fingerprint: key, path: song.path, sourceHash, stamp: fileStamp, model,
      timingSource: 'audioAligned', lines: checked.lines, quality: checked.quality};
    if (!await saveEntry(song, entry, () => !paused(id, revision)) || paused(id, revision)) return;
    remember(id, entry); completed++; status('ready', {id, quality: checked.quality}); notify(onUpdate);
  }
  async function run() {
    if (running || !usable() || busy() || !queue.length) { wake(); return; }
    running = true;
    try {
      const model = await modelSettings();
      if (!usable() || busy()) return;
      if (!model.available) status('waitingForModel', {message: '已有逐字缓存仍可使用；安装所选模型后可生成新缓存'});
      while (usable() && !busy() && queue.length) {
        const id = queue.shift(); queued.delete(id); if (!known.has(id)) continue;
        activeID = id;
        const revision = generation(id);
        try { await processSong(id, model.model, model.available); }
        catch (error) { if (!paused(id, revision)) { failed++; status('failed', {id, message: error.message}); } }
        activeID = null;
        // Yield the host event loop between tracks; playback commands stay live.
        await new Promise(resolve => setImmediate(resolve));
      }
    } finally { running = false; activeID = null; if (!queue.length) status('idle'); wake(); }
  }
  return {
    catalog(rows) {
      const next = new Map((Array.isArray(rows) ? rows : []).filter(row => row && row.id != null).map(row => [String(row.id), row]));
      for (const id of known.keys()) if (!next.has(id)) { generations.set(id, generation(id) + 1); memory.delete(id); attempts.delete(id); }
      for (const [id, row] of next) {
        const previous = known.get(id);
        if (!previous || previous.path !== row.path || previous.modified !== row.modified || previous.size !== row.size) {
          generations.set(id, generation(id) + 1); memory.delete(id); attempts.delete(id); enqueue(id);
        }
      }
      known.clear(); for (const [id, row] of next) known.set(id, row);
      for (const id of next.keys()) enqueue(id);
      schedule();
    },
    observe(next) {
      const wasUsable = usable();
      state = next || {}; observed = true;
      if (wasUsable && !usable()) {
        if (scheduled) clearTimeout(scheduled);
        scheduled = null;
        // Even a disable/re-enable within one await permanently abandons that run.
        if (activeID != null) { generations.set(activeID, generation(activeID) + 1); attempts.delete(activeID); enqueue(activeID); }
      }
      const signature = JSON.stringify([state.lyricsModel, state.preferences?.lyricsModel, state.tasks?.downloadingModel, state.tasks?.modelStatus]);
      if (signature !== settingsSignature) { settingsSignature = signature; settingsUntil = 0; for (const [id, attempt] of attempts) if (attempt.missingModel) { attempts.delete(id); enqueue(id); } }
      if (wasImporting && !state.importing) for (const id of known.keys()) enqueue(id);
      wasImporting = Boolean(state.importing);
      prioritize(String(state.playing?.id ?? state.current ?? '')); prioritize(String(state.selected?.id ?? ''));
      schedule();
    },
    decorate(next) {
      if (!usable()) return next;
      let changed = false;
      const output = {...next};
      for (const key of ['playing', 'selected']) {
        const song = next?.[key], id = song?.id == null ? '' : String(song.id), cached = memory.get(id);
        if (!song || !cached || !known.has(id) || nativeWordsComplete(song)) continue;
        const requestedModel = state.preferences?.lyricsModel || state.lyricsModel || settings?.model;
        let matches = cached.path === song.path && cached.sourceHash === lyricHash(song) && (!requestedModel || cached.model === requestedModel);
        if (matches) { try { matches = sameStamp(cached.stamp, stamp(syncFS.statSync(song.path))); } catch { matches = false; } }
        if (!matches) { invalidate(id); continue; }
        const checked = validatedLines(song, cached.lines);
        if (checked.quality.wordCoverage < minimumCoverage) { invalidate(id); continue; }
        output[key] = {...song, lines: checked.lines, wordTiming: {source: 'audioAligned', quality: cached.quality, cacheVersion: pipelineVersion}};
        changed = true;
      }
      return changed ? output : next;
    },
    invalidate,
    stop() { stopped = true; if (scheduled) clearTimeout(scheduled); scheduled = null; queue.length = 0; queued.clear(); wake(); },
    whenIdle() { if (!running && !scheduled) return Promise.resolve(); return new Promise(resolve => waiters.add(resolve)); },
  };
}
module.exports = {wordTimingCache};
