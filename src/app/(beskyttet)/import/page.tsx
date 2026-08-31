import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Opplaster } from './opplaster'
import { KlientOpplaster } from './klient-opplaster'
import { settAllowlist } from './handlinger'
import { BehandleKnapp } from './behandle-knapp'
import { BehandleAlleKnapp } from './behandle-alle-knapp'
import { behandleJobb } from '@/lib/import/behandle'
import { nesteSteg, onboardingsteg, type Kildemaaling } from '@/lib/onboarding'
import { Sidehode, Datatabell } from '@/components/ui/side'
import { Status, type Statusnivaa } from '@/components/ui/status'

// Regnskaps-import utløser tung AI (Opus + fokus), og «Behandle alle» kan kjøre
// mange filer — gi handlingen god tid.
export const maxDuration = 300

// Brukerens ord, ikke systemets. «Parset» betyr ingenting for en
// stasjonseier, og «Mottatt» er verre — det antyder at systemet gjør
// resten, mens det i praksis betyr «ligger i kø».
const STATUS_ETIKETT: Record<string, { tekst: string; klasse: string }> = {
  mottatt: { tekst: 'I kø', klasse: 'bla' },
  behandler: { tekst: 'Leser fila …', klasse: 'gul' },
  parset: { tekst: 'Importert', klasse: 'gronn' },
  feilet: { tekst: 'Feilet', klasse: 'rod' },
}

const RAPPORT_ETIKETT: Record<string, string> = {
  st1_salgsstatistikk: 'Salgsstatistikk',
  st1_salesperhour: 'Timesalg',
  st1_salesperhour_inneute: 'Timesalg',
  st1_cashierstats: 'Kassererstat.',
  salgsgrid_varetrans: 'Synlig svinn',
  regnskap_resultat: 'Regnskap',
  st1_bp: 'Forretningsplan',
  easyatwork_stempling: 'Stemplinger',
  ukjent: '—',
}

// All tidsvisning tvinges til Europe/Oslo (§18)
const tid = new Intl.DateTimeFormat('nb-NO', {
  timeZone: 'Europe/Oslo',
  dateStyle: 'short',
  timeStyle: 'short',
})
const dato = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'medium' })
const maaned = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', month: 'long', year: 'numeric' })

// «Gjelder»-visning: regnskap er en måned, resten en dato.
function gjelder(j: { rapporttype: string; gjelder_dato: string | null }): string {
  if (!j.gjelder_dato) return '—'
  const d = new Date(j.gjelder_dato)
  return j.rapporttype === 'regnskap_resultat' ? maaned.format(d) : dato.format(d)
}

type Jobb = {
  id: string
  status: string
  rapporttype: string
  antall_rader: number | null
  feilmelding: string | null
  gjelder_dato: string | null
  opprettet_tid: string
  raa_filer: { filnavn: string; mottakskanal: string } | null
}

// Hva ligger faktisk i basen? Måles per kilde, per stasjon — ikke som et
// «du er 60 % ferdig», som skjuler at de siste 40 er den ene fila som gjør
// at bemanningsplanen virker.
//
// Tellingen skjer i basen (v_datadekning, 0090). Første forsøk hentet hver
// eneste rad i salgstabellen hit for å telle datoer: PostgREST kutter på
// 1000 rader, så svaret ble løgn, og spørringen var dyr nok til å velte
// siden på en tabell som vokser med drift.
//
// Dagene telles på stasjonen med MINST. En kilde som dekker fire stasjoner
// godt og den femte i tre dager er ikke i mål; den femte får ingen analyse.
async function maalKilder(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
): Promise<Kildemaaling[]> {
  const { data } = await supabase
    .from('v_datadekning')
    .select('kilde, stasjon_id, dager, siste_dato')
  const rader = (data ?? []) as {
    kilde: string; stasjon_id: string; dager: number; siste_dato: string | null
  }[]

  const perKilde = new Map<string, { dager: number[]; stasjoner: Set<string>; siste: string | null }>()
  for (const r of rader) {
    const k = perKilde.get(r.kilde) ?? { dager: [], stasjoner: new Set<string>(), siste: null }
    k.dager.push(r.dager)
    k.stasjoner.add(r.stasjon_id)
    if (r.siste_dato && (!k.siste || r.siste_dato > k.siste)) k.siste = r.siste_dato
    perKilde.set(r.kilde, k)
  }

  return [...perKilde].map(([noekkel, k]) => ({
    noekkel,
    stasjonerMedData: k.stasjoner.size,
    dagerDekket: k.dager.length > 0 ? Math.min(...k.dager) : 0,
    sisteDato: k.siste,
  }))
}

