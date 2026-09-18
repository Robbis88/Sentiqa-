import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { Sideramme } from '@/components/ui/sideramme'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { endreForesporsel, opprettTilbud, registrerAksept, opprettKundeFraTilbud } from './handlinger'

const statuser = ['ny', 'kontaktet', 'tilbud_klargjoeres', 'tilbud_sendt', 'akseptert', 'avslatt', 'utloopt']
const tekst: Record<string, string> = { ny: 'Ny', kontaktet: 'Kontaktet', tilbud_klargjoeres: 'Tilbud klargjøres', tilbud_sendt: 'Tilbud sendt', akseptert: 'Akseptert', avslatt: 'Avslått', utloopt: 'Utløpt' }

export default async function TilbudsforesporslerSide() {
  if ((await hentInnloggetBruker()).rolle !== 'plattform_redaktor') return <Sideramme><p>Kun plattformadministrator har tilgang.</p></Sideramme>
  const admin = lagSupabaseAdminKlient()
  const [{ data }, { data: tilbud }] = await Promise.all([
    admin.from('tilbudsforesporsler').select('*').order('opprettet_tid', { ascending: false }).limit(200),
    admin.from('tilbud').select('*').limit(200),
  ])
  const tilbudMap = new Map((tilbud ?? []).map((t) => [t.foresporsel_id, t]))
  return <Sideramme><Sidehode tittel="Tilbudsforespørsler" undertittel="Interne forespørsler og tilbud. Priser vises ikke offentlig." />
    {!data?.length ? <Tomtilstand tittel="Ingen forespørsler ennå" forklaring="Nye forespørsler fra tilbudsskjemaet vises her." /> : <div className="sq-liste">
      {data.map((f) => { const t = tilbudMap.get(f.id); return <article className="kort" key={f.id}><h2>{f.virksomhet}</h2><p>{f.kontaktperson} · {f.epost} · {f.telefon}</p><p>{f.antall_stasjoner} stasjoner · {f.retailer_limit} retailer · {f.butikksjef_limit} butikksjefer · {f.tablet_station_limit} tabletstasjoner</p><p>{f.kommentar || 'Ingen kommentar'}</p>
        <form action={endreForesporsel} className="sq-inline"><input type="hidden" name="id" value={f.id} /><select name="status" defaultValue={f.status}>{statuser.map((s) => <option key={s} value={s}>{tekst[s]}</option>)}</select><button className="sq-knapp" type="submit">Lagre status</button></form>
        {!t && <form action={opprettTilbud} className="sq-inline"><input type="hidden" name="id" value={f.id} /><input name="retailer_limit" type="number" min="0" defaultValue={f.retailer_limit} aria-label="Retailerlisenser" /><input name="butikksjef_limit" type="number" min="0" defaultValue={f.butikksjef_limit} aria-label="Butikksjeflisenser" /><input name="tablet_station_limit" type="number" min="0" defaultValue={f.tablet_station_limit} aria-label="Tabletlisenser" /><input name="trial_starts_at" type="date" aria-label="Prøvestart" /><input name="maanedspris_kr" type="number" min="0" placeholder="Månedspris" aria-label="Avtalt månedspris" /><input name="oppstartsgebyr_kr" type="number" min="0" placeholder="Oppstartsgebyr" aria-label="Oppstartsgebyr" /><button className="sq-knapp primar" type="submit">Opprett tilbud</button></form>}
        {t && <><p>Tilbud: {t.status} · {t.maanedspris_kr ?? 'pris ikke satt'} kr/mnd · prøve {t.trial_starts_at ?? 'ikke satt'}–{t.trial_ends_at ?? 'ikke satt'} · binding {t.commitment_starts_at ?? '—'}–{t.commitment_ends_at ?? '—'}</p>{t.status !== 'akseptert' && <form action={registrerAksept} className="sq-inline"><input type="hidden" name="id" value={t.id} /><input name="accepted_by" placeholder="Hvem aksepterte?" required /><input name="acceptance_reference" placeholder="Referanse til signert tilbud/e-post" required /><button className="sq-knapp primar" type="submit">Registrer aksept</button></form>}{t.status === 'akseptert' && !t.retailer_id && <form action={opprettKundeFraTilbud}><input type="hidden" name="id" value={t.id} /><button className="sq-knapp primar" type="submit">Opprett kunde fra tilbud</button></form>}{t.retailer_id && <p className="undertittel">Kunde opprettet: {t.retailer_id}</p>}</>}
      </article> })}
    </div>}</Sideramme>
}
