import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { utenKommentarer } from '@/lib/redesign/design'

// =====================================================================
// PORTEN SKAL IKKE GÅ AN Å GÅ RUNDT
//
// `krevStotte` er verdiløs hvis en plattformhandling kan hente
// tjenestenøkkelen selv i stedet. Da er porten en konvensjon, og en
// konvensjon er nettopp det denne kodebasen har sett svikte fire ganger:
// regelen står skrevet, alle er enige, og så glemmer noen den én gang.
//
// Vakten leser kilden. Den kan ikke kjøre handlingene — de snakker med
// Supabase — men både porten og omveien rundt den står i teksten.
//
// ---------------------------------------------------------------------
// HVA SOM ER GATET, OG HVA SOM MED VILJE IKKE ER DET
//
// Gatet: handlinger som rører en LEVENDE kjede.
// Ikke gatet: å opprette en kunde (det finnes ingen kunde ennå),
// å godkjenne en (samme), og å sende en gjenopprettingslenke — den
// finnes nettopp for kunden som ikke kommer inn, og et vindu som måtte
// åpnes først ville låst flyten den ble laget for. Den logges i stedet.
//
// Unntakene står NAVNGITT under. Et navngitt unntak kan leses og
// bestrides; et hull i en regex kan ingen se.
// =====================================================================

const KILDE = readFileSync(
  join(process.cwd(), 'src', 'app', '(beskyttet)', 'plattform', 'handlinger.ts'), 'utf8')
const PORT = readFileSync(join(process.cwd(), 'src', 'lib', 'stotte.ts'), 'utf8')
const MIGRASJON = readFileSync(
  join(process.cwd(), 'supabase', 'migrations', '0196_stottetilgang.sql'), 'utf8')

const kode = utenKommentarer(KILDE)
const portkode = utenKommentarer(PORT)

/** Handlinger som rører en levende kjede og derfor må gjennom porten. */
const MAA_GATES = ['deaktiverKunde', 'reaktiverKunde', 'slettKundePermanent']

/** Navngitte unntak, med grunnen. Ikke et hull — en beslutning. */
const UNNTAK: Record<string, string> = {
  opprettKunde: 'Oppretter kjeden. Det finnes ingen kunde å be om tilgang til ennå.',
  godkjennKunde: 'Slipper en selvregistrert kjede inn. Samme: ingen data å røre.',
  sendInvitasjonPaaNytt: 'Finnes for kunden som ikke kommer inn. Logges i kontrollrommet i stedet.',
  apneStottevindu: 'Er selve åpningen. Kan ikke kreve seg selv.',
  lukkStottevindu: 'Lukker et vindu som allerede er åpnet.',
}

function kroppen(navn: string): string {
  const start = kode.indexOf(`export async function ${navn}(`)
  if (start < 0) return ''
  const neste = kode.indexOf('export async function ', start + 1)
  return kode.slice(start, neste < 0 ? undefined : neste)
}

describe('KANARIFUGL', () => {
  it('vakten finner faktisk handlingene', () => {
    // Uten denne ville «ingen avvik» også vært svaret hvis fila ble
    // omdøpt — og alle påstandene under sanne om tom streng.
    for (const navn of MAA_GATES) {
      expect(kroppen(navn).length, `fant ikke ${navn}`).toBeGreaterThan(150)
    }
    expect(portkode).toContain('krevStotte')
  })

  it('hvert unntak peker på en handling som finnes', () => {
    // Et unntak for noe som er slettet er et hull som ser ut som en regel.
    for (const navn of Object.keys(UNNTAK)) {
      expect(kode, `unntaket ${navn} gjelder ingenting lenger — fjern det`)
        .toContain(`export async function ${navn}(`)
    }
  })
})

