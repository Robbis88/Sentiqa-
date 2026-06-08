import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { settOppStandard, leggTilPunkt, leggTilPerson, veksleFullfort } from './handlinger'

type Punkt = { id: string; omrade: string; tekst: string; sortering: number }
type Person = { id: string; stasjon_id: string; navn: string; startdato: string | null }
type Fullfort = { person_id: string; punkt_id: string; fullfort_dato: string }

export default async function OpplaringSide({
  searchParams,
}: {
  searchParams: Promise<{ person?: string }>
}) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Opplæring administreres av eier/butikksjef.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const sp = await searchParams

  const [{ data: punkter }, { data: personer }, { data: stasjoner }, { data: fullfort }] = await Promise.all([
    supabase.from('opplaring_punkter').select('id, omrade, tekst, sortering').is('slettet_tid', null).order('sortering').overrideTypes<Punkt[]>(),
    supabase.from('opplaring_personer').select('id, stasjon_id, navn, startdato').is('slettet_tid', null).eq('aktiv', true).order('navn').overrideTypes<Person[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('opplaring_fullfort').select('person_id, punkt_id, fullfort_dato').overrideTypes<Fullfort[]>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const fullPerPerson = new Map<string, Map<string, string>>()
  for (const f of fullfort ?? []) {
    const m = fullPerPerson.get(f.person_id) ?? new Map()
    m.set(f.punkt_id, f.fullfort_dato)
    fullPerPerson.set(f.person_id, m)
  }
  const totalPunkter = (punkter ?? []).length
  const valgt = (personer ?? []).find((p) => p.id === sp.person)

  // Grupper punkter per område
  const omrader: { navn: string; punkter: Punkt[] }[] = []
  for (const p of punkter ?? []) {
    let g = omrader.find((o) => o.navn === p.omrade)
    if (!g) { g = { navn: p.omrade, punkter: [] }; omrader.push(g) }
    g.punkter.push(p)
  }

  return (
    <>
      <h1>Opplæring</h1>
      <p className="undertittel">Opplæringsplan for nyansatte — kryss av og signer per punkt.</p>

      {totalPunkter === 0 ? (
        <section className="kort">
          <h2>Sett opp læreplan</h2>
          <p className="undertittel">Ingen læreplan ennå. Start med standardplanen (18 punkter), så kan du tilpasse.</p>
          <form action={settOppStandard}><button type="submit">Sett opp standard læreplan</button></form>
        </section>
      ) : (
        <>
          <section className="kort">
            <h2>Under opplæring</h2>
            <form action={leggTilPerson} className="rutine-form">
              <input name="navn" placeholder="Navn på nyansatt" required />
              <select name="stasjon_id" required defaultValue={(stasjoner ?? []).length === 1 ? stasjoner![0].id : ''}>
                {(stasjoner ?? []).length !== 1 && <option value="" disabled>Stasjon …</option>}
                {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
              </select>
              <input name="startdato" type="date" aria-label="Startdato" />
              <button type="submit" className="liten">Legg til</button>
            </form>

            {(personer ?? []).length === 0 ? (
              <p className="undertittel" style={{ marginTop: '0.75rem' }}>Ingen personer under opplæring.</p>
            ) : (
              <ul className="person-liste">
                {(personer ?? []).map((p) => {
                  const antall = fullPerPerson.get(p.id)?.size ?? 0
                  const pst = totalPunkter ? Math.round((antall / totalPunkter) * 100) : 0
                  return (
                    <li key={p.id} className={valgt?.id === p.id ? 'aktiv' : ''}>
                      <Link href={`/opplaring?person=${p.id}`}>
                        <strong>{p.navn}</strong>
                        <span className="undertittel"> · {navnFor.get(p.stasjon_id) ?? '—'}{p.startdato ? ` · fra ${datoLang.format(new Date(p.startdato))}` : ''}</span>
                      </Link>
                      <span className={`status-pip ${pst === 100 ? 'gronn' : 'gul'}`}>{antall}/{totalPunkter}</span>
                    </li>
                  )
                })}
              </ul>
            )}
          </section>

          {valgt && (
            <section className="kort">
              <h2>{valgt.navn} — sjekkliste</h2>
              {omrader.map((o) => (
                <div className="ik-gruppe" key={o.navn}>
                  <h3>{o.navn}</h3>
                  <ul className="rutine-liste">
                    {o.punkter.map((pkt) => {
                      const dato = fullPerPerson.get(valgt.id)?.get(pkt.id)
                      const fullfortNa = Boolean(dato)
                      return (
                        <li key={pkt.id} className={fullfortNa ? 'gjort' : ''}>
                          <form action={veksleFullfort}>
                            <input type="hidden" name="person_id" value={valgt.id} />
                            <input type="hidden" name="punkt_id" value={pkt.id} />
                            <input type="hidden" name="stasjon_id" value={valgt.stasjon_id} />
                            <input type="hidden" name="til" value={fullfortNa ? 'nei' : 'ja'} />
                            <button type="submit" className={`kryss ${fullfortNa ? 'av' : ''}`} aria-label="Signer">{fullfortNa ? '✓' : ''}</button>
                          </form>
                          <div className="rutine-tekst">
                            {pkt.tekst}
                            {dato ? <span className="undertittel"> · signert {datoLang.format(new Date(dato))}</span> : null}
                          </div>
                        </li>
                      )
                    })}
                  </ul>
                </div>
              ))}
            </section>
          )}

          <section className="kort">
            <h2>Legg til lærepunkt</h2>
            <form action={leggTilPunkt} className="rutine-form">
              <input name="omrade" placeholder="Område (f.eks. Kasse & salg)" />
              <input name="tekst" placeholder="Hva skal læres" required />
              <button type="submit" className="liten">Legg til</button>
            </form>
          </section>
        </>
      )}
    </>
  )
}
