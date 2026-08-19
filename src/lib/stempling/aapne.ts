import type { SupabaseClient } from '@supabase/supabase-js'
import { avledVakter, type Hendelse } from './avled'

// =====================================================================
// Åpne vakter for én stasjon i én periode.
//
// PERIODEN, IKKE ALT. En vakt som står åpen fra juni skal blokkere
// juni-fila, ikke august-fila i tillegg. Blokkerte vi på alt som
// noensinne har stått åpent, ville én glemt utstempling i mai stoppe
// lønn resten av året — og da slutter folk å tro på sperren.
//
// Vinduet strekkes én dag i hver ende. En vakt som starter 31. juli
// 22:00 og skulle vært lukket 1. august 06:00 hører til juli, fordi
// forretningsdatoen følger starten (se avled.ts). Uten strekket ville
// den falle mellom to filer og aldri blokkere noen av dem.
// =====================================================================

export type AapenVakt = {
  ansattNr: string
  ansattNavn: string
  /** ISO-tidspunkt for innstemplingen som aldri fikk noen ut. */
  siden: string
}

type Rad = {
  id: string
  ansatt_nr: string
  ansatt_navn: string
  stasjon_id: string
  tidspunkt: string
  type: 'inn' | 'ut'
}

const DAG = 86_400_000

/** Perioden strukket ett døgn i hver ende. Se forklaringen over. */
function vindu(ar: number, maned: number): { fra: string; til: string } {
  return {
    fra: new Date(Date.UTC(ar, maned - 1, 1) - DAG).toISOString(),
    til: new Date(Date.UTC(ar, maned, 1) + DAG).toISOString(),
  }
}

/**
 * Måneden en innstempling hører til, i Oslo-tid.
 *
 * Ikke `.slice(0, 7)` på ISO-strengen: en vakt som starter 1. september
 * 01:00 norsk tid er 31. august 23:00 UTC, og ville blitt talt i august.
 * Forretningsdatoen følger starten i norsk tid (se avled.ts), og da må
 * dette gjøre det samme.
 */
const osloMaaned = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'Europe/Oslo', year: 'numeric', month: '2-digit',
})

/**
 * Vakter som er stemplet inn og aldri ut, med start i perioden.
 *
 * Tom liste betyr at fila kan lages. Feiler spørringen — for eksempel
 * fordi migrasjonen ikke er kjørt ennå — svarer vi `null`, ikke tom
 * liste. Forskjellen er hele poenget: «ingen åpne vakter» og «jeg vet
 * ikke» må ikke se like ut for den som skal kjøre lønn.
 */
export async function hentAapneVakter(
  supabase: SupabaseClient,
  stasjonId: string,
  ar: number,
  maned: number,
): Promise<AapenVakt[] | null> {
  const { fra, til } = vindu(ar, maned)

  const { data, error } = await supabase
    .from('stempling_hendelse')
    .select('id, ansatt_nr, ansatt_navn, stasjon_id, tidspunkt, type')
    .eq('stasjon_id', stasjonId)
    .is('annullert_tid', null)
    .gte('tidspunkt', fra)
    .lt('tidspunkt', til)
    .order('tidspunkt')

  // 42P01 = tabellen finnes ikke. Da er stemplingen ikke tatt i bruk paa
  // denne basen ennaa, og alle timer kommer fra easy@work-importen inn i
  // `stempling`. Ingen kan staa innstemplet i en tabell som ikke er der,
  // saa svaret er «ingen aapne» — ikke «vet ikke».
  //
  // Skillet er verdt praesisjonen: gjorde vi alle feil til «vet ikke»,
  // ville sperren stoppe lonnsfila som virker i dag, helt til
  // migrasjonen kjores. En ny sikring som slaar ut en fungerende rutine
  // blir skrudd av, og da sikrer den ingenting.
  if (error) {
    const kode = (error as { code?: string }).code
    return kode === '42P01' ? [] : null
  }

  const hendelser: Hendelse[] = ((data ?? []) as Rad[]).map((r) => ({
    id: r.id,
    ansattNr: r.ansatt_nr,
    ansattNavn: r.ansatt_navn,
    stasjonId: r.stasjon_id,
    tidspunkt: r.tidspunkt,
    type: r.type,
  }))

  const { avvik } = avledVakter(hendelser)

  // BARE «aapen». De to andre avvikene er ikke aapne vakter:
  //
  //   «dobbel_inn» er innstemplingen som kom mens hun alt var inne — den
  //   blir lukket av neste ut. Det er den FORLATTE innstemplingen for
  //   den som staar aapen, og avledningen har allerede lagt den inn som
  //   «aapen». Tar vi med begge, teller vi samme problem to ganger.
  //
  //   «foreldrelos» er en ut uten inn. Den mangler timer, men ingen
  //   staar inne — og en sperre som blokkerer paa noe annet enn aapne
  //   vakter ville sagt noe annet enn det den heter.
  const maaned = `${ar}-${String(maned).padStart(2, '0')}`
  return avvik
    .filter((a) => a.slag === 'aapen')
    .map((a) => ({
      ansattNr: a.hendelse.ansattNr,
      ansattNavn: a.hendelse.ansattNavn,
      siden: a.hendelse.tidspunkt,
    }))
    // Strekket henter inn nabodognene; her kastes de som faktisk hoerer
    // til nabomaaneden.
    .filter((v) => osloMaaned.format(new Date(v.siden)) === maaned)
    .sort((a, b) => a.siden.localeCompare(b.siden))
}
