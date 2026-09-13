import { defineConfig, devices } from '@playwright/test'

// =====================================================================
// Nettlesertestene.
//
// De maaler det de raske vaktene ikke kan naa: KONTRAST og
// TREFFOMRAADER krever layout, og layout krever en ekte nettleser.
// jsdom har ingen av delene, saa axe der slaar contrast-regelen av.
//
// CI starter en LOKAL Supabase og peker miljoet dit, saa de innloggede
// testene faar en ekte base. Uten et miljo faller vi tilbake paa dummy -
// da virker de aapne sidene, men ingenting bak innlogging.
// =====================================================================

// Ikke 3000. Den maskinen dette utvikles paa har andre dev-servere der,
// og en testkjoring som krasjer med dagens arbeid blir skrudd av.
const PORT = 3100

// Arver miljoet naar det er satt, og faller tilbake paa dummy bare naar
// det ikke er det.
//
// Foerste utgave hardkodet dummyverdiene her. Da overstyrte de
// workflowens peker mot den lokale Supabase-en, og serveren slo opp
// `dummy.supabase.co` - et domene som ikke finnes - ved HVERT
// auth-oppslag. De innloggede testene fikk aldri en oekt.
//
// Det forklarer ogsaa hvorfor kjoring #3 brukte 20 minutter og traff
// timeout: et DNS-slag som feiler tar sekunder paa en runner, ikke
// millisekunder, og det skjedde 53 ganger.
const env = {
  NEXT_PUBLIC_SUPABASE_URL:
    process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'https://dummy.supabase.co',
  NEXT_PUBLIC_SUPABASE_ANON_KEY:
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? 'dummy_anon_key_for_build_only',
  PORT: String(PORT),
}

export default defineConfig({
  testDir: './e2e',
  // Ingen retry. En flaky nettlesertest som «gaar over av seg selv» er
  // verre enn ingen - den laerer folk aa kjore paa nytt i stedet for aa
  // lese. Er den ustabil, skal den fikses eller fjernes.
  //
  // OG DET ER NAA EN FORUTSETNING, ikke bare en holdning: den muterende
  // maanedsplanflyten i `e2e/maanedsplan.spec.ts` bygger, slipper og
  // avviser ekte rader. En retry ville startet midt i den flyten paa en
  // halvt mutert base og latt som det var seedtilstanden.
  // `src/lib/redesign/e2e-oppsett.test.ts` feller en endring her.
  retries: 0,

  // =====================================================================
  // ÉN ARBEIDER, OG INGEN PARALLELLE FILER
  // =====================================================================
  //
  // Alle spec-filene deler ÉN database. `fullyParallel` er `false` som
  // standard, saa testene INNE i en fil gaar serielt - men FILENE gaar
  // i parallell over flere arbeidere, og det holdt ikke:
  //
  //   `maanedsplan.spec.ts` slipper Grenseby juli.
  //   `min-plan.spec.ts` leser butikksjefens liste.
  //
  // Kjoerer de samtidig, ser den andre en liste som endrer seg under
  // foettene paa den. Det er ikke flakiness man kan feilsoeke; det er to
  // tester som skriver i hverandres fikstur.
  //
  // Antallet var dessuten AVHENGIG AV MASKINEN: standarden er halvparten
  // av kjernene, saa en to-kjerners runner ga én arbeider og en
  // fire-kjerners ga to. Da ville en test bestaatt eller feilet av hvor
  // den kjoerte.
  //
  // Prisen er kjoeretid. Den er verdt aa betale for et svar man kan tro
  // paa.
  workers: 1,
  fullyParallel: false,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: 'retain-on-failure',
  },
  projects: [
    // OPPSETTET FORST. Eieren rulles inn i to-faktor en gang, og lagrer
    // en okt de andre gjenbruker. Uten dette steget logget fire
    // spec-filer inn hver for seg, og to arbeidere kunne rulle inn hver
    // sin faktor - da passet ikke hemmeligheten til faktoren sida
    // utfordret, og det saa ut som «feil engangskode».
    { name: 'oppsett', testMatch: /eier\.setup\.ts/, use: { ...devices['Desktop Chrome'] } },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['oppsett'],
    },
  ],

  webServer: {
    // Bygget kjores som eget steg i CI, og manuelt lokalt:
    //   npx next build --webpack   (--webpack kun paa win32/arm64)
    command: `npx next start -p ${PORT}`,
    url: `http://localhost:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env,
  },
})
