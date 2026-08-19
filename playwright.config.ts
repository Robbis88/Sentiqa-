import { defineConfig, devices } from '@playwright/test'

// =====================================================================
// Nettlesertestene.
//
// De maaler det de raske vaktene ikke kan naa: KONTRAST og
// TREFFOMRAADER krever layout, og layout krever en ekte nettleser.
// jsdom har ingen av delene, saa axe der slaar contrast-regelen av.
//
// Kjorer UTEN database. Dummy-nokler er nok fordi hver side er dynamisk
// og ingenting spor Supabase paa byggtid. Det betyr ogsaa at alt bak
// innlogging er utilgjengelig her - se e2e/README for hva som mangler.
// =====================================================================

// Ikke 3000. Den maskinen dette utvikles paa har andre dev-servere der,
// og en testkjoring som krasjer med dagens arbeid blir skrudd av.
const PORT = 3100

const DUMMY = {
  NEXT_PUBLIC_SUPABASE_URL: 'https://dummy.supabase.co',
  NEXT_PUBLIC_SUPABASE_ANON_KEY: 'dummy_anon_key_for_build_only',
  PORT: String(PORT),
}

export default defineConfig({
  testDir: './e2e',
  // Ingen retry. En flaky nettlesertest som «gaar over av seg selv» er
  // verre enn ingen - den laerer folk aa kjore paa nytt i stedet for aa
  // lese. Er den ustabil, skal den fikses eller fjernes.
  retries: 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],

  webServer: {
    // Bygget kjores som eget steg i CI, og manuelt lokalt:
    //   npx next build --webpack   (--webpack kun paa win32/arm64)
    command: `npx next start -p ${PORT}`,
    url: `http://localhost:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: DUMMY,
  },
})
