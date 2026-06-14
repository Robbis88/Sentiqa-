import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { beregnAbonnement } from '@/lib/pris'
import { kr, datoLang } from '@/lib/format'
import { NyKunde } from './ny-kunde'
import { BekreftKnapp } from './kunde-handlinger'
import { sendInvitasjonPaaNytt, deaktiverKunde, reaktiverKunde, slettKundePermanent } from './handlinger'

// Plattform-eierens tverr-tenant-oversikt: hvem bruker systemet, omfang og hva
// du skal fakturere — pluss onboarding og avslutning. Service-role (leser på
// tvers av kjeder) — derfor streng gate på plattform_redaktor FØR admin-klienten.
export default async function PlattformSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return <p>Plattform-oversikten er for plattform-eier.</p>

  let admin
  try {
    admin = lagSupabaseAdminKlient()
  } catch {
    return <><h1>Plattform</h1><p className="undertittel">Mangler service-nøkkel (SUPABASE_SERVICE_ROLE_KEY) — kan ikke lese på tvers av kjeder.</p></>
  }

  const [{ data: retailers }, { data: stasjoner }, { data: profiler }, { data: jobber }, brukere] = await Promise.all([
    admin.from('retailers').select('id, navn, org_nr, opprettet_tid, slettet_tid').order('navn').overrideTypes<{ id: string; navn: string; org_nr: string | null; opprettet_tid: string; slettet_tid: string | null }[]>(),
    admin.from('stasjoner').select('retailer_id').is('slettet_tid', null).overrideTypes<{ retailer_id: string }[]>(),
    admin.from('profiler').select('id, retailer_id, rolle').overrideTypes<{ id: string; retailer_id: string | null; rolle: string }[]>(),
    admin.from('import_jobber').select('retailer_id, opprettet_tid').overrideTypes<{ retailer_id: string; opprettet_tid: string }[]>(),
    admin.auth.admin.listUsers({ page: 1, perPage: 1000 }),
  ])

  const authMap = new Map((brukere.data?.users ?? []).map((u) => [u.id, u]))
  const tell = (rader: { retailer_id: string | null }[], pred: (r: never) => boolean = () => true) => {
    const m = new Map<string, number>()
    for (const r of rader) { if (r.retailer_id && pred(r as never)) m.set(r.retailer_id, (m.get(r.retailer_id) ?? 0) + 1) }
    return m
  }
  const stasjonerPer = tell(stasjoner ?? [])
  const brukerePer = tell(profiler ?? [])
  const tabletPer = tell(profiler ?? [], (r: { rolle: string }) => r.rolle === 'butikkbruker_tablet')
  const sisteJobbPer = new Map<string, string>()
  for (const j of jobber ?? []) { const f = sisteJobbPer.get(j.retailer_id); if (!f || j.opprettet_tid > f) sisteJobbPer.set(j.retailer_id, j.opprettet_tid) }
  // Admin-kontakt + om de har tatt i bruk kontoen (logget inn) per kjede.
  const adminPer = new Map<string, { epost: string | undefined; aktivert: boolean }>()
  for (const p of profiler ?? []) {
    if (p.rolle === 'retailer_admin' && p.retailer_id && !adminPer.has(p.retailer_id)) {
      const u = authMap.get(p.id)
      adminPer.set(p.retailer_id, { epost: u?.email, aktivert: !!u?.last_sign_in_at })
    }
  }

  const beriket = (retailers ?? []).map((r) => {
    const ant = stasjonerPer.get(r.id) ?? 0
    const pris = beregnAbonnement(ant, false)
    return { ...r, stasjoner: ant, tableter: tabletPer.get(r.id) ?? 0, brukere: brukerePer.get(r.id) ?? 0, siste: sisteJobbPer.get(r.id) ?? null, adminInfo: adminPer.get(r.id), maaned: pris.maaned, aarlig: pris.aarlig }
  })
  const aktive = beriket.filter((r) => !r.slettet_tid)
  const deaktiverte = beriket.filter((r) => r.slettet_tid)
  const sum = aktive.reduce((a, r) => ({ stasjoner: a.stasjoner + r.stasjoner, maaned: a.maaned + r.maaned, aarlig: a.aarlig + r.aarlig }), { stasjoner: 0, maaned: 0, aarlig: 0 })
  const kortDato = (iso: string) => datoLang.format(new Date(iso))

  return (
    <>
      <h1>Plattform</h1>
      <p className="undertittel">Alle kjeder på plattformen — omfang, aktivitet og faktureringsgrunnlag (listepris). Avtalte rabatter avtales utenfor systemet.</p>

      <section className="nokkeltall">
        <div className="kpi"><span className="kpi-tall">{aktive.length}</span><span className="kpi-merke">Aktive kjeder</span></div>
        <div className="kpi"><span className="kpi-tall">{sum.stasjoner}</span><span className="kpi-merke">Stasjoner totalt</span></div>
        <div className="kpi"><span className="kpi-tall">{kr.format(sum.maaned)}</span><span className="kpi-merke">Samlet pr mnd (listepris)</span></div>
        <div className="kpi"><span className="kpi-tall">{kr.format(sum.aarlig)}</span><span className="kpi-merke">Samlet pr år</span></div>
      </section>

      <section className="kort">
        <h2>Aktive kjeder</h2>
        {aktive.length === 0 ? (
          <p className="undertittel">Ingen aktive kjeder ennå.</p>
        ) : (
          <table className="tabell">
            <thead><tr><th>Kjede</th><th>Admin</th><th>Stasj.</th><th>Tabl.</th><th>Brukere</th><th>Siste oppl.</th><th>Pr mnd</th><th>Handlinger</th></tr></thead>
            <tbody>
              {aktive.map((r) => (
                <tr key={r.id}>
                  <td>{r.navn}<br /><span className="undertittel">{r.org_nr ?? '—'}</span></td>
                  <td>
                    <span className="undertittel">{r.adminInfo?.epost ?? '—'}</span><br />
                    {r.adminInfo ? <span className={`status-pip ${r.adminInfo.aktivert ? 'gronn' : 'gul'}`}>{r.adminInfo.aktivert ? 'aktiv' : 'venter pålogging'}</span> : null}
                  </td>
                  <td>{r.stasjoner}</td>
                  <td>{r.tableter}</td>
                  <td>{r.brukere}</td>
                  <td className="undertittel">{r.siste ? kortDato(r.siste) : <span className="status-pip gul">ingen</span>}</td>
                  <td>{kr.format(r.maaned)}</td>
                  <td>
                    <div className="plattform-handlinger">
                      {r.adminInfo?.epost ? (
                        <BekreftKnapp action={sendInvitasjonPaaNytt} epost={r.adminInfo.epost} etikett="Send på nytt" sporsmaal={`Sende påloggingslenke på nytt til ${r.adminInfo.epost}?`} />
                      ) : null}
                      <BekreftKnapp action={deaktiverKunde} id={r.id} etikett="Deaktiver" klasse="liten slett" sporsmaal={`Deaktivere ${r.navn}? Brukerne mister tilgang, men data beholdes (kan reaktiveres).`} />
                      <BekreftKnapp action={slettKundePermanent} id={r.id} etikett="Slett" klasse="liten slett" sporsmaal={`PERMANENT slette ${r.navn} og ALLE data + brukere? Dette kan ikke angres.`} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot><tr><th>Sum</th><th></th><th>{sum.stasjoner}</th><th></th><th></th><th></th><th>{kr.format(sum.maaned)}</th><th></th></tr></tfoot>
          </table>
        )}
        <p className="undertittel" style={{ marginTop: '0.6rem' }}>
          Listepris: {kr.format(beregnAbonnement(0, false).maaned)}/mnd per kjede + 249/mnd per stasjon. Årlig = 10 mnd (2 gratis ved forskudd). «venter pålogging» = admin har fått invitasjon, men ikke logget inn ennå.
        </p>
      </section>

      {deaktiverte.length > 0 && (
        <section className="kort">
          <h2>Deaktiverte kjeder</h2>
          <ul className="arr-liste">
            {deaktiverte.map((r) => (
              <li key={r.id}>
                <span>{r.navn} <span className="undertittel">{r.org_nr ?? ''} · {r.stasjoner} stasjoner · sperret</span></span>
                <div className="plattform-handlinger">
                  <BekreftKnapp action={reaktiverKunde} id={r.id} etikett="Reaktiver" sporsmaal={`Reaktivere ${r.navn}? Brukerne får tilgang igjen.`} />
                  <BekreftKnapp action={slettKundePermanent} id={r.id} etikett="Slett permanent" klasse="liten slett" sporsmaal={`PERMANENT slette ${r.navn} og ALLE data + brukere? Dette kan ikke angres.`} />
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

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
