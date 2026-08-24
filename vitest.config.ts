import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'

// =====================================================================
// Vitest og Playwright deler filendelse, men ikke kjoretoy.
//
// Uten dette plukker vitest opp e2e/*.spec.ts og feiler med «Playwright
// Test did not expect test() to be called here». To testkjorere som
// slaas om de samme filene gir en rod suite som ikke handler om koden -
// og det er nettopp den slags roedt som laerer folk aa ignorere roedt.
//
// Konfigurasjonen er med vilje minimal. Alt annet - miljo per fil -
// settes i testfila der det trengs, saa oppsettet ikke blir et sted feil
// kan gjemme seg.
//
// De to aliasene under er unntaket, fordi de ikke kan settes per fil:
//
//   `@/*`         speiler `paths` i tsconfig.json. Uten den kan vitest
//                 ikke laste noe som importerer '@/...', og AI-laget
//                 gjor det. Holdes i takt med tsconfig manuelt - to
//                 kilder til samme sannhet er prisen for at Next og
//                 vitest ikke deler resolver.
//
//   `server-only` kaster paa import utenfor Next-bygget. Den finnes for
//                 aa vokte klientgrensa, og den grensa maales et annet
//                 sted (src/app/klientgrense.test.ts) - ikke her.
// =====================================================================

export default defineConfig({
  test: {
    exclude: ['e2e/**', 'node_modules/**', '.next/**'],
  },
  resolve: {
    alias: {
      'server-only': fileURLToPath(new URL('./src/lib/test/server-only-stub.ts', import.meta.url)),
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