const STEG_KLASSE: Record<string, string> = {
  mangler: 'rod', ufullstendig: 'rod', tynt: 'gul', ok: 'gronn',
}
const STEG_TEKST: Record<string, string> = {
  mangler: 'Mangler', ufullstendig: 'Ufullstendig', tynt: 'Tynt', ok: 'På plass',
}


/**
 * De tre gamle fargeklassene, oversatt til systemets semantiske spraak.
 *
 * Grensene er uendret - det er bare navnet og det at ORDET foelger med
 * som er nytt. En prosentpip der fargen var eneste forskjell mellom
 * «greit» og «ikke greit» kunne ikke leses av den som ikke ser farge.
 */
function nivaaFraKlasse(k: string): Statusnivaa {
  return k === 'gronn' ? 'normal' : k === 'gul' ? 'endring' : k === 'rod' ? 'handling' : 'normal'
}

export default async function ImportSide(
  { searchParams }: { searchParams: Promise<{ type?: string }> },
) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier har tilgang til import.</p>
  }

  const naa = new Date()
  const supabase = await lagSupabaseServerKlient()
  const { data: retailer } = await supabase
    .from('retailers')
    .select('inntak_epost, avsender_allowlist')
    .maybeSingle<{ inntak_epost: string | null; avsender_allowlist: string[] }>()
  // FILTERET ER IKKE PYNT. Lista viser de 50 siste jobbene, og med
  // daglige salgsimporter er en forretningsplan fra i fjor for lengst ute
  // av vinduet. Den lastes opp en gang i aaret og er nettopp den man
  // trenger aa finne igjen - for aa kjoere den om igjen mot ny kode.
  const sp = await searchParams
  const filter = sp.type === 'st1_bp' ? 'st1_bp' : null
  let sporring = supabase
    .from('import_jobber')
    .select(
      'id, status, rapporttype, antall_rader, feilmelding, gjelder_dato, opprettet_tid, raa_filer(filnavn, mottakskanal)',
    )
    .order('opprettet_tid', { ascending: false })
    .limit(50)
  if (filter) sporring = sporring.eq('rapporttype', filter)
  const { data } = await sporring.overrideTypes<Jobb[]>()

  const jobber = data ?? []
  const { count: antallStasjoner } = await supabase
    .from('stasjoner').select('id', { count: 'exact', head: true }).is('slettet_tid', null)
  const steg = onboardingsteg(await maalKilder(supabase), antallStasjoner ?? 0)
  const neste = nesteSteg(steg)
  // «Behandles nå» har en grense. Kaster gjenkjenningen før statusen rekker
  // å bli satt, blir raden stående i «Leser fila …» for alltid — og da er en
  // skjult knapp det siste man trenger. Samme frist som nattjobbens
  // gjenoppretting (DOD_ETTER_MIN i ko.ts).
  const dodFrist = new Date(naa.getTime() - 20 * 60_000).toISOString()

  // NIVÅ 1 på en arbeidsflyt: hvor langt er jeg kommet, og hva stopper meg.
  // «Neste steg» var regnet ut, men sto inne i en seksjon under en
  // undertittel om hvilke filformater systemet tar imot. Neste steg ER
  // svaret på denne siden; filformatene er en opplysning man trenger
  // etterpå, og de står i tabellen under uansett.
  const feiler = jobber.filter((j) => j.status === 'feilet').length

  return (
    <>
      <Sidehode
        tittel="Import"
        undertittel={[
          neste ? `Neste steg: ${neste.navn}. ${neste.beskjed}` : 'Alt på plass — systemet har det det trenger for alle stasjoner.',
          feiler > 0 ? `${feiler} ${feiler === 1 ? 'fil feilet' : 'filer feilet'}` : null,
        ].filter(Boolean).join(' · ')}
      />

      {/* Datasett mot datasett nedover, «har/mangler» bortover. Dette
          ER en matrise, og blir det. */}
      <Datatabell tittel="Hva systemet har, og hva det mangler">
          <thead>
            <tr><th>Data</th><th>Status</th><th>Hvor den hentes</th><th>Hva den gir deg</th></tr>
          </thead>
          <tbody>
            {steg.map((s) => (
              <tr key={s.noekkel}>
                <td>{s.navn}</td>
                <td>
                  <Status nivaa={nivaaFraKlasse(STEG_KLASSE[s.status])}>
                    {STEG_TEKST[s.status]}
                  </Status>
                  <br />
                  <span className="undertittel">{s.beskjed}</span>
                </td>
                <td className="undertittel">{s.hentesFra}</td>
                <td className="undertittel">{s.laserOpp}</td>
              </tr>
            ))}
          </tbody>
      </Datatabell>

      <section className="kort">
        <h2>Last opp filer</h2>
        <KlientOpplaster />
        {/* Reserveveien. Fila går gjennom en server action, og plattformen
            avviser kropper over noen få MB med 413 — store filer hører derfor
            hjemme i feltet over, som laster rett til Storage. */}
        <details className="sq-luft-over-liten">
          <summary className="undertittel">
            Reserve: last opp uten å parse i nettleseren
          </summary>
          <div className="sq-luft-over-liten">
            <p className="undertittel">
              For små filer som feltet over ikke klarer å tolke. Fila legges i kø og parses på
              serveren. Bruk ikke denne til forretningsplanen — den er for stor og blir avvist
              (413); store filer tar feltet over.
            </p>
            <Opplaster />
          </div>
        </details>
      </section>

      <section className="kort">
        <h2>E-post-inntak</h2>
        <p className="undertittel">
          Videresend rapportene til denne adressen, så havner vedleggene rett i køen (§6):
        </p>
        <p><code className="inntak-adresse">{retailer?.inntak_epost ?? '— ikke satt —'}</code></p>
        <form action={settAllowlist} className="skjema sq-smal-flate">
          <label className="felt">
            <span>Godkjente avsendere (én per linje – tom = alle slipper gjennom)</span>
            <textarea
              name="allowlist"
              rows={3}
              defaultValue={(retailer?.avsender_allowlist ?? []).join('\n')}
              placeholder="rapporter@st1.no"
            />
          </label>
          <button type="submit" className="liten primar">Lagre avsendere</button>
        </form>
      </section>

      <section className="kort">
        <h2>Status</h2>
        <BehandleAlleKnapp antall={jobber.filter((j) => j.status === 'mottatt').length} />
        {/* Lista viser de 50 siste. Forretningsplanen lastes opp én gang i
            året, og er nettopp den man trenger å finne igjen — den er for
            lengst ute av vinduet når salgsfilene kommer daglig. */}
        <nav className="sq-faner" aria-label="Filtrer importjobber">
          <Link href="/import" className="sq-fane" aria-current={filter ? undefined : 'page'}>
            Alle
          </Link>
          <Link
            href="/import?type=st1_bp"
            className="sq-fane"
            aria-current={filter === 'st1_bp' ? 'page' : undefined}
          >
            Forretningsplan
          </Link>
        </nav>
        {jobber.length === 0 ? (
          <p className="undertittel">
            {filter
              ? 'Ingen forretningsplaner er lastet opp ennå.'
              : 'Ingen filer lastet opp ennå.'}
          </p>
        ) : (
          <table className="tabell">
            <thead>
              <tr>
                <th>Fil</th>
                <th>Type</th>
                <th>Gjelder</th>
                <th>Mottatt</th>
                <th>Status</th>
                <th>Resultat</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {jobber.map((j) => {
                const s = STATUS_ETIKETT[j.status] ?? { tekst: j.status, klasse: 'gul' }
                // Idempotent → tillat ny kjøring på alt unntatt det som behandles nå.
                const kanBehandle = j.status !== 'behandler' || j.opprettet_tid < dodFrist
                const knappetekst = j.status === 'parset' ? 'Behandle på nytt' : 'Behandle'
                return (
                  <tr key={j.id}>
                    <td>{j.raa_filer?.filnavn ?? '—'}</td>
                    <td>{RAPPORT_ETIKETT[j.rapporttype] ?? j.rapporttype}</td>
                    <td>{gjelder(j)}</td>
                    <td>{tid.format(new Date(j.opprettet_tid))}</td>
                    <td><Status nivaa={nivaaFraKlasse(s.klasse)}>{s.tekst}</Status></td>
                    <td className="resultat">
                      {j.status === 'parset' && j.antall_rader != null
                        ? `${j.antall_rader} linjer`
                        : null}
                      {j.feilmelding ? <span className="feil-tekst">{j.feilmelding}</span> : null}
                    </td>
                    <td>
                      {kanBehandle ? (
                        <form action={behandleJobb}>
                          <input type="hidden" name="jobbId" value={j.id} />
                          <BehandleKnapp tekst={knappetekst} />
                        </form>
                      ) : null}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </section>
    </>
  )
}
