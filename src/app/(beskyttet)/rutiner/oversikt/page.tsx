import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { Sideramme } from '@/components/ui/sideramme'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { byggOversikt, summerRader, type Forventning, type Utforing } from '@/lib/rutiner-oversikt'
import { Stasjon } from './stasjon'

type Param = string | string[] | undefined
type Search = Record<string, Param>
const tekst = (v: Param) => Array.isArray(v) ? v[0] ?? '' : v ?? ''
const iso = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(d)
const minus = (dato: string, dager: number) => { const d = new Date(`${dato}T12:00:00Z`); d.setUTCDate(d.getUTCDate() - dager); return d.toISOString().slice(0, 10) }
const gyldigDato = (d: string) => /^\d{4}-\d{2}-\d{2}$/.test(d)
const visDato = (d: string) => new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(`${d}T12:00:00Z`))

export default async function RutineOversikt({ searchParams }: { searchParams?: Promise<Search> }) {
  const bruker = await hentInnloggetBruker(); if (!erLeder(bruker.rolle)) return <Sideramme><p>Kun eier/butikksjef har tilgang til oversikten.</p></Sideramme>
  const p = await searchParams ?? {}; const naa = iso(new Date()); const periode = tekst(p.periode) || '7'; const fra = periode === 'i dag' ? naa : periode === '30' ? minus(naa, 29) : periode === 'custom' && gyldigDato(tekst(p.fra)) ? tekst(p.fra) : minus(naa, 6); const til = periode === 'custom' && gyldigDato(tekst(p.til)) ? tekst(p.til) : naa; const vakt = tekst(p.vakt), status = tekst(p.status), medarbeider = tekst(p.medarbeider)
  const supabase = await lagSupabaseServerKlient(); const { data: stasjoner, error } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'); if (error) return <Sideramme><p className="feil">Kunne ikke hente stasjoner: {error.message}</p></Sideramme>
  // Snapshot-tabellen kom etter den genererte databasetypen; den valideres av
  // migrasjonen og holdes isolert til dette serverkallet.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const db = supabase as any
  const svar = await Promise.all((stasjoner ?? []).map(async (s) => { const [f, u, n, a] = await Promise.all([db.from('rutine_forventninger').select('*').eq('stasjon_id', s.id).gte('dato', fra).lte('dato', til), db.from('rutine_utforinger').select('rutine_id, stasjon_id, dato, utfort_tid, ansatt_id, bilde_sti').eq('stasjon_id', s.id).gte('dato', fra).lte('dato', til), db.from('rutine_notat').select('rutine_id, dato, tekst').eq('stasjon_id', s.id).gte('dato', fra).lte('dato', til), db.from('ansatte').select('id, navn').eq('stasjon_id', s.id).is('slettet_tid', null)]); const fs = (f.data ?? []) as Forventning[]; const kommentarer = new Map<string, string>((n.data ?? []).map((x: { rutine_id: string; dato: string; tekst: string }) => [`${x.rutine_id}|${x.dato}`, x.tekst])); const ansatte = new Map<string, string>((a.data ?? []).map((x: { id: string; navn: string }) => [x.id, x.navn])); const full = byggOversikt(fs, (u.data ?? []) as Utforing[], kommentarer, ansatte); const søk = medarbeider.toLocaleLowerCase('nb-NO'); const rader = full.rader.filter((r) => (!vakt || r.vakttype === vakt) && (!status || r.status === status) && (!medarbeider || r.ansatt_id === medarbeider || r.ansatt_navn.toLocaleLowerCase('nb-NO') === søk)); return { stasjon: s, o: summerRader(rader, ansatte), bilder: full.rader.flatMap((r) => r.bilde_sti ? [r.bilde_sti] : []), vakter: [...new Set(full.rader.map((r) => r.vakttype))] } }))
  const stier = [...new Set(svar.flatMap((x) => x.bilder))]; const bildeUrl = new Map<string, string>(); if (stier.length) { const { data } = await supabase.storage.from('rutinebilder').createSignedUrls(stier, 60 * 30); for (const x of data ?? []) if (x.path && x.signedUrl) bildeUrl.set(x.path, x.signedUrl) }
  const alleVakter = [...new Set(svar.flatMap((x) => x.vakter))].sort((a, b) => a.localeCompare(b, 'nb'))
  const totalForventet = svar.reduce((sum, x) => sum + x.o.forventet, 0); const totalUtfort = svar.reduce((sum, x) => sum + x.o.utfort, 0); const filter = <form className="rutine-filtre" method="get"><label>Periode<select name="periode" defaultValue={periode}><option value="i dag">I dag</option><option value="7">Siste 7 dager</option><option value="30">Siste 30 dager</option><option value="custom">Egendefinert</option></select></label><label>Vakt<select name="vakt" defaultValue={vakt}><option value="">Alle vakter</option>{alleVakter.map((x) => <option key={x} value={x}>{x}</option>)}</select></label><label>Status<select name="status" defaultValue={status}><option value="">Alle statuser</option><option>Gjennomført</option><option>Mangler</option><option>For sent</option><option>Ikke registrert</option></select></label><label>Medarbeider<input name="medarbeider" defaultValue={medarbeider} placeholder="Navn eller ID" /></label><label>Fra<input type="date" name="fra" defaultValue={tekst(p.fra)} disabled={periode !== 'custom'} /></label><label>Til<input type="date" name="til" defaultValue={tekst(p.til)} disabled={periode !== 'custom'} /></label><button type="submit">Oppdater oversikt</button></form>
  return <Sideramme><Sidehode tittel="Rutiner — oversikt" undertittel={`${visDato(fra)} til ${visDato(til)} · For sent betyr etter planlagt slutt + 60 minutter.`} /><div className="rutine-oversikt-resultat" aria-live="polite">{totalUtfort} gjennomførte av {totalForventet} forventede rutiner</div>{filter}{svar.length ? svar.map((x) => <Stasjon key={x.stasjon.id} navn={`${x.stasjon.butikknummer} ${x.stasjon.navn}`} o={x.o} bildeUrl={bildeUrl} />) : <Tomtilstand tittel="Ingen stasjoner ennå" forklaring="Du har ingen tildelte stasjoner å vise." />}</Sideramme>
}
