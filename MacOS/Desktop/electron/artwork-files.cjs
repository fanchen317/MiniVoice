const fs = require('node:fs');
const path = require('node:path');

function cachedArtworkFile(root, requestURL) {
  if (!root) return null;
  const url = new URL(requestURL), key = url.pathname.slice(1);
  if (url.protocol !== 'minivoice-art:' || !['cover', 'detail'].includes(url.hostname) || !/^[0-9a-f]{64}$/.test(key)) return null;
  // Pruning can evict any disposable size independently. A surviving detail
  // cover is still usable while the persistent browse cache is being rebuilt.
  const kinds = url.hostname === 'detail' ? ['Original', 'Detail', 'Browse', 'List'] : ['Browse', 'List', 'Detail'];
  return kinds.map(kind => path.join(root, 'Artwork', kind, key)).find(file => fs.existsSync(file)) || null;
}

module.exports = { cachedArtworkFile };
