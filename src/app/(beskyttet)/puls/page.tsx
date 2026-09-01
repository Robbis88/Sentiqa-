import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { avsluttRunde, slettRunde } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Status } from '@/components/ui/status'
import { NyRundeSkjema, type PulsSporsmal } from './ny-skjema'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { Sideramme } from '@/components/ui/sideramme'

type Runde = { id: string; sporsmal_id: string; start_dato: string; slutt_dato: string; status: string; puls_sporsmal: { tekst: string; kategori: string } | null }

export default async function PulsSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Puls administreres av eier/butikksjef. Ansatte svarer på tableten.</p></Sideramme>
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

  const liste = runder ?? []
  const aktive = liste.filter((r) => r.status === 'aktiv').length

  // Spørsmålsbiblioteket til gjenbruksvelgeren i skjemaet.
  const { data: sporsmal } = await supabase
    .from('puls_sporsmal').select('id, tekst, kategori')
    .eq('aktiv', true).is('slettet_tid', null).order('sortering')
    .overrideTypes<PulsSporsmal[]>()

  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  const om7 = new Date(idag)
  om7.setDate(om7.getDate() + 7)

  const startPanel = (
    <Sidepanel
      knapp="Start måling"
      tittel="Start pulsmåling"
      beskrivelse="Ett spørsmål og en periode — så er den publisert på nettbrettene."
    >
      <NyRundeSkjema
        sporsmal={sporsmal ?? []}
        idag={idag}
        om7={om7.toISOString().slice(0, 10)}
      />
    </Sidepanel>
  )

  return (
    <Sideramme>
      <Sidehode
        tittel="Puls"
        undertittel={liste.length === 0
          ? 'Korte målinger — ett spørsmål om gangen.'
          : `${aktive} ${aktive === 1 ? 'aktiv måling' : 'aktive målinger'} av ${liste.length}.`}
        handlinger={startPanel}
      />

      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Ingen målinger ennå"
          forklaring={'Ett spørsmål, ett trykk på nettbrettet. Godt egnet til å følge '
            + 'stemningen over tid framfor å spørre på et personalmøte.'}
          handling={startPanel}
        />
      ) : (
        <ul className="sq-innleggsliste">
          {liste.map((r) => {
            const n = antall.get(r.id) ?? 0
            const snitt = n > 0 ? (sum.get(r.id)! / n).toFixed(1) : '—'
            return (
              <li key={r.id} className="sq-innlegg">
                <div className="sq-innlegg-topp">
                  <strong><Link href={`/puls/${r.id}`}>{r.puls_sporsmal?.tekst ?? '—'}</Link></strong>
                  {/* En aktiv maaling er utgangspunktet, ikke en seier -
                      derfor `normal`. Den avsluttede er ikke et problem
                      heller; den er ferdig. Ingen av dem trenger farge
                      for aa bli forstaatt, og ordet staar der uansett. */}
                  <Status nivaa={r.status === 'aktiv' ? 'normal' : 'endring'}>
                    {r.status === 'aktiv' ? 'Aktiv' : 'Avsluttet'}
                  </Status>
                </div>
                <div className="sq-innlegg-bunn">
                  <span className="undertittel">
                    {r.puls_sporsmal?.kategori} · {datoLang.format(new Date(r.start_dato))}–{datoLang.format(new Date(r.slutt_dato))} · {n} svar · snitt {snitt}
                  </span>
                  <span className="knapperad">
                    <Link href={`/puls/${r.id}`} className="liten">Resultater</Link>
                    {r.status === 'aktiv' && (
                      <form action={avsluttRunde}><input type="hidden" name="id" value={r.id} /><button type="submit" className="liten primar">Avslutt</button></form>
                    )}
                    <SlettKnapp hva={r.start_dato} handling={slettRunde} id={r.id} merke="Slett" />
                  </span>
                </div>
              </li>
            )
          })}
        </ul>
      )}
    </Sideramme>
  )
}
