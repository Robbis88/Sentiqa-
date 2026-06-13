import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { avsluttRunde, slettRunde } from './handlinger'

type Runde = { id: string; sporsmal_id: string; start_dato: string; slutt_dato: string; status: string; puls_sporsmal: { tekst: string; kategori: string } | null }

export default async function PulsSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Puls administreres av eier/butikksjef. Ansatte svarer på tableten.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const { data: runder } = await supabase
    .from('puls_runde')
    .select('id, sporsmal_id, start_dato, slutt_dato, status, puls_sporsmal(tekst, kategori)')
    .is('slettet_tid', null)
    .order('opprettet_tid', { ascending: false })
    .overrideTypes<Runde[]>()

  const ids = (runder ?? []).map((r) => r.id)
  const antall = new Map<string, number>()
  const sum = new Map<string, number>()
  if (ids.length > 0) {
    const { data: svar } = await supabase.from('puls_svar').select('runde_id, skala').in('runde_id', ids)
    for (const s of (svar ?? []) as { runde_id: string; skala: number | null }[]) {
      if (s.skala == null) continue
      antall.set(s.runde_id, (antall.get(s.runde_id) ?? 0) + 1)
      sum.set(s.runde_id, (sum.get(s.runde_id) ?? 0) + s.skala)
    }
  }

  return (
    <>
      <h1>Puls</h1>
      <p className="undertittel">Korte pulsmålinger — ett spørsmål om gangen. <Link href="/puls/ny">+ Start måling</Link> · <Link href="/puls/sporsmal">Spørsmål</Link></p>

      {(runder ?? []).length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen målinger ennå. <Link href="/puls/ny">Start en måling</Link> — skriv spørsmålet rett i skjemaet.</p></section>
      ) : (
        (runder ?? []).map((r) => {
          const n = antall.get(r.id) ?? 0
          const snitt = n > 0 ? (sum.get(r.id)! / n).toFixed(1) : '—'
          return (
            <section className="kort" key={r.id}>
              <h2>
                <Link href={`/puls/${r.id}`}>{r.puls_sporsmal?.tekst ?? '—'}</Link>{' '}
                <span className={`status-pip ${r.status === 'aktiv' ? 'gronn' : 'gul'}`}>{r.status === 'aktiv' ? 'Aktiv' : 'Avsluttet'}</span>
              </h2>
              <p className="undertittel">
                {r.puls_sporsmal?.kategori} · {datoLang.format(new Date(r.start_dato))}–{datoLang.format(new Date(r.slutt_dato))} · {n} svar · snitt {snitt}
              </p>
              <div className="konk-knapper">
                <Link href={`/puls/${r.id}`} className="liten" style={{ textDecoration: 'none', display: 'inline-flex', alignItems: 'center', padding: '0.3rem 0.6rem' }}>Resultater</Link>
                {r.status === 'aktiv' && (
                  <form action={avsluttRunde}><input type="hidden" name="id" value={r.id} /><button type="submit" className="liten">Avslutt</button></form>
                )}
                <form action={slettRunde}><input type="hidden" name="id" value={r.id} /><button type="submit" className="liten slett">Slett</button></form>
              </div>
            </section>
          )
        })
      )}
    </>
  )
}
