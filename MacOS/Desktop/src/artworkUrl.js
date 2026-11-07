export function artwork(track,detail=false,presentation='browse'){
  if(!track?.artworkKey)return '';
  // A failed request must get a fresh URL after the backend repairs the cache,
  // even when the embedded image's content key has not changed.
  return `minivoice-art://${detail?'detail':'cover'}/${track.artworkKey}?v=${track.artworkRevision??0}${detail?'&source=original-v1':''}${globalThis.miniVoice?.platform==='windows'&&!detail?'&size='+(presentation==='list'?'list':'browse')+'&preview=1':''}`;
}
