// Stubb for pakken `server-only` under vitest.
//
// Pakken finnes for aa kaste hvis en servermodul havner i klientbunten.
// Under enhetstest finnes ingen bunt aa havne i, og den ekte pakken
// kaster paa import. Vaktene maaler kilden, ikke kjoretoyet.
//
// At grensa faktisk holder maales et annet sted: `src/app/klientgrense.test.ts`.
export {}
