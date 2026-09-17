const fs = require('node:fs');
const { createServerClient } = require('@supabase/ssr');
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE2NDE3NjkyMDAsImV4cCI6MTc5OTUzNTYwMH0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GQ';
(async () => {
  let cookies = [];
  const client = createServerClient('http://127.0.0.1:54321', key, { cookies: { getAll: () => cookies, setAll: values => { cookies = values; } } });
  const { error } = await client.auth.signInWithPassword({ email: 'nettbrett-analyse@test.sentiqa.no', password: 'test-nettbrett-analyse-2026' });
  if (error) throw error;
  const header = cookies.map(c => `${c.name}=${c.value}`).join('; ');
  const rows = () => fs.existsSync('.tablet-nettverk.ndjson') ? fs.readFileSync('.tablet-nettverk.ndjson', 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) : [];
  const results = [];
  for (const path of ['/oversikt', '/rutiner']) {
    for (let n = 0; n < 4; n++) {
      const before = rows().length;
      const start = performance.now();
      const response = await fetch(`http://localhost:3100${path}`, { headers: { cookie: header }, redirect: 'manual' });
      const body = await response.text();
      if (response.status !== 200 || !body.includes('tablet-nav')) throw new Error(`Ugyldig maaling ${path}: ${response.status}`);
      const calls = rows().slice(before);
      results.push({ path, sample: n, ms: Math.round(performance.now() - start), calls: calls.length, perPath: calls.reduce((a, r) => { a[r.path] = (a[r.path] ?? 0) + 1; return a; }, {}) });
    }
  }
  fs.writeFileSync(process.argv[2] ?? '.tablet-foer.json', JSON.stringify({ latencyMs: 150, results }, null, 2));
  console.log(JSON.stringify(results.map(({ path, sample, ms, calls }) => ({ path, sample, ms, calls }))));
})().catch(e => { console.error(e.message); process.exitCode = 1; });
