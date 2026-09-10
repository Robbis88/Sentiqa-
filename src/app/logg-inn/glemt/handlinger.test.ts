import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
// Felleshjelperen, ikke en lokal kopi. Den lokale var en regex, og en
// regex kan ikke strippe en `//`-kommentar som slutter med CRLF: `.`
// matcher ikke `\r`, så `.*$` når aldri slutten av linja. Vakten var
// derfor grønn i CI (LF) og rød hos Robert (CRLF) — på samme kode.
import { utenKommentarer } from '@/lib/redesign/design'

// =====================================================================
// «GLEMT PASSORD?» ER EN ÅPEN DØR SOM IKKE SKAL VÆRE ET OPPSLAGSVERK
//
// Sida står utenfor innlogging. Hvem som helst kan skrive inn hvilken
// som helst adresse og se hva vi svarer. Sier vi «vi kjenner ikke den
// adressen», har vi laget et gratis søk over hvem som har konto hos oss
// — og adressene er navn@kjede.no, altså hvem som jobber hvor.
//
// Innloggingen selv er allerede bevisst generisk («Feil e-post eller
// passord»). Denne må være det samme, ellers er den generiske meldingen
// der borte verdiløs: man spør bare her i stedet.
//
// DEN ANDRE HALVDELEN: «SENDT» ER IKKE «KOM FRAM».
// Supabase Auth sender disse gjennom sin egen SMTP, ikke gjennom Resend.
// Er den ikke satt opp, går alt her grønt og ingenting kommer fram — og
// den som venter har ingen måte å vite forskjellen på. Derfor skal
// kvitteringen si hva man gjør når det ikke skjer.
//
// Vakten leser kilden. Den kan ikke kjøre handlingen — den snakker med
// Supabase — men begge reglene står i teksten, og begge er stille når de
// forsvinner.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', 'logg-inn', 'glemt', 'handlinger.ts'), 'utf8')
const SKJEMA = readFileSync(
  join(process.cwd(), 'src', 'app', 'logg-inn', 'glemt', 'skjema.tsx'), 'utf8')
const INNLOGGING = readFileSync(
  join(process.cwd(), 'src', 'app', 'logg-inn', 'skjema.tsx'), 'utf8')

const kode = utenKommentarer(KILDE)

describe('sendGlemtLenke', () => {
  it('KANARIFUGL: vakten leser faktisk handlingen', () => {
    expect(kode.length, 'fant ikke handlingen').toBeGreaterThan(400)
    expect(kode, 'fant ikke selve utsendingen').toContain('resetPasswordForEmail')
  })

  it('lander i den flyten som allerede finnes', () => {
    // /auth/bekreft → /sett-passord. En egen landingsside til ville vært
    // en andre halvdel av samme flyt, og de to ville skilt lag.
    expect(kode).toContain('/auth/bekreft')
  })

  it('avslører ikke om adressen finnes', () => {
    // Svaret skal være det samme uansett. Regelen er lett å bryte med
    // velmenende hjelpsomhet: «fant ingen bruker med den adressen».
    expect(kode, 'et oppslag på om brukeren finnes hører ikke hjemme her')
      .not.toContain("from('profiler')")
    expect(kode).not.toMatch(/finnes ikke|ukjent adresse|ingen bruker/i)
  })

  it('den vellykkede kvitteringen er betinget, ikke bekreftende', () => {
    // «Lenke sendt til X» påstår at X finnes. «Er X registrert hos oss …»
    // sier nøyaktig like mye til den som eier adressen, og ingenting til
    // den som gjetter.
    expect(kode, 'kvitteringen bekrefter at adressen finnes').toMatch(/ok: `Er \$\{felt\.data\.epost\}/)
  })

  it('sier hva man gjør når e-posten ikke kommer', () => {
    // SMTP er den vanlige årsaken og den er usynlig herfra. Uten denne
    // setningen står den som venter og venter på noe som aldri skjer.
    expect(kode, 'ingen utvei nevnt når e-posten uteblir').toMatch(/eieren av kjeden/)
  })

  it('den ekte grunnen logges, selv om brukeren ikke får se den', () => {
    // Den generiske teksten skjuler noe for en fremmed. Uten en logg
    // skjuler den det for OSS også — og da står man med «klarte ikke
    // sende» og ingen måte å vite om det er ratebegrensning, feil
    // SMTP-passord eller en redirect-URL utenfor lista. Det skjedde
    // første gang dette ble prøvd i drift.
    expect(kode, 'feilen fra Supabase forsvinner uten spor')
      .toContain('console.error')
    expect(kode, 'meldingen fra Supabase må være med i loggen')
      .toContain('error.message')
  })

  it('loggen inneholder ikke adressen', () => {
    // Loggen er stedet vi IKKE vil bekrefte at en adresse finnes — den
    // leses av flere enn den som eier postkassen.
    const logg = kode.slice(kode.indexOf('console.error'), kode.indexOf('return {', kode.indexOf('console.error')))
    expect(logg, 'adressen havner i loggen').not.toContain('felt.data.epost')
  })

  it('feilen skiller ikke på om adressen finnes', () => {
    // Supabase svarer med feil på ratebegrensning og oppsett, ikke på
    // ukjent adresse. Teksten skal derfor handle om sendingen.
    expect(kode).toMatch(/feil: 'Klarte ikke sende/)
  })
})

describe('veien inn til sida', () => {
  it('innloggingssida lenker hit', () => {
    // En glemt-passord-side ingen finner er ingen glemt-passord-side.
    // Dette er nøyaktig hullet som var her før: mekanismen fantes i
    // /plattform, men bare plattformeieren kunne utløse den.
    expect(INNLOGGING, 'ingen lenke fra innloggingen').toContain('/logg-inn/glemt')
    expect(INNLOGGING).toMatch(/Glemt passord\?/)
  })

  it('kvitteringen erstatter skjemaet', () => {
    // Står feltet igjen under «lenke sendt», trykker man en gang til —
    // og havner i ratebegrensningen som gjør at den FØRSTE lenken var
    // den siste som kom fram.
    expect(SKJEMA).toMatch(/if \(tilstand\?\.ok\)/)
  })
})
