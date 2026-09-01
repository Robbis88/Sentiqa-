import { hentInnloggetBruker } from '@/lib/auth/dal'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { registrerSkills, slettSkills } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Liste, Rad } from '@/components/ui/liste'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Sideramme } from '@/components/ui/sideramme'

type Score = { id: string; stasjon_id: string; prosent: number; kommentar: string | null; registrert_tid: string }
const tid = new Intl.DateTimeFormat('nb-NO', { timeZone: 'Europe/Oslo', dateStyle: 'short' })

export default async function SkillsSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return <Sideramme><p>Kun eier/butikksjef.</p></Sideramme>
  const supabase = await lagSupabaseServerKlient()
  const [{ data: scorer }, { data: stasjoner }] = await Promise.all([
    supabase.from('skills_score').select('id, stasjon_id, prosent, kommentar, registrert_tid').order('registrert_tid', { ascending: false }).limit(50).overrideTypes<Score[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])
  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  const liste = scorer ?? []
  const nyPanel = (
    <Sidepanel
      knapp="Ny score"
      tittel="Ny skills-score"
      beskrivelse="Vises på nettbrettet, så teamet ser sin egen utvikling."
    >
      <form action={registrerSkills} className="skjema">
        <label className="felt"><span>Stasjon</span>
          <select name="stasjon_id" required defaultValue="">
            <option value="" disabled>Stasjon …</option>
            {(stasjoner ?? []).map((s) => <option key={s.id} value={s.id}>{s.butikknummer} {s.navn}</option>)}
          </select>
        </label>
        <label className="felt"><span>Skills-score i prosent</span>
          <input name="prosent" type="number" min="0" max="100" step="0.1" required />
        </label>
        <label className="felt"><span>Kommentar (valgfri)</span><input name="kommentar" /></label>
        <button type="submit" className="sq-knapp primar">Lagre score</button>
      </form>
    </Sidepanel>
  )

  return (
    <Sideramme>
      <Sidehode
        tittel="Skills-score"
        undertittel="Teamets score fra treningsappen. Vises på nettbrettet."
        handlinger={nyPanel}
      />

      {/* Hver rad er EN registrering man kan slette - ikke en kolonne
          noen leser mot en annen. Scoren staar som metadata, hoyrestilt
          med tabulaere siffer, saa den fortsatt kan skummes nedover. */}
      {liste.length === 0 ? (
        <Tomtilstand
          tittel="Ingen score registrert"
          forklaring="Legg inn score fra treningsappen, så ser teamet utviklingen sin på nettbrettet."
          handling={nyPanel}
        />
      ) : (
        <Liste merkelapp="Registrerte score">
          {liste.map((s) => (
            <Rad
              key={s.id}
              primaer={navnFor.get(s.stasjon_id) ?? '—'}
              sekundaer={[tid.format(new Date(s.registrert_tid)), s.kommentar]
                .filter(Boolean).join(' · ')}
              metadata={`${Number(s.prosent)} %`}
              handlinger={(
                <SlettKnapp hva={`${s.prosent} %`} handling={slettSkills} id={s.id} bekreftelse="Scoren slettet" />
              )}
            />
          ))}
        </Liste>
      )}
    </Sideramme>
  )
}
