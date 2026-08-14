import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import {
  fordelAaret, planleggMaaned, dagerPerUkedag,
  type Krav, type Vindu, type FastVakt,
} from '@/lib/bemanning'
import { FastVaktSkjema, KravSkjema, VinduSkjema } from './skjemaer'
import { slettFastVakt, slettKrav, slettVindu } from './handlinger'

const UKEDAG = ['', 'man', 'tir', 'ons', 'tor', 'fre', 'lør', 'søn']
const MND = ['januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember']
const kl = (t: number) => `${String(t).padStart(2, '0')}:00`

type Sok = Promise<{ stasjon?: string; ar?: string; maned?: string }>

// Radene som de ligger i basen. Motoren bruker camelCase, så mappingen
// skjer ett sted (tilVindu/tilKrav/tilVakt) i stedet for spredt utover.
type VinduRad = {
  id: string; ukedag: number; fra_time: number; til_time: number
  min_bemanning: number; gjelder_fra: string
}
type KravRad = {
  id: string; ukedag: number; fra_time: number; til_time: number
  antall: number; begrunnelse: string | null
}
type VaktRad = { id: string; navn: string; ukedag: number; fra_time: number; til_time: number }

const tilVindu = (v: VinduRad): Vindu => ({
  ukedag: v.ukedag, fraTime: v.fra_time, tilTime: v.til_time, minBemanning: v.min_bemanning,
})
const tilKrav = (k: KravRad): Krav => ({
  ukedag: k.ukedag, fraTime: k.fra_time, tilTime: k.til_time, antall: k.antall,
})
const tilVakt = (v: VaktRad): FastVakt => ({
  ukedag: v.ukedag, fraTime: v.fra_time, tilTime: v.til_time,
})

// Kundeformen. Samme måned i fjor er riktigst — januar planlegges ikke etter
// septembertall. Finnes den ikke, faller vi tilbake på siste 90 dager og sier
// ifra i UI-et, for da er formen sesongforskjøvet.
async function hentProfil(
  supabase: Awaited<ReturnType<typeof lagSupabaseServerKlient>>,
  stasjonId: string,
  ar: number,
  maned: number,
): Promise<{ profil: Map<string, number>; kilde: string; dager: number }> {
  const les = async (fra: string, til: string) => {
    const { data } = await supabase
      .from('timesalg')
      .select('dato, time, inne_kunder')
      .eq('stasjon_id', stasjonId)
      .is('slettet_tid', null)
      .not('inne_kunder', 'is', null)
      .gte('dato', fra)
      .lte('dato', til)
    return (data ?? []) as { dato: string; time: string; inne_kunder: number }[]
  }

  const sisteDag = new Date(Date.UTC(ar - 1, maned, 0)).getUTCDate()
  let rader = await les(`${ar - 1}-${String(maned).padStart(2, '0')}-01`,
    `${ar - 1}-${String(maned).padStart(2, '0')}-${sisteDag}`)
  let kilde = `${MND[maned - 1]} ${ar - 1}`

  if (new Set(rader.map((r) => r.dato)).size < 20) {
    const til = new Date()
    const fra = new Date(til.getTime() - 90 * 24 * 3600 * 1000)
    rader = await les(fra.toISOString().slice(0, 10), til.toISOString().slice(0, 10))
    kilde = 'siste 90 dager'
  }

  const sum = new Map<string, { n: number; sum: number }>()
  for (const r of rader) {
    const d = new Date(`${r.dato}T00:00:00Z`).getUTCDay()
    const noekkel = `${d === 0 ? 7 : d}:${Number.parseInt(r.time.split('-')[0], 10)}`
    const s = sum.get(noekkel) ?? { n: 0, sum: 0 }
    s.n++; s.sum += r.inne_kunder
    sum.set(noekkel, s)
  }
  const profil = new Map<string, number>()
  for (const [k, s] of sum) profil.set(k, s.sum / s.n)
  return { profil, kilde, dager: new Set(rader.map((r) => r.dato)).size }
}

