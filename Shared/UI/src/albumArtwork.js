export const albumKey=value=>String(value||'').trim().toLowerCase();
export function albumArtworkTracks(tracks,album){const key=albumKey(album);return !key||key==='未知专辑'?[]:tracks.filter(track=>albumKey(track.album)===key);}
