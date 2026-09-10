import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { utenKommentarer } from '@/lib/redesign/design'

// =====================================================================
// MALENE OG RUTA MÅ SI DET SAMME
//
// Lenken i e-posten er den eneste delen av innloggingsflyten som ikke
// kjøres av oss. Supabase bygger den fra en mal i et dashboard, og
// `/auth/bekreft` leser den. Skiller de to lag, er symptomet en lenke
// som ser helt riktig ut og ikke gjør noe.
//
// DEN FARLIGE FORMEN ER STANDARDMALEN. `{{ .ConfirmationURL }}` sender
// tokenet i URL-fragmentet, og et fragment når aldri serveren. Ruta ser
// ingenting og kan ikke skille det fra en lenke som aldri ble sendt.
//
// Vakten kan ikke lese dashboardet — ingen test kan det. Den holder
// KOPIEN i repoet riktig, så det finnes noe å sammenligne med når
// lenken ikke virker. Kanarifuglen under er derfor viktigere enn vanlig:
// uten den ville en tom mappe vært like grønn som tre riktige maler.
// =====================================================================

const MAPPE = join(process.cwd(), 'supabase', 'templates')
const RUTE = readFileSync(
  join(process.cwd(), 'src', 'app', 'auth', 'bekreft', 'route.ts'), 'utf8')
/** Ruta sender en grunn; sida gir den tekst. To filer, én kontrakt. */
const SIDE = readFileSync(
  join(process.cwd(), 'src', 'app', 'logg-inn', 'page.tsx'), 'utf8')

// KOMMENTARENE STRIPPES FOER PAASTANDENE. Begge filene forklarer i
// klartekst hva koden under gjoer - blokken oeverst i ruta nevner alle
// tre grunnene ved navn. Uten strippingen ville vakten lest sin egen
// forklaring og staatt groenn paa en rute som ikke gjorde noe av det.
// Det skjedde med to andre vakter, se PR #251.
const KODE = utenKommentarer(RUTE)
const SIDEKODE = utenKommentarer(SIDE)

const maler = readdirSync(MAPPE)
  .filter((f) => f.endsWith('.html'))
  .map((f) => ({ navn: f, html: readFileSync(join(MAPPE, f), 'utf8') }))

/** Ærendet hver mal sender, og navnet Supabase gir malen i dashboardet. */
const AERENDER: Record<string, string> = {
  'invitasjon.html': 'invite',
  'gjenoppretting.html': 'recovery',
  'bekreft-registrering.html': 'signup',
}

describe('e-postmalene', () => {
  it('KANARIFUGL: malene finnes og blir lest', () => {
    expect(maler.length, 'fant ingen maler — da måler denne vakten ingenting')
      .toBe(Object.keys(AERENDER).length)
    for (const { navn, html } of maler) {
      expect(html.length, `${navn} er tom`).toBeGreaterThan(400)
    }
  })

  it('hver mal har et ærend vi kjenner', () => {
    // En fil som ikke står i tabellen blir ikke sjekket av testene under,
    // og en umålt mal ser ut som en riktig mal.
    for (const { navn } of maler) {
      expect(AERENDER[navn], `${navn} står ikke i AERENDER`).toBeDefined()
    }
  })

  it('bærer tokenet i spørrestrengen, ikke i et fragment', () => {
    for (const { navn, html } of maler) {
      expect(html, `${navn} bruker ikke token_hash`).toContain('token_hash={{ .TokenHash }}')
      expect(html, `${navn} bruker standardmalens ConfirmationURL — den sender `
        + 'tokenet i fragmentet, og et fragment når aldri serveren')
        .not.toContain('ConfirmationURL')
      expect(html, `${navn} har ingen # i lenken`).not.toMatch(/href="[^"]*#/)
    }
  })

  it('peker på ruta som faktisk finnes', () => {
    for (const { navn, html } of maler) {
      expect(html, `${navn} peker et annet sted enn /auth/bekreft`).toContain('/auth/bekreft?')
    }
  })

  it('sender riktig type for sitt ærend', () => {
    // Feil `type` gir «Token has expired or is invalid» på et helt ferskt
    // token — en feilmelding som peker rett vekk fra årsaken.
    for (const { navn, html } of maler) {
      expect(html, `${navn} mangler type=${AERENDER[navn]}`)
        .toContain(`type=${AERENDER[navn]}`)
    }
  })

  it('bruker prosjektets faste adresse, ikke den som ba om lenken', () => {
    // `.RedirectTo` bygges av koden fra Host-headeren. Kjøres handlingen
    // fra en preview-deploy, sender vi en lenke inn i previewen.
    for (const { navn, html } of maler) {
      expect(html, `${navn} bruker RedirectTo`).not.toContain('.RedirectTo')
      expect(html, `${navn} bruker ikke SiteURL`).toContain('{{ .SiteURL }}')
    }
  })
})

