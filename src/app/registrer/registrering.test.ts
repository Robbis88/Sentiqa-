import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// =====================================================================
// PORTEN PÅ SELVBETJENT REGISTRERING
//
// `/registrer` var åpen: hvem som helst kunne opprette en kjede med seg
// selv som `retailer_admin`, live i samme sekund. Isolasjonen holdt —
// RLS gir dem bare sin egen tomme kjede — så det var aldri en lekkasje.
// Det var fire åpninger, og alle fire er lukket nå.
//
// DENNE TESTEN LESER KILDEN, IKKE OPPFØRSELEN. Handlingen snakker med
// Supabase Auth og med basen; å teste den ekte veien ville krevd begge.
// Men de tre farligste regresjonene er synlige i teksten, og hver av
// dem ville gjenåpnet et hull uten at noe annet ble rødt:
//
//   `email_confirm: true`   markerer adressen som bekreftet uten å
//                           sende noe. Da kan man registrere seg på en
//                           adresse man ikke eier — og «glemt passord»
//                           går til den ekte eieren.
//   `signInWithPassword`    logger inn en søker vi ikke har godkjent,
//                           og som vi ikke har bevist eier adressen.
//   `godkjent_tid`          settes den ved registrering, er porten borte.
//
// Samme form som rollevakten i `src/lib/redesign`: en regel skrevet ned
// som en påstand, med en kanarifugl som feller den hvis den slutter å
// lese.
// =====================================================================

const KILDE = readFileSync(join(__dirname, 'handlinger.ts'), 'utf8')

/** Kildeteksten uten kommentarer — de forklarer nettopp det forbudte. */
const kode = KILDE
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .split(/\r?\n/)
  .filter((l) => !/^\s*(\/\/|\*|\/\*)/.test(l))
  .join('\n')

describe('registreringen har en port', () => {
  it('markerer aldri e-posten som bekreftet selv', () => {
    expect(kode).not.toMatch(/email_confirm/)
  })

  it('bruker invitasjonsveien, som beviser at adressen er ekte', () => {
    expect(kode).toMatch(/inviteUserByEmail/)
    expect(kode).toMatch(/auth\/bekreft/)
  })

  it('logger ikke søkeren inn', () => {
    expect(kode).not.toMatch(/signInWithPassword/)
    expect(kode).not.toMatch(/redirect\(/)
  })

  it('tar ikke imot et passord', () => {
    // Passordet settes bak lenken i e-posten. Tar skjemaet det her, er
    // vi tilbake til en konto som finnes før adressen er bevist.
    // Ordet «passord» star i kvitteringsteksten - «apne lenken for a
    // sette passord» - saa paastanden ma vaere om FELTET, ikke om ordet.
    expect(kode).not.toMatch(/formData\.get\('passord'\)/)
    expect(kode).not.toMatch(/password:/)
    const skjema = readFileSync(join(__dirname, 'skjema.tsx'), 'utf8')
    expect(skjema).not.toMatch(/type="password"/)
  })

  it('setter aldri godkjent_tid — det er et menneskes klikk', () => {
    expect(kode).not.toMatch(/godkjent_tid/)
  })

  it('teller forsøket før noe opprettes', () => {
    const teller = kode.indexOf('registrering_forsok')
    const kjede = kode.indexOf("from('retailers')")
    expect(teller).toBeGreaterThan(-1)
    expect(kjede).toBeGreaterThan(-1)
    expect(teller).toBeLessThan(kjede)
  })

  // =================================================================
  // KANARIFUGL
  //
  // En vakt som leser feil fil, eller en `kode` som filtrerer bort alt,
  // ville bestått hver påstand over uten å se en linje. Det er samme
  // form som RLS-vakthunden som var grønn i månedsvis fordi den
  // forutsatte at det fantes policyer å vurdere.
  // =================================================================
  it('leser faktisk handlingen', () => {
    expect(kode.length).toBeGreaterThan(1000)
    expect(kode).toMatch(/export async function registrer/)
    expect(kode).toMatch(/retailer_admin/)
  })

  it('ville sett et forbudt mønster om det kom tilbake', () => {
    const injisert = `${kode}\nconst x = { email_confirm: true }`
    expect(injisert).toMatch(/email_confirm/)
  })
})

describe('DAL-en stenger en ugodkjent kjede ute', () => {
  // PORTEN LIGGER I DAL-EN, IKKE I `(beskyttet)/layout.tsx`. En rute
  // utenfor det treet som kaller `hentInnloggetBruker` ville ellers vært
  // en vei rundt — og `/sikkerhet` er nettopp en slik rute.
  const dal = readFileSync(
    join(__dirname, '..', '..', 'lib', 'auth', 'dal.ts'), 'utf8',
  )

  it('sender en ugodkjent kjede til ventesida', () => {
    expect(dal).toMatch(/godkjent_tid/)
    expect(dal).toMatch(/venter-paa-godkjenning/)
  })

  it('holder plattformredaktøren utenfor — hun har ingen kjede å vente på', () => {
    expect(dal).toMatch(/plattform_redaktor/)
  })
})
