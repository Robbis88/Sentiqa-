import { defineConfig } from 'vitest/config'

// =====================================================================
// Vitest og Playwright deler filendelse, men ikke kjoretoy.
//
// Uten dette plukker vitest opp e2e/*.spec.ts og feiler med «Playwright
// Test did not expect test() to be called here». To testkjorere som
// slaas om de samme filene gir en rod suite som ikke handler om koden -
// og det er nettopp den slags roedt som laerer folk aa ignorere roedt.
//
// Konfigurasjonen er med vilje minimal. Alt annet - miljo per fil,
// aliaser - settes i testfila der det trengs, saa oppsettet ikke blir et
// sted feil kan gjemme seg.
// =====================================================================

export default defineConfig({
  test: {
    exclude: ['e2e/**', 'node_modules/**', '.next/**'],
  },
})