describe('ruta tar imot det malene sender', () => {
  it('leser token_hash og type fra spørrestrengen', () => {
    expect(KODE).toContain("searchParams.get('token_hash')")
    expect(KODE).toContain("searchParams.get('type')")
  })

  it('skiller en tom lenke fra en avvist lenke', () => {
    // Uten dette er en drifta mal i dashboardet ikke til å skille fra en
    // gammel lenke hos brukeren — og da leter man feil sted hver gang.
    expect(KODE, 'ingen egen grunn for en lenke som ikke bar noe')
      .toContain("'ingen-token'")
  })

  it('krever en SESJON, ikke bare fravær av feil', () => {
    // =================================================================
    // «INGEN FEIL» ER IKKE «INNLOGGET»
    //
    // `verifyOtp` POSTer til /verify og leser sesjonen ut av svaret.
    // Mangler den, kaster den ikke — den returnerer
    // `{ user: null, session: null, error: null }`. Cookien skrives bare
    // når det finnes et `access_token`.
    //
    // Uten denne sjekken sendes brukeren til /sett-passord UTEN sesjon,
    // og møter «Lenken er utløpt eller allerede brukt» på en lenke som
    // var fersk og ble godtatt. Hun ber om en ny, får samme svar, og
    // leter etter et problem som ikke finnes.
    // =================================================================
    for (const kall of ['verifyOtp', 'exchangeCodeForSession']) {
      const i = KODE.indexOf(kall)
      expect(i, `fant ikke ${kall} i ruta`).toBeGreaterThan(-1)
      const etter = KODE.slice(i, i + 400)
      expect(etter, `${kall} sender videre på fravær av feil alene`)
        .toContain('data.session?.access_token')
    }
  })

  it('en godtatt lenke uten sesjon har sin EGEN grunn', () => {
    // Faller den sammen med «invitasjon», er vår oppsettsfeil ikke til å
    // skille fra hennes gamle lenke — og de to krever motsatt handling.
    expect(KODE).toContain('feil=ingen-sesjon')
    expect(SIDEKODE, 'ruta sender en grunn sida ikke har tekst for')
      .toContain("'ingen-sesjon':")
  })

  it('KANARIFUGL: hver grunn ruta sender har en tekst på innloggingssida', () => {
    // En grunn uten tekst gir en tom `<p role="alert">` — altså en side
    // som ser helt normal ut etter en feilet lenke. Dette er stedet den
    // ville oppstått: to filer, og bare den ene endres.
    //
    // Grunnene staar to steder i ruta: direkte i `feil=<navn>`, og som de
    // to armene i `const grunn = … ? '…' : '…'`. Begge maa leses, ellers
    // maaler vakten bare halve kontrakten.
    const grunner = new Set<string>()
    for (const m of KODE.matchAll(/feil=([a-z-]+)/g)) grunner.add(m[1])
    // `[^\n]*` og ikke `.*` — se CRLF-fella i redesign/design.ts.
    const ternar = /const grunn =[^\n]*\?\s*'([a-z-]+)'\s*:\s*'([a-z-]+)'/.exec(KODE)
    expect(ternar, 'fant ikke ternaeren som velger grunn').not.toBeNull()
    grunner.add(ternar![1])
    grunner.add(ternar![2])

    expect(grunner.size, 'fant faerre grunner enn ruta har — maaler denne noe?')
      .toBeGreaterThanOrEqual(3)
    for (const g of grunner) {
      // Noekkelen staar sitert naar den har bindestrek (`'ingen-token':`)
      // og usitert naar den ikke har det (`invitasjon:`). Begge er samme
      // noekkel; en vakt som bare godtok den ene ville krevd en stilregel
      // den ikke har noe med.
      expect(SIDEKODE, `ruta sender feil=${g}, men sida har ingen tekst for den`)
        .toMatch(new RegExp(`'?${g}'?\\s*:`))
    }
  })

  it('hver type malene sender er en type ruta godtar', () => {
    // Ruta sender `type` rett inn i verifyOtp, så alle tre virker — men
    // `invite` og `signup` skal i tillegg gi «Velkommen» på /sett-passord.
    expect(KODE).toContain("type === 'invite' || type === 'signup'")
  })
})
