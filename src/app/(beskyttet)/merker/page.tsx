import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { settOppStandard, leggTilMerke, slettMerke, tildelMerke, fjernTildeling } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Merke = { id: string; navn: string; emoji: string; beskrivelse: string | null }
type Ansatt = { id: string; navn: string; stasjon_id: string }
type Tildelt = { id: string; merke_id: string; ansatt_id: string; merker: { navn: string; emoji: string } | null }

export default async function MerkerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const [{ data: merker }, { data: ansatte }, { data: tildelte }, { data: stasjoner }] = await Promise.all([
    supabase.from('merker').select('id, navn, emoji, beskrivelse').is('slettet_tid', null).order('sortering').overrideTypes<Merke[]>(),
    supabase.from('ansatte').select('id, navn, stasjon_id').eq('aktiv', true).is('slettet_tid', null).order('navn').overrideTypes<Ansatt[]>(),
    supabase.from('tildelte_merker').select('id, merke_id, ansatt_id, merker(navn, emoji)').overrideTypes<Tildelt[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perAnsatt = new Map<string, Tildelt[]>()
  for (const t of tildelte ?? []) {
    const l = perAnsatt.get(t.ansatt_id) ?? []
    l.push(t)
    perAnsatt.set(t.ansatt_id, l)
  }

  const merkeliste = merker ?? []
  const folk = ansatte ?? []
  const tildelt = [...perAnsatt.values()].reduce((n, l) => n + l.length, 0)

  // Emojien paa et merke er INNHOLD - brukeren velger den selv - og ikke
  // ikonografi. Derfor staar de, mens 🏅 i undertittelen maatte gaa.
  const tildelPanel = erLeder && merkeliste.length > 0 ? (
    <Sidepanel knapp="Tildel merke" tittel="Tildel et merke">
      <form action={tildelMerke} className="skjema">
        <label className="felt"><span>Til hvem</span>
          <select name="ansatt_id" required defaultValue="">
            <option value="" disabled>Velg ansatt …</option>
            {folk.map((a) => <option key={a.id} value={a.id}>{a.navn}</option>)}
          </select>
        </label>
        <label className="felt"><span>Hvilket merke</span>
          <select name="merke_id" required defaultValue="">
            <option value="" disabled>Velg merke …</option>
            {merkeliste.map((m) => <option key={m.id} value={m.id}>{m.emoji} {m.navn}</option>)}
          </select>
        </label>
        <button type="submit" className="sq-knapp primar">Tildel merket</button>
      </form>
    </Sidepanel>
  ) : undefined

  return (
    <>
      <Sidehode
        tittel="Merker"
        undertittel={tildelt === 0
          ? 'Anerkjennelse til de ansatte — vis fram det teamet får til.'
          : `${tildelt} tildelt til ${folk.length} ansatte.`}
        handlinger={tildelPanel}
      />

      {erLeder && merkeliste.length === 0 && (
        <Tomtilstand
          tittel="Ingen merker satt opp"
          forklaring="Start med et sett standardmerker, så kan du tilpasse dem etterpå."
          handling={<form action={settOppStandard}><button type="submit" className="sq-knapp primar">Sett opp standardmerker</button></form>}
        />
      )}

      {folk.length === 0 ? (
        <Tomtilstand
          tittel="Ingen ansatte ennå"
          forklaring="Legg dem inn under Ansatte, så kan de få merker her."
        />
      ) : (
        <ul className="merkevegg">
          {folk.map((a) => {
            const sine = perAnsatt.get(a.id) ?? []
            return (
              <li key={a.id}>
                <div className="merkevegg-navn">
                  <strong>{a.navn}</strong>
                  <span className="undertittel"> · {navnFor.get(a.stasjon_id) ?? '—'}</span>
                </div>
                <div className="merkevegg-merker">
                  {sine.length === 0 ? <span className="undertittel">Ingen merker ennå</span> : sine.map((t) => (
                    <span className="merke-pill" key={t.id} title={t.merker?.navn}>
                      <span className="merke-emoji">{t.merker?.emoji}</span> {t.merker?.navn}
                      {erLeder && (
                        <form action={fjernTildeling} className="sq-inline-skjema">
                          <input type="hidden" name="id" value={t.id} />
                          <button type="submit" className="merke-fjern" aria-label="Fjern">×</button>
                        </form>
                      )}
                    </span>
                  ))}
                </div>
              </li>
            )
          })}
        </ul>
      )}

      {erLeder && merkeliste.length > 0 && (
        // Hvilke merker som FINNES er oppsett, ikke dagens arbeid. Det er
        // merkeveggen folk kommer for.
        <details className="sq-forklaring sq-luft-over">
          <summary>Merkene som finnes ({merkeliste.length})</summary>
          <div className="sq-forklaring-innhold">
            <ul className="laereplan-liste">
              {merkeliste.map((m) => (
                <li key={m.id}>
                  <span><span className="merke-emoji">{m.emoji}</span> <strong>{m.navn}</strong>{m.beskrivelse ? <span className="undertittel"> — {m.beskrivelse}</span> : null}</span>
                  <form action={slettMerke}>
                    <input type="hidden" name="id" value={m.id} />
                    <button type="submit" className="liten slett">Slett</button>
                  </form>
                </li>
              ))}
            </ul>
            <form action={leggTilMerke} className="sq-skjema">
              <input name="emoji" placeholder="🏅" maxLength={4} className="sq-smalt-felt" aria-label="Merkesymbol" />
              <input name="navn" placeholder="Merkenavn" required />
              <input name="beskrivelse" placeholder="Beskrivelse (valgfri)" />
              <button type="submit" className="liten">Legg til</button>
            </form>
          </div>
        </details>
      )}
    </>
  )
}
