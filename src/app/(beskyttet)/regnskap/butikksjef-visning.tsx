import type { InnloggetBruker } from '@/lib/auth/typer'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { kr, prosent, manedAar, avviksKlasse } from '@/lib/format'
import { byggPeriodeGrupper } from '@/lib/perioder'
import { BUTIKKSJEF_PERSONAL_KODER, BUTIKKSJEF_DRIFT_KODER } from '@/lib/regnskap-tilgang'
import { SKJUL_OMS_KODER as SKJUL_OMS } from '@/lib/avdelinger'
import { PeriodeVelger } from '../periode-velger'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { motBudsjett, storsteAvvik, svaret } from '@/lib/regnskap/mot-budsjett'

type Linje = { seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null; regnskap_hittil?: number | null; budsjett_hittil?: number | null }
type Kost = { navn: string; regnskap: number; budsjett: number }

// Butikksjef ser kun EGEN stasjon: omsetning + BRF + påvirkbare kostnader.
// Aldri royalty/husleie/finans/varekost-detaljer eller «Resultat» (admin-nivå).
export async function RegnskapButikksjef({ bruker, periode: valgtPeriode, butikknummer }: { bruker: InnloggetBruker; periode?: string; butikknummer?: string }) {
  const supabase = await lagSupabaseServerKlient()

  const { data: tilgang } = await supabase.from('butikksjef_stasjoner').select('stasjon_id').eq('profil_id', bruker.id)
  const stasjonIds = (tilgang ?? []).map((t) => t.stasjon_id as string)
  if (stasjonIds.length === 0) return <p className="undertittel">Du har ingen stasjon tildelt ennå.</p>
  const { data: stasjoner } = await supabase.from('stasjoner').select('id, butikknummer, navn').in('id', stasjonIds).order('butikknummer').overrideTypes<{ id: string; butikknummer: string; navn: string }[]>()
  // BUTIKKSJEF-GRENEN AGGREGERER IKKE. Den er en skjermet visning av
  // EGEN stasjon, og rutetabellen sier derfor at /regnskap bare taaler
  // aggregat for retailer_admin. `tillatAlleFor` gir false her uansett
  // hvor mange stasjoner hun har - og appskallet regner det samme, saa
  // hun faar ikke tilbudt «Alle stasjoner» paa en side som ikke har det.
  const liste = (stasjoner ?? []) as { id: string; butikknummer: string; navn: string }[]
  const sok = new URLSearchParams()
  if (butikknummer) sok.set('butikknummer', butikknummer)
  const valgtId = await husketStasjon(
    liste, stasjonFraUrl(sok, liste),
    tillatAlleFor('/regnskap', bruker.rolle, liste.length),
  )
  const stasjon = liste.find((s) => s.id === valgtId) ?? liste[0]
  if (!stasjon) return <p className="undertittel">Ingen stasjon.</p>

  // Perioder for stasjonen (rød tråd)
  const { data: perRader } = await supabase.from('regnskapslinjer').select('periode').eq('stasjon_id', stasjon.id).order('periode', { ascending: false }).overrideTypes<{ periode: string }[]>()
  const perioder = [...new Set((perRader ?? []).map((p) => p.periode))]
  if (perioder.length === 0) {
    return (
      <>
        <Sidehode tittel={`Regnskap · ${stasjon.butikknummer} ${stasjon.navn}`} />
        <Tomtilstand
          tittel="Ingen regnskapsdata for din stasjon ennå"
          forklaring="Regnskapet legges inn sentralt. Så snart perioden er lastet opp, ser du omsetning, bruttofortjeneste og kostnadene du selv styrer her."
        />
      </>
    )
  }
  // Periode: enkeltmåned (YYYY-MM) eller hittil i år (YYYY-hittil). År skilles.
  const ytdAar = valgtPeriode && /^\d{4}-hittil$/.test(valgtPeriode) ? valgtPeriode.slice(0, 4) : null
  const hittil = ytdAar != null
  let aktivPeriode: string
  let valgtVerdi: string
  if (hittil) {
    const iAaret = perioder.filter((p) => p.slice(0, 4) === ytdAar).sort()
    aktivPeriode = iAaret[iAaret.length - 1] ?? perioder[0]
    valgtVerdi = `${ytdAar}-hittil`
  } else {
    const valgtIso = valgtPeriode && /^\d{4}-\d{2}$/.test(valgtPeriode) ? `${valgtPeriode}-01` : null
    aktivPeriode = valgtIso && perioder.includes(valgtIso) ? valgtIso : perioder[0]
    valgtVerdi = aktivPeriode.slice(0, 7)
  }

  // Summer månedene jan→valgt (hittil) eller den ene måneden — RLS gir kun egne
  // stasjoner; vi filtrerer til valgt stasjon. (Per-stasjon-hittil i basen er 0.)
  const fra = hittil ? `${ytdAar}-01-01` : aktivPeriode
  // `regnskap_sum` er den samme funksjonen som `0065` skrev bare
  // halvparten av. Svelges feilen, viser sida et tomt regnskap i stedet
  // for å si at oppslaget ikke gikk — og et tomt regnskap ser ut som en
  // måned uten tall.
  const { data: alle, error } = await supabase.rpc('regnskap_sum', { p_fra: fra, p_til: aktivPeriode })
  if (error) throw new Error(`regnskap_sum feilet: ${error.message}`)
  type SumRad = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; sortering: number | null; regnskap: number | null; budsjett: number | null }
  const linjer: Linje[] = ((alle ?? []) as SumRad[])
    .filter((r) => r.stasjon_id === stasjon.id)
    .map((r) => ({ ...r, avvik: (r.regnskap ?? 0) - (r.budsjett ?? 0), index_pct: r.budsjett ? (((r.regnskap ?? 0) - r.budsjett) / r.budsjett) * 100 : null }))
    .sort((a, b) => (a.sortering ?? 9999) - (b.sortering ?? 9999))

  const seksjon = (n: string) => linjer.filter((l) => l.seksjon === n && !SKJUL_OMS.has(l.kode ?? ''))
  const sumR = (ls: Linje[]) => ls.reduce((a, l) => a + (l.regnskap ?? 0), 0)
  const omsTot = sumR(seksjon('omsetning'))
  const brfTot = sumR(seksjon('bruttofortjeneste'))

  // Påvirkbare kostnader: personal samlet til én linje + de utvalgte drift-kodene.
  const drift = seksjon('driftskostnader')
  const personal = drift.filter((l) => l.kode && BUTIKKSJEF_PERSONAL_KODER.has(l.kode))
  const kostnader: Kost[] = []
  if (personal.length > 0) {
    kostnader.push({ navn: 'Personalkostnad', regnskap: sumR(personal), budsjett: personal.reduce((a, l) => a + (l.budsjett ?? 0), 0) })
  }
  for (const kode of BUTIKKSJEF_DRIFT_KODER) {
    const l = drift.find((x) => x.kode === kode)
    if (l && ((l.regnskap ?? 0) !== 0 || (l.budsjett ?? 0) !== 0)) kostnader.push({ navn: l.post, regnskap: l.regnskap ?? 0, budsjett: l.budsjett ?? 0 })
  }

  // NIVÅ 1 — svaret. Butikksjefen har ingen resultatlinje å måles på;
  // bruttofortjenesten er det nærmeste hun kommer, og driveren hentes fra
  // kostnadene hun faktisk styrer. Å peke på husleie ville vært å be henne
  // fikse noe hun ikke rår over.
  const brfBudsjett = seksjon('bruttofortjeneste').reduce((a, l) => a + (l.budsjett ?? 0), 0)
  const motBrf = motBudsjett(brfTot, brfBudsjett)
  const driver = storsteAvvik(kostnader.map((k) => ({ post: k.navn, regnskap: k.regnskap, budsjett: k.budsjett })), true)
  const svar = svaret('Bruttofortjeneste', motBrf, driver)
  const periodeTekst = hittil ? `Hittil i år ${ytdAar}` : manedAar.format(new Date(aktivPeriode))

  return (
    <>
      <Sidehode
        tittel={`Regnskap · ${stasjon.butikknummer} ${stasjon.navn}`}
        undertittel={svar ? `${svar}. ${periodeTekst}` : `${periodeTekst} · din stasjon`}
      />

      {/* Stasjonsvelgeren staar i toppstripen, ett sted for hele systemet.
          Butikksjefen med to stasjoner byttet her for; naa bytter hun
          samme sted som overalt ellers. Se trinn 09. */}

      {perioder.length > 0 && (
        <div className="regnskap-velgere">
          <PeriodeVelger
            valgt={valgtVerdi}
            grupper={byggPeriodeGrupper(perioder, true)}
            basePath="/regnskap"
            bevar={liste.length > 1 ? { butikknummer: stasjon.butikknummer } : {}}
          />
        </div>
      )}

      <section className="nokkeltall">
        {([
          { merke: 'Omsetning', verdi: omsTot, budsjett: seksjon('omsetning').reduce((a, l) => a + (l.budsjett ?? 0), 0) },
          { merke: 'Bruttofortjeneste', verdi: brfTot, budsjett: brfBudsjett },
        ] as const).map(({ merke, verdi, budsjett }) => {
          const mot = motBudsjett(verdi, budsjett)
          return (
            <div className="kpi" key={merke}>
              <span className="kpi-tall">{kr.format(verdi)}</span>
              <span className="kpi-merke">{merke}</span>
              {mot.tekst && (
                <span className={`kpi-mot${mot.bra === null ? '' : mot.bra ? ' god' : ' darlig'}`}>
                  {mot.tekst}
                </span>
              )}
            </div>
          )
        })}
      </section>

      <Forklaring sporsmaal="Hvorfor ser jeg ikke hele regnskapet?">
        <p>
          Du ser omsetning, bruttofortjeneste og kostnadene du selv styrer. Royalty,
          husleie, finans og varekost-detaljer ligger på selskapsnivå — de er ikke
          skjult for å holde noe tilbake, men fordi de ikke er noe du kan gjøre noe med
          på skiftet ditt.
        </p>
        <p>
          {hittil
            ? `Hittil i år summerer månedene januar til og med ${manedAar.format(new Date(aktivPeriode))}.`
            : `Tallene gjelder ${manedAar.format(new Date(aktivPeriode))} alene.`}{' '}
          «Drar mest» er det største avviket målt i kroner blant de påvirkbare
          kostnadene. Avvik under 2 % regnes som truffet budsjett.
        </p>
      </Forklaring>

      {(['omsetning', 'bruttofortjeneste'] as const).map((navn) => (
        <section className="kort" key={navn}>
          <h2>{navn === 'omsetning' ? 'Omsetning' : 'Bruttofortjeneste'}</h2>
          <table className="tabell">
            <thead><tr><th>Avdeling</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th>Mot budsjett</th></tr></thead>
            <tbody>
              {seksjon(navn).map((l, i) => (
                <tr key={i}>
                  <td>{l.post}</td>
                  <td>{kr.format(l.regnskap ?? 0)}</td>
                  <td className="mob-skjul">{kr.format(l.budsjett ?? 0)}</td>
                  <td>{l.index_pct != null ? <span className={`status-pip ${avviksKlasse(l.index_pct)}`}>{prosent.format(l.index_pct / 100)}</span> : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      ))}

      <section className="kort">
        <h2>Påvirkbare kostnader</h2>
        <p className="undertittel">Kostnadene du selv styrer. Resten (royalty, husleie, finans …) ligger på admin-nivå.</p>
        <table className="tabell">
          <thead><tr><th>Kostnad</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th>Mot budsjett</th></tr></thead>
          <tbody>
            {kostnader.map((k) => {
              const avvik = k.regnskap - k.budsjett
              const overBudsjett = k.budsjett > 0 && avvik > 0
              return (
                <tr key={k.navn}>
                  <td>{k.navn}</td>
                  <td>{kr.format(k.regnskap)}</td>
                  <td className="mob-skjul">{kr.format(k.budsjett)}</td>
                  <td><span className={`status-pip ${overBudsjett ? 'rod' : 'gronn'}`}>{avvik >= 0 ? '+' : '−'}{kr.format(Math.abs(avvik))}</span></td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </section>
    </>
  )
}
