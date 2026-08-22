import Link from 'next/link'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { TabletHode } from '../tablet-hode'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { oversettMange } from '@/lib/oversett'
import { leggTilAnvisning, slettAnvisning } from './handlinger'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Knapp } from '@/components/ui/knapp'
import { Felt } from '@/components/ui/felt'

type Anvisning = { id: string; kategori: string; tittel: string; innhold: string }

export default async function AnvisningerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('anvisninger')
    .select('id, kategori, tittel, innhold')
    .is('slettet_tid', null)
    .order('kategori')
    .order('sortering')
    .overrideTypes<Anvisning[]>()

  const grupper = new Map<string, Anvisning[]>()
  for (const a of data ?? []) {
    const l = grupper.get(a.kategori) ?? []
    l.push(a)
    grupper.set(a.kategori, l)
  }

  // Oversettelse gjelder KUN tableten. Admin/butikksjef ser alltid norsk
  // (selv om sprak-cookien er satt av en tablet-bruker i samme nettleser).
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet' ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const fast = [
    'Anvisninger', 'Prosedyrer og oppskrifter — slå opp når du trenger det.',
    'Ingen anvisninger ennå.', 'anvisning', 'anvisninger',
    // Nettbrettets «Hjelp» og foten under den (bolge 5).
    'Hjelp', 'Slå opp når du trenger det.', 'Mer hjelp',
    'Lenker', 'Hurtiglenker for å hjelpe kunder',
    'Nyheter', 'Oppdateringer og tips',
    'Slik måler vi', 'Hva systemet lagrer om deg',
  ]
  const oversatt = await oversettMange([...fast, ...(data ?? []).flatMap((a) => [a.kategori, a.tittel, a.innhold])], sprak)
  const o = (s: string) => oversatt.get(s) ?? s

  const antall = [...grupper.values()].reduce((n, l) => n + l.length, 0)
  const nyPanel = erLeder ? (
    <Sidepanel knapp="Ny anvisning" tittel="Ny anvisning">
      <form action={leggTilAnvisning} className="sq-skjema">
        <Felt etikett="Kategori" name="kategori" placeholder="Hurtigmat"
          hjelp="Samler anvisninger folk leter etter sammen." />
        <Felt etikett="Tittel" name="tittel" placeholder="Slik lager du kaffe" required />
        <label className="felt"><span>Innhold</span>
          <textarea name="innhold" rows={8} required />
        </label>
        <div className="knapperad">
          <Knapp type="submit" variant="primar">Legg til anvisning</Knapp>
        </div>
      </form>
    </Sidepanel>
  ) : undefined

  // «HJELP» PAA NETTBRETTET, «Anvisninger» hos lederen.
  //
  // Samme innhold, to aerend. Lederen vedlikeholder et bibliotek; hun som
  // staar i butikken har et problem og trenger svaret. Derfor heter fana
  // det hun kommer for — og derfor staar Lenker, Nyheter og «Slik maaler
  // vi» i foten her, i stedet for som egne faner og fliser.
  const paaNettbrett = bruker.rolle === 'butikkbruker_tablet'

  return (
    <>
      {paaNettbrett ? (
        <TabletHode tittel={o('Hjelp')} undertittel={o('Slå opp når du trenger det.')} />
      ) : (
        <Sidehode
          tittel={o('Anvisninger')}
          undertittel={o('Prosedyrer og oppskrifter — slå opp når du trenger det.')}
          handlinger={nyPanel}
        />
      )}

      {grupper.size === 0 ? (
        <Tomtilstand
          tittel={o('Ingen anvisninger ennå')}
          forklaring={o('Her legger dere prosedyrene folk må slå opp — hvordan '
            + 'kaffemaskinen rengjøres, hvordan pølsegrillen settes opp.')}
          handling={nyPanel}
        />
      ) : (
        // Kategoriene er en EKTE gruppering — folk leter etter «Hurtigmat»,
        // ikke etter den fjerde anvisningen. Derfor beholdes de.
        [...grupper.entries()].map(([kat, liste]) => (
          <section className="sq-anvkat" key={kat}>
            <h2>{o(kat)} <span className="undertittel">· {liste.length}</span></h2>
            {liste.map((a) => (
              <details className="anvisning" key={a.id}>
                <summary>{o(a.tittel)}</summary>
                {/* Linjeskiftene i en oppskrift ER innholdet. Sto som
                    inline-stil; er naa en klasse, som alt annet. */}
                <p className="sq-brodtekst">{o(a.innhold)}</p>
                {erLeder && (
                  <div className="knapperad">
                    <SlettKnapp hva={a.tittel} handling={slettAnvisning} id={a.id} bekreftelse="Anvisningen slettet" />
                  </div>
                )}
              </details>
            ))}
          </section>
        ))
      )}
      <p className="undertittel">{antall} {antall === 1 ? o('anvisning') : o('anvisninger')}</p>

      {/* FOTEN. Tre ruter som hver hadde en fane eller en flis paa hjem,
          og som alle svarer paa det samme aerendet: «jeg trenger aa vite
          noe». De mistet ikke en vei — de mistet en dublett, og fikk et
          sted der de hoerer sammen. */}
      {paaNettbrett && (
        <nav className="tablet-fot" aria-label={o('Mer hjelp')}>
          <Link href="/lenker" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Lenker')}</strong>
              <span className="undertittel">{o('Hurtiglenker for å hjelpe kunder')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
          <Link href="/nyheter" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Nyheter')}</strong>
              <span className="undertittel">{o('Oppdateringer og tips')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
          <Link href="/mine-opplysninger" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Slik måler vi')}</strong>
              <span className="undertittel">{o('Hva systemet lagrer om deg')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
        </nav>
      )}
    </>
  )
}