export default async function BemanningSide({ searchParams }: { searchParams: Sok }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Bemanningsplanen er for butikksjef og eier.</p>
  }
  const sok = await searchParams
  const supabase = await lagSupabaseServerKlient()

  const { data: stasjoner } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const alle = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
  if (alle.length === 0) return <p>Ingen stasjoner registrert.</p>

  const valgt = alle.find((s) => s.id === sok.stasjon) ?? alle[0]
  // Standard er NESTE måned — det er den man planlegger. Ruller over årsskiftet.
  const naa = new Date()
  const nesteNr = naa.getUTCMonth() + 2
  const nesteManed = nesteNr > 12 ? 1 : nesteNr
  const nesteAr = nesteNr > 12 ? naa.getUTCFullYear() + 1 : naa.getUTCFullYear()
  const ar = Number(sok.ar) || nesteAr
  const maned = Number(sok.maned) || nesteManed
  const iDag = naa.toISOString().slice(0, 10)

  const [{ data: rammer }, { data: vinduer }, { data: krav }, { data: vakter }, profilen] =
    await Promise.all([
      // Hele året, ikke bare måneden: gulvet må trekkes fra i alle tolv før
      // noe kan fordeles. En døgnåpen stasjon kan trenge mer i juni enn
      // bruttokurven gir den, og de timene finnes i en roligere måned.
      supabase.from('bemanning_maned').select('maned, disponible_timer')
        .eq('stasjon_id', valgt.id).eq('ar', ar).order('maned'),
      supabase.from('bemanning_vindu').select('id, ukedag, fra_time, til_time, min_bemanning, gjelder_fra')
        .eq('stasjon_id', valgt.id).order('ukedag').order('gjelder_fra', { ascending: false }),
      supabase.from('bemanning_krav').select('id, ukedag, fra_time, til_time, antall, begrunnelse')
        .eq('stasjon_id', valgt.id).order('ukedag'),
      supabase.from('bemanning_fast_vakt').select('id, navn, ukedag, fra_time, til_time')
        .eq('stasjon_id', valgt.id).order('navn').order('ukedag'),
      hentProfil(supabase, valgt.id, ar, maned),
    ])

  // Databasen er snake_case, motoren camelCase. Mappingen står her, ett sted.
  const alleVinduer = (vinduer ?? []) as VinduRad[]
  // Én rad per ukedag: den nyeste som har trådt i kraft.
  const gjeldende = new Map<number, (typeof alleVinduer)[number]>()
  for (const v of alleVinduer) {
    if (v.gjelder_fra > iDag) continue
    if (!gjeldende.has(v.ukedag)) gjeldende.set(v.ukedag, v)
  }

  const kravListe = (krav ?? []) as KravRad[]
  const vaktListe = (vakter ?? []) as VaktRad[]
  const aarsrammer = ((rammer ?? []) as { maned: number; disponible_timer: number }[])
    .map((r) => ({ maned: r.maned, timer: r.disponible_timer }))

  const oppsett = {
    vinduer: [...gjeldende.values()].map(tilVindu),
    krav: kravListe.map(tilKrav),
    fasteVakter: vaktListe.map(tilVakt),
  }
  // Årsfordelingen først — gulvet i alle tolv månedene, så resten etter
  // bruttokurven. Det er den som avgjør hva denne måneden faktisk har.
  const aar = aarsrammer.length > 0
    ? fordelAaret({ ar, rammer: aarsrammer, ...oppsett })
    : null
  const iMnd = aar?.maaneder.find((m) => m.maned === maned) ?? null
  const disponible = iMnd?.disponible ?? null
  const raaRamme = aarsrammer.find((r) => r.maned === maned)?.timer ?? null

  const plan = disponible !== null && gjeldende.size > 0 && aar?.gjennomforbar
    ? planleggMaaned({ disponibleTimer: disponible, ar, maned, ...oppsett, profil: profilen.profil })
    : null
  const dager = dagerPerUkedag(ar, maned)
  const rutenett = new Map(plan?.timer.map((t) => [`${t.ukedag}:${t.time}`, t]) ?? [])
  const timerVist = plan ? [...new Set(plan.timer.map((t) => t.time))].sort((a, b) => a - b) : []

  return (
    <>
      <h1>Bemanning</h1>
      <p className="undertittel">
        Timerammen fordeles der kundene faktisk er. Du legger inn hvordan dere jobber fast —
        systemet fyller resten.
      </p>

      <section className="kort">
        <form className="rutine-form">
          <select name="stasjon" defaultValue={valgt.id}>
            {alle.map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
          <select name="maned" defaultValue={maned}>
            {MND.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
          </select>
          <input name="ar" type="number" defaultValue={ar} style={{ width: '5rem' }} />
          <button type="submit" className="liten">Vis</button>
        </form>
      </section>

      <section className="kort">
        <h2>{MND[maned - 1]} {ar}</h2>
        {disponible === null ? (
          <p className="undertittel">
            Ingen ramme for denne måneden ennå. Eier må laste opp forretningsplanen på <a href="/import">/import</a>.
          </p>
        ) : aar && !aar.gjennomforbar ? (
          <p className="feil">
            Minimumsbemanningen koster {Math.round(aar.sumBundne)} timer i året — {Math.round(aar.underskudd)} mer
            enn hele årsrammen på {Math.round(aar.pool)}. Dette løses ikke ved å flytte timer mellom
            måneder. Enten må åpningstiden kortes ned, eller så er rammen for stram. Si ifra til eier.
          </p>
        ) : (
          <>
            <p><strong>{Math.round(disponible)} timer</strong> til disposisjon.</p>
            {iMnd && raaRamme !== null && Math.abs(disponible - raaRamme) >= 1 && (
              <p className="undertittel">
                {disponible > raaRamme
                  ? `Måneden låner ${Math.round(disponible - raaRamme)} timer fra resten av året — minimumsbemanningen her koster ${Math.round(iMnd.bundne)} timer, mer enn bruttokurven alene ville gitt.`
                  : `Måneden avgir ${Math.round(raaRamme - disponible)} timer til måneder med tyngre gulv.`}
              </p>
            )}
            {plan === null ? (
              <p className="undertittel">Legg inn bemannet vindu nedenfor, så regner jeg ut forslaget.</p>
            ) : (
              <p className="undertittel">
                {Math.round(plan.bundneTimer)} timer går til minimumsbemanning, timer som krever flere, og faste vakter.
                {' '}{Math.round(plan.brukteTimer)} er fordelt etter kundetrykk.
                {' '}Kundeformen er hentet fra {profilen.kilde} ({profilen.dager} dager).
              </p>
            )}
          </>
        )}
      </section>

      {plan && plan.gjennomforbar && (
        <section className="kort">
          <h2>Forslag til en vanlig uke</h2>
          <table className="tabell">
            <thead>
              <tr>
                <th></th>
                {[1, 2, 3, 4, 5, 6, 7].map((u) => (
                  <th key={u}>{UKEDAG[u]}<br /><span className="undertittel">{dager[u]} dg</span></th>
                ))}
              </tr>
            </thead>
            <tbody>
              {timerVist.map((t) => (
                <tr key={t}>
                  <td>{kl(t)}</td>
                  {[1, 2, 3, 4, 5, 6, 7].map((u) => {
                    const c = rutenett.get(`${u}:${t}`)
                    if (!c) return <td key={u} className="undertittel">—</td>
                    return (
                      <td key={u} title={`${Math.round(c.kunder)} kunder i snitt`}>
                        {c.sum}{c.fast > 0 ? '*' : ''}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
          <p className="undertittel">
            Tallet er antall personer den timen. * betyr at en fast vakt dekker en av dem.
            Hold musen over for kundetrykket.
          </p>
        </section>
      )}

      <section className="kort">
        <h2>Når står det folk i butikken?</h2>
        <p className="undertittel">
          Når står det folk der — ikke når døra åpner. Begynner noen en time før åpning, er det den
          timen som skal stå. Endrer dere åpningstid permanent, legg inn en ny rad med dato fra
          endringen; den gamle blir stående som historikk.
        </p>
        <VinduSkjema stasjonId={valgt.id} iDag={iDag} />
        {alleVinduer.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Dag</th><th>Fra</th><th>Til</th><th>Min.</th><th>Gjelder fra</th><th></th></tr></thead>
            <tbody>
              {alleVinduer.map((v) => (
                <tr key={v.id} style={{ opacity: v.gjelder_fra > iDag ? 0.5 : 1 }}>
                  <td>{UKEDAG[v.ukedag]}</td>
                  <td>{kl(v.fra_time)}</td>
                  <td>{kl(v.til_time)}</td>
                  <td>{v.min_bemanning}</td>
                  <td>{v.gjelder_fra}</td>
                  <td>
                    <form action={slettVindu}>
                      <input type="hidden" name="id" value={v.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="kort">
        <h2>Faste vakter</h2>
        <p className="undertittel">
          Deg selv, NK, eller andre som alltid står. De går på fastlønn og bruker ikke av timerammen,
          men dekker minimumsbemanningen i timene de står. Gjelder bare de som faktisk har fastlønn —
          føres en timelønnet inn her, tror planen at de timene er gratis.
        </p>
        <FastVaktSkjema stasjonId={valgt.id} />
        {vaktListe.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Hvem</th><th>Dag</th><th>Fra</th><th>Til</th><th></th></tr></thead>
            <tbody>
              {vaktListe.map((v) => (
                <tr key={v.id}>
                  <td>{v.navn}</td>
                  <td>{UKEDAG[v.ukedag]}</td>
                  <td>{kl(v.fra_time)}</td>
                  <td>{kl(v.til_time)}</td>
                  <td>
                    <form action={slettFastVakt}>
                      <input type="hidden" name="id" value={v.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="kort">
        <h2>Timer der én ikke holder</h2>
        <p className="undertittel">
          Varemottak, eller andre timer der én ikke holder. Uten en rad her foreslås aldri to
          personer på en rolig time — de ekstra hendene går dit kundene faktisk er.
        </p>
        <KravSkjema stasjonId={valgt.id} />
        {kravListe.length > 0 && (
          <table className="tabell">
            <thead><tr><th>Dag</th><th>Fra</th><th>Til</th><th>Antall</th><th>Hvorfor</th><th></th></tr></thead>
            <tbody>
              {kravListe.map((k) => (
                <tr key={k.id}>
                  <td>{UKEDAG[k.ukedag]}</td>
                  <td>{kl(k.fra_time)}</td>
                  <td>{kl(k.til_time)}</td>
                  <td>{k.antall}</td>
                  <td>{k.begrunnelse ?? '—'}</td>
                  <td>
                    <form action={slettKrav}>
                      <input type="hidden" name="id" value={k.id} />
                      <button type="submit" className="liten slett">Slett</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  )
}
