import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { startRunde } from '../handlinger'

type Sporsmal = { id: string; tekst: string; kategori: string }

export default async function NyRundeSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') return <p>Ingen tilgang.</p>
  const supabase = await lagSupabaseServerKlient()
  const { data: sporsmal } = await supabase.from('puls_sporsmal').select('id, tekst, kategori').eq('aktiv', true).is('slettet_tid', null).order('sortering').overrideTypes<Sporsmal[]>()

  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  const om7 = new Date(idag); om7.setDate(om7.getDate() + 7)

  return (
    <>
      <h1>Start pulsmåling</h1>
      <p className="undertittel">Velg ett spørsmål og en periode. <Link href="/puls">Tilbake</Link></p>

      {(sporsmal ?? []).length === 0 ? (
        <section className="kort"><p className="undertittel">Ingen aktive spørsmål. <Link href="/puls/sporsmal">Sett opp spørsmål først</Link>.</p></section>
      ) : (
        <section className="kort">
          <form action={startRunde} className="skjema" style={{ maxWidth: 520 }}>
            <label className="felt"><span>Spørsmål</span>
              <select name="sporsmal_id" required defaultValue="">
                <option value="" disabled>Velg …</option>
                {(sporsmal ?? []).map((s) => <option key={s.id} value={s.id}>{s.kategori}: {s.tekst}</option>)}
              </select>
            </label>
            <div className="rad-2">
              <label className="felt"><span>Fra</span><input type="date" name="start_dato" defaultValue={idag} required /></label>
              <label className="felt"><span>Til</span><input type="date" name="slutt_dato" defaultValue={om7.toISOString().slice(0, 10)} required /></label>
            </div>
            <label className="felt"><span>Notat (valgfri)</span><input name="notat" placeholder="internt notat" /></label>
            <button type="submit">Start måling</button>
          </form>
        </section>
      )}
    </>
  )
}
