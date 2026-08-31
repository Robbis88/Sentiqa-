import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { iDag, datoLang, tall, kr } from '@/lib/format'
import { finnTidsproblemer, samletTap, type Tidsproblem } from '@/lib/svinn/tidsproblem'
import { finnUtsolgt, type Kandidatrad, type UtsolgtHendelse } from '@/lib/utsolgt'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { Sideramme } from '@/components/ui/sideramme'

// Kjører deteksjon for alle tilgjengelige stasjoner (én RPC hver).
export const maxDuration = 60
const VINDU = 35

type Stasjon = { id: string; butikknummer: string; navn: string }
type StasjonResultat = {
  stasjon: Stasjon
  hendelser: UtsolgtHendelse[]
  tapt: number
  tidsproblemer: Tidsproblem[]
}

function dato(d: string): string {
  return datoLang.format(new Date(`${d}T12:00:00Z`))
}

export default async function UtsolgtSide({ searchParams }: { searchParams: Promise<{ butikknummer?: string }> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <p>Du har ikke tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const { data: alleStasjoner } = await supabase
    .from('stasjoner').select('id, butikknummer, navn').is('slettet_tid', null).order('butikknummer')
    .overrideTypes<Stasjon[]>()
  let stasjoner = alleStasjoner ?? []
  if (bruker.rolle === 'butikksjef') {
    const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
    const ids = new Set((tilgang ?? []).map((t) => t.stasjon_id))
    stasjoner = stasjoner.filter((s) => ids.has(s.id))
  }

  const idag = iDag()
  const resultater: StasjonResultat[] = await Promise.all(
    stasjoner.map(async (stasjon) => {
      const fra = new Date(`${idag}T12:00:00Z`)
      fra.setUTCDate(fra.getUTCDate() - VINDU)
      const [{ data }, { data: svinnrader }] = await Promise.all([
        supabase.rpc('utsolgt_kandidater', { p_stasjon: stasjon.id, p_dager: VINDU }),
        // Samme vindu som utsolgt-deteksjonen. Uten det ville
        // sammenligningen vaert mellom to ulike perioder.
        supabase.from('synlig_svinn')
          .select('ean, varenavn, dato, antall, nettopris_total')
          .eq('stasjon_id', stasjon.id)
          .gte('dato', fra.toISOString().slice(0, 10))
          .is('slettet_tid', null),
      ])
      const hendelser = finnUtsolgt((data ?? []) as Kandidatrad[], idag, VINDU)
      const tidsproblemer = finnTidsproblemer(
        ((svinnrader ?? []) as {
          ean: string | null; varenavn: string | null; dato: string
          antall: number | null; nettopris_total: number | null
        }[]).map((r) => ({
          ean: r.ean ?? '', varenavn: r.varenavn, dato: r.dato,
          antall: r.antall, kr: r.nettopris_total,
        })),
        hendelser,
      )
      return {
        stasjon,
        hendelser,
        tapt: hendelser.reduce((s, h) => s + h.tapt_kr, 0),
        tidsproblemer,
      }
    }),
  )

  // Denne siden noekler paa BUTIKKNUMMER, ikke id — derfor oversettes
  // valget fra toppstripen. URL-en vinner fortsatt, som ellers.
  const fraKontekst = await husketStasjon(stasjoner)
  const valgtNr = sp.butikknummer
    || stasjoner.find((s2) => s2.id === fraKontekst)?.butikknummer
    || stasjoner[0]?.butikknummer
    || ''
  const valgt = resultater.find((r) => r.stasjon.butikknummer === valgtNr) ?? resultater[0]
  const totaltHendelser = resultater.reduce((s, r) => s + r.hendelser.length, 0)

  return (
    <Sideramme>
      <Sidehode
        tittel="Mulig utsolgt"
        undertittel={totaltHendelser === 0
          ? `Ingen tegn til tom hylle de siste ${VINDU} dagene.`
          : `${totaltHendelser} ${totaltHendelser === 1 ? 'hendelse' : 'hendelser'} `
            + `siste ${VINDU} dager.`}
      />

      {valgt && valgt.tidsproblemer.length > 0 && (
        <section className="kort sq-tidsproblem">
          <h2>Samme vare, motsatt feil</h2>
          <p className="undertittel">
            {valgt.tidsproblemer.length}{' '}
            {valgt.tidsproblemer.length === 1 ? 'vare' : 'varer'} blir både kastet
            og går tom i samme periode. Det er ikke for mye eller for lite — det er
            feil tid. Til sammen {kr.format(samletTap(valgt.tidsproblemer))}.
          </p>
          <div className="tabellramme">
            <table className="tabell">
              <thead>
                <tr>
                  <th>Vare</th>
                  <th className="tall">Kastet</th>
                  <th className="tall">Tom</th>
                  <th className="tall">Koster</th>
                </tr>
              </thead>
              <tbody>
                {valgt.tidsproblemer.map((t) => (
                  <tr key={t.ean}>
                    <td>
                      {t.varenavn}
                      <br />
                      <span className="undertittel">{t.melding}</span>
                    </td>
                    <td className="tall">{t.svinnDager} d · {kr.format(t.svinnKr)}</td>
                    <td className="tall">{t.utsolgtDager} d · {kr.format(t.tapteKr)}</td>
                    <td className="tall"><strong>{kr.format(t.samletKr)}</strong></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="notis" style={{ marginBottom: 0 }}>
            Svinnrapporten og utsolgt-deteksjonen ser hver sin halvdel. Kastet du
            baguetter 22:00 og manglet dem 07:30, gir de to sidene motsatt råd —
            og begge tar feil.
          </p>
        </section>
      )}

      <Forklaring sporsmaal="Hvordan finnes disse?">
        Faste varer — de som selger jevnt, snitt minst 1,5 per dag — som
        plutselig falt til null i minst to dager og så var tilbake på
        normalen. Det er signaturen på utsolgt eller en glemt bestilling.
        Estimert tap er normalsalg × dager × snittpris.
      </Forklaring>

      {stasjoner.length > 1 && (
        <section className="kort">
          <h2>Oversikt — hvor butikken mister salg på tom hylle</h2>
          <table className="tabell">
            <thead><tr><th>Stasjon</th><th>Hendelser</th><th>Estimert tapt</th></tr></thead>
            <tbody>
              {[...resultater].sort((a, b) => b.tapt - a.tapt).map((r) => (
                <tr key={r.stasjon.id}>
                  <td>{r.stasjon.butikknummer} {r.stasjon.navn}</td>
                  <td><span className={`status-pip ${r.hendelser.length === 0 ? 'gronn' : r.hendelser.length <= 3 ? 'gul' : 'rod'}`}>{r.hendelser.length}</span></td>
                  <td>{r.tapt > 0 ? kr.format(r.tapt) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="undertittel" style={{ marginTop: '0.5rem' }}>Lavt tall = god kontroll på bestilling/produksjon. Estimatet er normalsalg × dager × snittpris.</p>
        </section>
      )}

      {!valgt || valgt.hendelser.length === 0 ? (
        <Tomtilstand
          tittel="Ingen tegn til tom hylle"
          forklaring={totaltHendelser === 0 && stasjoner.length <= 1
            ? 'Ingen faste varer falt til null og kom tilbake. Det tyder på god kontroll på bestilling og produksjon.'
            : 'Ingen flagg for denne stasjonen i perioden.'}
        />
      ) : (
        <section className="kort">
          <div className="seksjon-topp">
            <h2>{valgt.stasjon.butikknummer} {valgt.stasjon.navn}</h2>
            <span className="undertittel">{valgt.hendelser.length} hendelse(r) · est. tapt {kr.format(valgt.tapt)}</span>
          </div>
          <table className="tabell">
            <thead><tr><th>Vare</th><th>Periode</th><th>Dager</th><th>Snitt/dag</th><th>Est. tapt</th></tr></thead>
            <tbody>
              {valgt.hendelser.map((h, i) => (
                <tr key={`${h.ean}-${i}`}>
                  <td>{h.varenavn}</td>
                  <td>{dato(h.fra)}{h.dager > 1 ? ` – ${dato(h.til)}` : ''}</td>
                  <td><span className="status-pip rod">{h.dager}</span></td>
                  <td>{tall.format(h.snitt)}</td>
                  <td>{h.tapt_kr > 0 ? kr.format(h.tapt_kr) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="undertittel" style={{ marginTop: '0.6rem' }}>
            Hver rad er en vare som solgte normalt, falt til 0 i {`≥`}2 dager, og kom tilbake. Sjekk om det var reelt utsolgt (bestilling/produksjon) eller en annen forklaring.
          </p>
        </section>
      )}
    </Sideramme>
  )
}