describe('porten står foran det den skal', () => {
  it('hver handling som rører en levende kjede krever støttetilgang', () => {
    for (const navn of MAA_GATES) {
      expect(kroppen(navn), `${navn} går utenom krevStotte`).toContain('krevStotte(')
    }
  })

  it('ingen gatet handling henter tjenestenøkkelen selv', () => {
    // Omveien: `lagSupabaseAdminKlient()` eller `eierOgAdmin()` inne i en
    // handling som skal gjennom porten. Da er porten pynt.
    for (const navn of MAA_GATES) {
      const k = kroppen(navn)
      expect(k, `${navn} henter admin-klienten utenom porten`)
        .not.toContain('lagSupabaseAdminKlient(')
      expect(k, `${navn} bruker eierOgAdmin, som ikke sjekker støttetilgang`)
        .not.toContain('eierOgAdmin(')
    }
  })

  it('ingen NY handling slipper unna uten å stå i lista', () => {
    // Den halvdelen som pleier å mangle: vakten feller det som forsvinner,
    // men ikke det som legges til. En handling ingen har tatt stilling til
    // ser ut som en handling det er tatt stilling til.
    const alle = [...kode.matchAll(/export async function (\w+)\(/g)].map((m) => m[1])
    const uklassifisert = alle.filter((n) => !MAA_GATES.includes(n) && !(n in UNNTAK))
    expect(uklassifisert,
      '\nDisse plattformhandlingene er hverken gatet eller navngitt som unntak:\n  '
      + uklassifisert.join('\n  ')
      + '\n\nLegg dem i MAA_GATES hvis de roerer en levende kjede, eller i '
      + 'UNNTAK med en skrevet grunn.\n')
      .toEqual([])
  })
})

describe('porten feiler lukket', () => {
  it('feil rolle gir nei', () => {
    expect(portkode).toContain("rolle !== 'plattform_redaktor'")
  })

  it('ingen aktiv rad gir nei', () => {
    expect(portkode).toMatch(/if \(!data\)/)
  })

  it('en feilet spørring gir nei, ikke ja', () => {
    // Den varianten som pleier å bli skrevet motsatt. En port som slipper
    // gjennom når den ikke får svar, står åpen akkurat når basen sliter.
    const etterFeil = portkode.slice(portkode.indexOf('if (error)'))
    expect(etterFeil.slice(0, 200), 'feilgrenen returnerer ikke et avslag')
      .toContain('ok: false')
  })

  it('en handling som ikke lot seg logge, skjer ikke', () => {
    // Hele poenget er sporet. Uten det er dette tjenestenøkkelen med et
    // ekstra steg.
    expect(portkode).toMatch(/if \(le\) return \{ ok: false/)
  })

  it('oppslaget skrives FØR handlingen utføres', () => {
    // En handling som feiler halvveis har likevel vært et oppslag i
    // kundens data — og det er den varianten kunden vil se.
    const loggPos = portkode.indexOf("from('stotte_oppslag')")
    const returPos = portkode.indexOf('return { ok: true')
    expect(loggPos, 'fant ingen skriving av oppslaget').toBeGreaterThan(-1)
    expect(loggPos, 'oppslaget logges etter at porten har sluppet gjennom').toBeLessThan(returPos)
  })
})

describe('basen håndhever det kommentaren lover', () => {
  it('vinduet er tidsbegrenset i skjemaet, ikke bare i koden', () => {
    // Et vindu man kan sette til ti aar er ikke et vindu.
    expect(MIGRASJON).toContain('stotte_tilgang_vindu')
    expect(MIGRASJON).toMatch(/til_tid <= fra_tid \+ interval/)
  })

  it('begrunnelsen er påkrevd av basen', () => {
    expect(MIGRASJON).toContain('stotte_tilgang_begrunnelse_ekte')
  })

  it('kunden kan lese sin egen logg', () => {
    // Uten dette er «etterprøvbar» et ord, ikke en egenskap.
    expect(MIGRASJON).toContain('stotte_tilgang_les')
    expect(MIGRASJON).toContain('stotte_oppslag_les')
  })

  it('ingen skrivepolicy finnes — en logg som lar seg redigere dokumenterer ingenting', () => {
    expect(MIGRASJON).not.toMatch(/create policy \w*stotte\w*_skriv/)
    expect(MIGRASJON).not.toMatch(/stotte_\w+ for (insert|update|delete)/)
  })

  it('anon er stengt ute ved siden av granten', () => {
    expect(MIGRASJON).toContain('revoke all on public.stotte_tilgang from anon')
    expect(MIGRASJON).toContain('revoke all on public.stotte_oppslag from anon')
  })

  it('hjelpefunksjonene er pakket i (select ...) i policyene', () => {
    // Uten pakkingen evalueres de per rad -> statement timeout -> 0 rader,
    // som ser ut som datatap. Slo ut daglig_salg 2026-06-16.
    // Telling, ikke mønstermatching: HVERT kall skal være pakket, og da
    // er de to tallene like. En regex på «ikke foran» bommer på at tegnet
    // foran er en mellomrom, ikke en parentes — og ville stått grønn.
    const tell = (s: string) => (MIGRASJON.match(new RegExp(s.replace(/[.()]/g, '\\$&'), 'g')) ?? []).length
    for (const fn of ['public.gjeldende_retailer_id()', 'public.gjeldende_rolle()']) {
      expect(tell(fn), `fant ingen kall til ${fn}`).toBeGreaterThan(0)
      expect(tell(`(select ${fn})`), `${fn} er kalt upakket et sted`).toBe(tell(fn))
    }
  })

  it('migrasjonen taaler aa kjoeres om igjen', () => {
    expect(MIGRASJON).toContain('create table if not exists public.stotte_tilgang')
    expect(MIGRASJON).toContain('create table if not exists public.stotte_oppslag')
    expect((MIGRASJON.match(/drop policy if exists/g) ?? []).length).toBeGreaterThanOrEqual(2)
  })

  it('fila er ren ASCII — innlimingskjeden legger ellers paa et stray-tegn', () => {
    const stygge = [...MIGRASJON].filter((c) => c.charCodeAt(0) > 127)
    expect(stygge, `fant ${stygge.length} ikke-ASCII-tegn`).toEqual([])
  })
})
