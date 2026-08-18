import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { beregnRutinestat, type Rutinestat } from '@/lib/rutinestat'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'

function prosentKlasse(p: number) {
  return p >= 90 ? 'gronn' : p >= 70 ? 'gul' : 'rod'
}

export default async function RutineOversikt() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Kun eier/butikksjef har tilgang til oversikten.</p>
  }
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())

  const { data: stasjoner } = await supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer')

  const rader: { navn: string; stat: Rutinestat }[] = await Promise.all(
    (stasjoner ?? []).map(async (s) => ({
      navn: `${s.butikknummer} ${s.navn}`,
      stat: await beregnRutinestat(supabase, s.id, idag),
    })),
  )
  rader.sort((a, b) => b.stat.prosent - a.stat.prosent)

  // NIVÅ 1 — svaret. Kjedetallet regnes på SUMMENE, ikke som snittet av
  // stasjonenes prosenter: en liten stasjon med tre rutiner skal ikke telle
  // like mye som en stor med tretti når man spør hvordan kjeden ligger an.
  const sumUtfort = rader.reduce((s, r) => s + r.stat.utfort, 0)
  const sumForventet = rader.reduce((s, r) => s + r.stat.forventet, 0)
  const kjedePst = sumForventet > 0 ? Math.round((sumUtfort / sumForventet) * 100) : null
  const verst = rader.length > 0 ? rader[rader.length - 1] : null

  const svar = kjedePst == null
    ? 'Ingen forventede rutiner de siste 30 dagene'
    : `Kjeden gjennomfører ${kjedePst} % av rutinene siste 30 dager`
      + (verst && rader.length > 1 ? `. Svakest: ${verst.navn} (${verst.stat.prosent} %)` : '')

  return (
    <>
      <Sidehode tittel="Rutiner — oversikt" undertittel={svar} />

      {rader.length === 0 ? (
        <Tomtilstand
          tittel="Ingen stasjoner ennå"
          forklaring="Oversikten rangerer stasjonene på hvor mye av rutinene som faktisk blir gjort. Så snart det finnes stasjoner, står de her."
        />
      ) : (
        rader.map((r, i) => (
          <section className="kort rangering-kort" key={r.navn}>
            <div className="rangering-topp">
              {/* Sto med medaljeemoji på topp tre. Plasseringen er allerede
                  et tall, og prosentpipen ved siden av bærer dommen. */}
              <span className="rangering-plass">#{i + 1}</span>
              <strong>{r.navn}</strong>
              <span className={`status-pip ${prosentKlasse(r.stat.prosent)}`}>{r.stat.prosent}%</span>
              {r.stat.streak > 0 && <span className="streak">{r.stat.streak} dager på rad</span>}
            </div>
            <p className="undertittel">
              {r.stat.utfort} av {r.stat.forventet} forventede rutiner gjennomført
            </p>
            {r.stat.toppUtforere.length > 0 && (
              <p className="undertittel">
                Topputførere: {r.stat.toppUtforere.map((t) => `${t.navn} (${t.antall})`).join(' · ')}
              </p>
            )}
          </section>
        ))
      )}

      <Forklaring sporsmaal="Hva teller som gjennomført?">
        <p>
          Prosenten er utførte rutiner delt på forventede, over de siste 30 dagene.
          Forventet følger skjemaet stasjonen er satt opp med — en rutine som ikke var
          planlagt den dagen, teller verken opp eller ned.
        </p>
        <p>
          Kjedetallet i toppen regnes på summene, ikke som snittet av stasjonenes
          prosenter. En liten stasjon med tre daglige rutiner skal ikke veie like tungt
          som en stor med tretti når spørsmålet er hvordan kjeden ligger an.
        </p>
        <p>
          «Dager på rad» er sammenhengende dager der <em>alt</em> som var forventet ble
          gjort. En dag uten forventede rutiner bryter den ikke — da var det ingenting
          å ryke på. Dagen i dag teller først når den er ferdig, men river ikke rekka
          mens den pågår.
        </p>
      </Forklaring>
    </>
  )
}
