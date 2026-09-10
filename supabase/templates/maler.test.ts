import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

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
    expect(RUTE).toContain("searchParams.get('token_hash')")
    expect(RUTE).toContain("searchParams.get('type')")
  })

  it('skiller en tom lenke fra en avvist lenke', () => {
    // Uten dette er en drifta mal i dashboardet ikke til å skille fra en
    // gammel lenke hos brukeren — og da leter man feil sted hver gang.
    expect(RUTE, 'ingen egen grunn for en lenke som ikke bar noe')
      .toContain("'ingen-token'")
  })

  it('hver type malene sender er en type ruta godtar', () => {
    // Ruta sender `type` rett inn i verifyOtp, så alle tre virker — men
    // `invite` og `signup` skal i tillegg gi «Velkommen» på /sett-passord.
    expect(RUTE).toContain("type === 'invite' || type === 'signup'")
  })
})
