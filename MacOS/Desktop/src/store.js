import { useSyncExternalStore } from 'react';

// Clock samples have their own store: playback ticks never invalidate the catalog.
function store(initial) {
  let value = initial;
  const listeners = new Set();
  return { get: () => value, subscribe: listener => { listeners.add(listener); return () => listeners.delete(listener); },
    set: next => { value = next; for (const listener of listeners) listener(); } };
}
export const catalog = store([]);
export const state = store({ folders: [], favorites: [], recent: [], playlists: [], jobs: [], outputDevices: [], volume: 1, mode: 'list' });
export const clock = store({ time: 0, duration: 0, playing: false, sampledAt: performance.now() });
export const signals = new EventTarget();
export const useCatalog = () => useSyncExternalStore(catalog.subscribe, catalog.get);
export const usePlayback = () => useSyncExternalStore(state.subscribe, state.get);
export const useClock = () => useSyncExternalStore(clock.subscribe, clock.get);
export async function command(action, payload = {}) {
  try { return await window.miniVoice.command(action, payload); }
  catch (error) { signals.dispatchEvent(new CustomEvent('error', { detail: error.message })); throw error; }
}
window.miniVoice.subscribe(({ event, data }) => {
  if (event === 'catalog') catalog.set(data);
  else if (event === 'state') {
    // System output-device notifications can repeat identical values.
    const encoded = JSON.stringify(data);
    if (encoded !== state.lastEncoded) { state.lastEncoded = encoded; state.set(data); }
  }
  else if (event === 'clock') clock.set({ ...data, sampledAt: performance.now() });
  else signals.dispatchEvent(new CustomEvent(event, { detail: data }));
});
export {artwork} from './artworkUrl';
export const seconds = value => `${Math.floor((value || 0) / 60)}:${String(Math.floor((value || 0) % 60)).padStart(2, '0')}`;
