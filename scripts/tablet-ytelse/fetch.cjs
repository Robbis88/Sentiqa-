const fs = require('node:fs');
const original = globalThis.fetch;
globalThis.fetch = async function(input, init) {
  const url = typeof input === 'string' ? input : input.url ?? String(input);
  if (!url.startsWith('http://127.0.0.1:54321')) return original(input, init);
  const start = performance.now();
  await new Promise(r => setTimeout(r, Number(process.env.TABLET_MAALING_LATENS ?? 150)));
  try { return await original(input, init); }
  finally { fs.appendFileSync('.tablet-nettverk.ndjson', JSON.stringify({ path: new URL(url).pathname, ms: Math.round(performance.now() - start) }) + '\n'); }
};
