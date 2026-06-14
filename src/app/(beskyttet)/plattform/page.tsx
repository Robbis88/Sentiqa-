import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { beregnAbonnement } from '@/lib/pris'
import { kr, datoLang } from '@/lib/format'
import { NyKunde } from './ny-kunde'

// Plattform-eierens tverr-tenant-oversikt: hvem bruker systemet, omfang og hva
// du skal fakturere. Service-role (leser på tvers av kjeder) — derfor streng
// gate på plattform_redaktor FØR vi rører admin-klienten.
export default async function PlattformSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return <p>Plattform-oversikten er for plattform-eier.</p>

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return <><h1>Plattform</h1><p className="undertittel">Mangler service-nøkkel (SUPABASE_SERVICE_ROLE_KEY) — kan ikke lese på tvers av kjeder.</p></>
  }

  const [{ data: retailers }, { data: stasjoner }, { data: profiler }, { data: jobber }] = await Promise.all([
    admin.from('retailers').select('id, navn, org_nr, opprettet_tid').is('slettet_tid', null).order('navn').overrideTypes<{ id: string; navn: string; org_nr: string | null; opprettet_tid: string }[]>(),
    admin.from('stasjoner').select('retailer_id').is('slettet_tid', null).overrideTypes<{ retailer_id: string }[]>(),
    admin.from('profiler').select('retailer_id, rolle').overrideTypes<{ retailer_id: string | null; rolle: string }[]>(),
    admin.from('import_jobber').select('retailer_id, opprettet_tid').overrideTypes<{ retailer_id: string; opprettet_tid: string }[]>(),
  ])

  const tell = (rader: { retailer_id: string | null }[], pred: (r: never) => boolean = () => true) => {
    const m = new Map<string, number>()
    for (const r of rader) { if (r.retailer_id && pred(r as never)) m.set(r.retailer_id, (m.get(r.retailer_id) ?? 0) + 1) }
    return m
  }
  const stasjonerPer = tell(stasjoner ?? [])
  const brukerePer = tell(profiler ?? [])
  const tabletPer = tell(profiler ?? [], (r: { rolle: string }) => r.rolle === 'butikkbruker_tablet')
  const sisteJobbPer = new Map<string, string>()
  for (const j of jobber ?? []) {
    const f = sisteJobbPer.get(j.retailer_id)
    if (!f || j.opprettet_tid > f) sisteJobbPer.set(j.retailer_id, j.opprettet_tid)
  }

  const rader = (retailers ?? []).map((r) => {
    const ant = stasjonerPer.get(r.id) ?? 0
    const pris = beregnAbonnement(ant, false)
    return { ...r, stasjoner: ant, tableter: tabletPer.get(r.id) ?? 0, brukere: brukerePer.get(r.id) ?? 0, siste: sisteJobbPer.get(r.id) ?? null, maaned: pris.maaned, aarlig: pris.aarlig }
  })
  const sum = rader.reduce((a, r) => ({ stasjoner: a.stasjoner + r.stasjoner, tableter: a.tableter + r.tableter, brukere: a.brukere + r.brukere, maaned: a.maaned + r.maaned, aarlig: a.aarlig + r.aarlig }), { stasjoner: 0, tableter: 0, brukere: 0, maaned: 0, aarlig: 0 })
  const kortDato = (iso: string) => datoLang.format(new Date(iso))

  return (
    <>
      <h1>Plattform</h1>
      <p className="undertittel">Alle kjeder på plattformen — omfang, aktivitet og faktureringsgrunnlag (listepris). Avtalte rabatter avtales utenfor systemet.</p>

      <section className="nokkeltall">
        <div className="kpi"><span className="kpi-tall">{rader.length}</span><span className="kpi-merke">Kjeder</span></div>
        <div className="kpi"><span className="kpi-tall">{sum.stasjoner}</span><span className="kpi-merke">Stasjoner totalt</span></div>
        <div className="kpi"><span className="kpi-tall">{kr.format(sum.maaned)}</span><span className="kpi-merke">Samlet pr mnd (listepris)</span></div>
        <div className="kpi"><span className="kpi-tall">{kr.format(sum.aarlig)}</span><span className="kpi-merke">Samlet pr år</span></div>
      </section>

      <section className="kort">
        <h2>Kjeder</h2>
        {rader.length === 0 ? (
          <p className="undertittel">Ingen kjeder ennå.</p>
        ) : (
          <table className="tabell">
            <thead><tr><th>Kjede</th><th>Org.nr</th><th>Stasjoner</th><th>Tableter</th><th>Brukere</th><th>Siste opplasting</th><th>Pr mnd</th><th>Pr år</th></tr></thead>
            <tbody>
              {rader.map((r) => (
                <tr key={r.id}>
                  <td>{r.navn}</td>
                  <td className="undertittel">{r.org_nr ?? '—'}</td>
                  <td>{r.stasjoner}</td>
                  <td>{r.tableter}</td>
                  <td>{r.brukere}</td>
                  <td className="undertittel">{r.siste ? kortDato(r.siste) : <span className="status-pip gul">ingen</span>}</td>
                  <td>{kr.format(r.maaned)}</td>
                  <td>{kr.format(r.aarlig)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr><th>Sum</th><th></th><th>{sum.stasjoner}</th><th>{sum.tableter}</th><th>{sum.brukere}</th><th></th><th>{kr.format(sum.maaned)}</th><th>{kr.format(sum.aarlig)}</th></tr>
            </tfoot>
          </table>
        )}
        <p className="undertittel" style={{ marginTop: '0.6rem' }}>
          Listepris: {kr.format(beregnAbonnement(0, false).maaned)}/mnd per kjede + 249/mnd per stasjon. Årlig = 10 mnd (2 gratis ved forskudd). «Siste opplasting» er nyeste fil i import-kø — et aktivitetssignal.
        </p>
      </section>

      <section className="kort">
        <h2>Ny kunde</h2>
        <p className="undertittel">
          Oppretter kjeden og sender en e-postinvitasjon til admin-kontakten, som velger eget passord via lenken.
          Krever at du har koblet en e-postleverandør (SMTP) i Supabase → Authentication → SMTP. Deretter legger du inn stasjonene på vegne av kunden under Stasjoner.
        </p>
        <NyKunde />
      </section>
    </>
  )
}
